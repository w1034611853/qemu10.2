# `SUBS rd -> plain SBC` 直连 consumer 实现计划

> **给执行型 agent 的要求：** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 为 x86 host 上 same-TB adjacent `SUBS rd, ... -> plain SBC` 增加 result-preserving direct-consumer fast path，删除 consumer 前的 borrow decode 热路径，同时保持 producer 结果值和 producer NZCV。

**架构：** 采用 `1.5` 方案：producer 继续复用现有 direct `gen_sub_CC()`，立即 materialize 结果值与 canonical raw flags；优先复用已有 `a64_cmp_pending_materialized + A64_X86_CC_SUB32/64` 作为最小 metadata。consumer 命中时直接复用已有 host `sbb` emission，不新增新的 arithmetic fused backend framework。

**技术栈：** QEMU AArch64 TCG 前端、现有 TCG borrow-chain arithmetic op、AArch64 TCG 测试、dedicated benchmark。

---

### 任务 1：先写会失败的 codegen 回归

**文件：**
- 修改：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 修改：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`

- [ ] **步骤 1：在汇编测试里加入 64-bit 相邻 `SUBS rd -> SBC` 场景**
- [ ] **步骤 2：在汇编测试里加入 32-bit 相邻 `SUBS rd -> SBC` 场景**
- [ ] **步骤 3：扩展检查脚本，能抽出 `subs-rd -> sbc` 对应 host block**
- [ ] **步骤 4：让脚本要求命中 block 中存在 producer `sub` 和 consumer `sbb`，并且 consumer 前没有 `shr/and/setcc` carry-decode 链、没有额外 borrow seed `sub`、没有重做 producer 的 `cmp`**
- [ ] **步骤 5：运行 `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user adc-sbc-host-direct`**
- [ ] **步骤 6：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`，确认当前实现仍然 decode borrow 而失败**

### 任务 2：补语义守护测试

**文件：**
- 修改：`tests/tcg/aarch64/nzcv-status4.S`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **步骤 1：新增 64-bit adjacent `SUBS rd -> SBC` 用例，验证 producer 结果值、consumer 结果值、producer NZCV**
- [ ] **步骤 2：新增 32-bit adjacent `SUBS rd -> SBC` 用例，验证 32-bit zero-extend 与 borrow 语义**
- [ ] **步骤 3：运行 `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`，确认新增用例作为语义 guard 可运行**

### 任务 3：把 `SUBS rd` 命中接到 producer 侧

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：在 `do_addsub_reg()` 中新增相邻 plain `SBC` 命中条件，范围只限 `setflags && sub_op && rd != 31`**
- [ ] **步骤 2：为本步增加独立 env 开关，例如 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`，不要复用 step 16 的 `QEMU_A64_DISABLE_CMP_SBC_DIRECT`**
- [ ] **步骤 3：命中后不要 defer producer，仍然走现有 direct `gen_sub_CC(..., allow_direct = true)`**
- [ ] **步骤 4：producer 结束后记录 pending metadata，明确这是一条 sub-style、adjacent-only、live-borrow-eligible producer**
- [ ] **步骤 5：优先复用已有 `a64_cmp_pending_materialized`，避免在本任务里新增新的 `DisasContext` 字段**

### 任务 4：把 plain `SBC` consumer 接到 live borrow

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：扩展 `a64_try_emit_x86_cmp_sbc(...)`，让它显式区分 compare-like producer（step 16）和 result-preserving producer（本步）**
- [ ] **步骤 2：step 16 producer 继续走当前 fused `cmp + capture + sbb` 路线**
- [ ] **步骤 3：本步 producer 改为直接复用已有 host `sbb` emission，不再重做 producer `cmp/sub`**
- [ ] **步骤 4：如果现有 helper 形状不便直接表达 `dst != lhs`，补一个最小 wrapper，例如先 `mov dst, lhs` 再发 `subbio`**
- [ ] **步骤 5：确保 consumer 命中后 canonical flags 仍然表示 producer raw flags，而不是 consumer flags**

### 任务 5：让红灯变绿并做 focused correctness 回归

**文件：**
- 测试：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 测试：`tests/tcg/aarch64/nzcv-status4.S`
- 测试：`tests/tcg/aarch64/adcsbc-bench.c`

- [ ] **步骤 1：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`，确认 `subs-rd -> sbc` codegen 检查通过**
- [ ] **步骤 2：重新运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 4：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`**
- [ ] **步骤 5：运行 `ninja -C build-aarch64-linux-user qemu-aarch64` 作为最终 build 验证**

### 任务 6：补 dedicated benchmark 并做 isolated A/B

**文件：**
- 修改：`tests/tcg/aarch64/adcsbc-bench.c`
- 修改：`tests/tcg/aarch64/adcsbc-bench.out`
- 修改：`a64_tcg_cmpjcc_perf_results.md`
- 修改：`codex_a64_x86_status4_cmpjcc_plan.md`

- [ ] **步骤 1：为真正命中本步优化的模式新增 dedicated benchmark，例如 `subsbc64` / `subsbc32`**
- [ ] **步骤 2：更新 golden output，让 `run-adcsbc-bench` 固定回归这些 mode 的 hash**
- [ ] **步骤 3：在同一棵树、同一二进制上，只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1` 做 isolated A/B**
- [ ] **步骤 4：优先记录 `subsbc64` / `subsbc32`，并保留 `sbc64` / `sbc32` / `cmp->sbc` 控制项**
- [ ] **步骤 5：把 mean / median 与结论写回结果文档，明确说明这一步本身是否为正收益**

### 任务 7：必要时做一轮 SPEC 复核

**文件：**
- 无代码改动；验证为主

- [ ] **步骤 1：如果 focused correctness 或 benchmark 期间暴露异常，再复跑 `531.deepsjeng_r train`**
- [ ] **步骤 2：如果改动面超出预期，再补跑当前跟踪的 `500/502/531/557 train` 子集**
- [ ] **步骤 3：把 fresh SPEC 结果只在本步真正完成后再写回结果文档，避免中途记录污染最终结论**
