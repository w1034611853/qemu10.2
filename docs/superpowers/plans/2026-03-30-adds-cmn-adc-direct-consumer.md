# `ADDS/CMN -> plain ADC` 直连 consumer 实现计划

> **给执行型 agent 的要求：** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 为 x86 host 上的 same-TB adjacent `CMN / ADDS xzr -> plain ADC` 增加一条窄范围 direct-consumer fast path，去掉 consumer 前的 carry decode 热路径。

**架构：** 复用现有 pending-producer 骨架，但 phase 1 只记录 add-style compare-like producer（`A64_X86_CC_ADD32/ADD64`），并只在相邻 plain `ADC` 处消费。后端增加一条窄的 fused x86 op，语义是“先做 producer add 并 capture raw flags，再直接做 consumer adc”。未命中时全部回退到现有路径。

**技术栈：** QEMU AArch64 TCG 前端、通用 TCG 核心、i386 TCG 后端、AArch64 TCG 测试。

---

### 任务 1：先写会失败的 codegen 回归

**文件：**
- 修改：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 修改：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`

- [ ] **步骤 1：在汇编测试里加入相邻 `CMN/ADDS xzr -> ADC` 场景**
- [ ] **步骤 2：把检查脚本扩成同时检查 `cmp->sbc` 和 `cmn->adc` 两个 block**
- [ ] **步骤 3：运行 `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user adc-sbc-host-direct`**
- [ ] **步骤 4：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh "build-aarch64-linux-user/qemu-aarch64" build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`，确认当前实现因缺少 direct `add; adc` 而失败**

### 任务 2：加入会失败的语义回归

**文件：**
- 修改：`tests/tcg/aarch64/nzcv-status4.S`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`

- [ ] **步骤 1：新增 64-bit adjacent `CMN -> ADC` 用例，验证结果值和 producer NZCV**
- [ ] **步骤 2：新增 32-bit adjacent `CMN -> ADC` 用例，验证 32-bit carry 语义**
- [ ] **步骤 3：运行 `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`，确认新增用例在当前实现下失败**

### 任务 3：为 add-side direct consumer 增加后端 fused op

**文件：**
- 修改：`tcg/i386/tcg-target-opc.h.inc`
- 修改：`tcg/i386/tcg-target-con-set.h`
- 修改：`tcg/tcg.c`
- 修改：`tcg/i386/tcg-target.c.inc`
- 修改：`tcg/optimize.c`

- [ ] **步骤 1：定义一条窄的 i386-only opcode，表达“producer add + capture rawflags + consumer adc”**
- [ ] **步骤 2：为这条 opcode 补上约束、TCG core 注册和分发**
- [ ] **步骤 3：在 x86 后端实现发射序列：先用最终 `ADC` 目标寄存器当 scratch 做 `add`，capture producer raw flags，再做 `adc`**
- [ ] **步骤 4：确保该 opcode 会正确打断/更新 carry folding 状态**

### 任务 4：把 fused op 接到 A64 前端

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：新增相邻 plain `ADC` 识别器和环境变量开关 `QEMU_A64_DISABLE_ADD_ADC_DIRECT`**
- [ ] **步骤 2：增加 add-side consumer helper，例如 `a64_try_emit_x86_add_adc(...)`**
- [ ] **步骤 3：只在 `do_addsub_reg()` 的 `setflags && !sub_op && rd == 31` 路径上记录 add-style pending producer**
- [ ] **步骤 4：只在 `do_adc_sbc()` 的 plain `ADC` 分支优先尝试消费该 pending producer**
- [ ] **步骤 5：任何 miss 都必须回退到现有 `gen_add_CC()` / `gen_adc()` 路径**

### 任务 5：让红灯变绿，并做 focused 回归

**文件：**
- 测试：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 测试：`tests/tcg/aarch64/nzcv-status4.S`
- 测试：`tests/tcg/aarch64/adcsbc-bench.c`

- [ ] **步骤 1：重新运行 codegen check，确认 `cmn->adc` 新检查通过**
- [ ] **步骤 2：重新运行 `nzcv-status4`，确认新增 64/32-bit 用例通过**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`**
- [ ] **步骤 5：如果上述都通过，再运行 `ninja -C build-aarch64-linux-user qemu-aarch64` 作为最终 build 验证**

### 任务 6：做 isolated A/B，确认这一步本身是正收益

**文件：**
- 修改：`a64_tcg_cmpjcc_perf_results.md`
- 修改：`codex_a64_x86_status4_cmpjcc_plan.md`

- [ ] **步骤 1：在同一棵树、同一二进制上只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 2：优先测 `adc64`、`adcsbc64`、`adc32`、`adcsbc32`，并保留 `sbc64` 作为控制项**
- [ ] **步骤 3：记录每组多次运行的 mean / median**
- [ ] **步骤 4：把结论写回 perf/results 和 plan 文档，明确说明这一步是否是全局变慢来源**
