# `ADDS rd -> plain ADC` 直连 consumer 实现计划

> **给执行型 agent 的要求：** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 为 x86 host 上 same-TB adjacent `ADDS rd, ... -> plain ADC` 增加 result-preserving direct-consumer fast path，删除 consumer 前的 carry decode 热路径，同时保持 producer 结果值和 producer NZCV。

**架构：** 采用 `1.5` 方案：producer 继续复用现有 direct `gen_add_CC()`，立即 materialize 结果值与 canonical raw flags；前端只新增最小 metadata，记录“live host `CF` 可供相邻 plain `ADC` 直接消费”。consumer 命中时复用已有 `a64_emit_addcio_i64/i32()` 发 plain host `adc`，不新增新的 arithmetic fused backend framework。

**技术栈：** QEMU AArch64 TCG 前端、现有 TCG carry-in arithmetic op、AArch64 TCG 测试、dedicated benchmark。

---

### 任务 1：先写会失败的 codegen 回归

**文件：**
- 修改：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 修改：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`

- [ ] **步骤 1：在汇编测试里加入 64-bit 相邻 `ADDS rd -> ADC` 场景**
- [ ] **步骤 2：在汇编测试里加入 32-bit 相邻 `ADDS rd -> ADC` 场景**
- [ ] **步骤 3：扩展检查脚本，能抽出 `adds-rd -> adc` 对应 host block**
- [ ] **步骤 4：让脚本要求命中 block 中存在 producer `add` 和 consumer `adc`，并且 consumer 前没有 `shr/and/setcc` 这类 carry-decode 链**
- [ ] **步骤 5：运行 `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user adc-sbc-host-direct`**
- [ ] **步骤 6：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`，确认当前实现因仍然 decode carry 而失败**

### 任务 2：补语义守护测试

**文件：**
- 修改：`tests/tcg/aarch64/nzcv-status4.S`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **步骤 1：新增 64-bit adjacent `ADDS rd -> ADC` 用例，验证 producer 结果值、consumer 结果值、producer NZCV**
- [ ] **步骤 2：新增 32-bit adjacent `ADDS rd -> ADC` 用例，验证 32-bit zero-extend 与 carry 语义**
- [ ] **步骤 3：运行 `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`，确认新增用例作为语义 guard 可运行**

### 任务 3：为 `ADDS rd` producer 增加最小 live-carry metadata

**文件：**
- 修改：`target/arm/tcg/translate.h`
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：在 `DisasContext` 的现有 pending metadata 上增加最小字段，用来表示“pending producer 留下了可被相邻 consumer 直接消费的 live carry”**
- [ ] **步骤 2：避免在本任务里做整套 `cmp_pending` 重命名，只加 phase 2 已经被证明需要的字段**
- [ ] **步骤 3：检查 pending metadata 初始化、drop、overwrite、record 逻辑，把新增字段接到所有 reset 路径**
- [ ] **步骤 4：如果 trace/debug 输出会受影响，补齐最小必要的 trace 信息**

### 任务 4：把 `ADDS rd` 命中接到 producer 侧

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：在 `do_addsub_reg()` 中新增相邻 plain `ADC` 命中条件，范围只限 `setflags && !sub_op && rd != 31`**
- [ ] **步骤 2：命中后不要 defer producer，仍然走现有 direct `gen_add_CC(..., allow_direct = true)`**
- [ ] **步骤 3：producer 结束后记录 pending metadata，明确这是一条 add-style、adjacent-only、live-carry-eligible producer**
- [ ] **步骤 4：任何 miss 都必须回退到当前 `gen_add_CC()` 路径，不影响 phase 1 的 `CMN/ADDS xzr` 流程**

### 任务 5：把 plain `ADC` consumer 接到 live carry

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：扩展 `a64_try_emit_x86_add_adc(...)`，让它显式区分 compare-like producer（phase 1）和 result-preserving producer（phase 2）**
- [ ] **步骤 2：phase 1 producer 继续走当前 fused `add + capture + adc` 路线**
- [ ] **步骤 3：phase 2 producer 改为直接复用 `a64_emit_addcio_i64()` / `a64_emit_addcio_i32()` 发 plain host `adc`**
- [ ] **步骤 4：确保 consumer 命中后正确标记 pending producer 已消费**
- [ ] **步骤 5：确保 consumer 之后 canonical flags 仍然表示 producer raw flags，而不是 consumer flags**

### 任务 6：让红灯变绿并做 focused correctness 回归

**文件：**
- 测试：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 测试：`tests/tcg/aarch64/nzcv-status4.S`
- 测试：`tests/tcg/aarch64/adcsbc-bench.c`

- [ ] **步骤 1：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`，确认 `adds-rd -> adc` codegen 检查通过**
- [ ] **步骤 2：重新运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 4：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`**
- [ ] **步骤 5：运行 `ninja -C build-aarch64-linux-user qemu-aarch64` 作为最终 build 验证**

### 任务 7：补 dedicated benchmark 并做 isolated A/B

**文件：**
- 修改：`tests/tcg/aarch64/adcsbc-bench.c`
- 修改：`tests/tcg/aarch64/adcsbc-bench.out`
- 修改：`a64_tcg_cmpjcc_perf_results.md`
- 修改：`codex_a64_x86_status4_cmpjcc_plan.md`

- [ ] **步骤 1：为真正命中本步优化的模式新增 dedicated benchmark，例如 `addsadc64` / `addsadc32`**
- [ ] **步骤 2：更新 golden output，让 `run-adcsbc-bench` 固定回归这些 mode 的 hash**
- [ ] **步骤 3：在同一棵树、同一二进制上，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1` 做 isolated A/B**
- [ ] **步骤 4：优先记录 `addsadc64` / `addsadc32`，并保留 `cmnadc64` / `cmnadc32` / `adc64` / `adc32` 作为控制项**
- [ ] **步骤 5：把 mean / median 与结论写回结果文档，明确说明这一步本身是否为正收益**
