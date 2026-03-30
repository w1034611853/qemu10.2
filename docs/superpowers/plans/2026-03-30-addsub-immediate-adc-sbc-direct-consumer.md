# immediate-form `ADDS/SUBS/CMN/CMP -> ADC/SBC` 直通实现计划

> **给执行型 agent 的要求：** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 让 `do_addsub_imm()` 支持 same-TB adjacent 的 immediate-form `CMN/CMP/ADDS/SUBS -> plain ADC/SBC` x86 direct-consumer 路径，并用 focused correctness + dedicated immediate benchmark 证明语义正确且无稳定性能负回退。

**架构：** 沿用现有 `pending_cc.kind + cc_op` 骨架，不新增新 env gate，不重做 consumer 主体逻辑。materialized immediate producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`；compare-like immediate producer 则在命中 direct path 时跳过旧 flags lowering，并把 `#imm` 先物化成 temp 以满足当前 fused op 的非-constant 约束。

**技术栈：** QEMU AArch64 TCG 前端、x86 host ADC/SBB direct path、AArch64 focused regression、`adcsbc-bench` immediate-mode microbenchmark。

---

### 任务 1：先锁住当前 focused baseline

**文件：**
- 无代码改动；验证为主
- 测试：`build-aarch64-linux-user/qemu-aarch64`
- 测试：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

- [ ] **步骤 1：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`，确认当前 build 作为实现起点可用**
- [ ] **步骤 2：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 5：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`**
- [ ] **步骤 6：确认当前 benchmark 还没有 immediate dedicated mode，避免后续误用 register-form mode 代表新路径收益**

### 任务 2：先写 immediate host-direct 红灯测试

**文件：**
- 修改：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 修改：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

- [ ] **步骤 1：在 `tests/tcg/aarch64/adc-sbc-host-direct.S` 中新增 immediate-form guest case，至少覆盖**
  - `CMN #imm -> ADC` 的 64-bit/32-bit case
  - `CMP #imm -> SBC` 的 64-bit/32-bit case
  - `ADDS rd,#imm -> ADC` 的 64-bit/32-bit case
  - `SUBS rd,#imm -> SBC` 的 64-bit/32-bit case
- [ ] **步骤 2：在 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh` 中新增这些 case 的 codegen 断言，先写成会失败的检查**
- [ ] **步骤 3：运行 `ninja -C build-aarch64-linux-user build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`**
- [ ] **步骤 4：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`，确认新加的 immediate case 在当前树下正确红灯**

### 任务 3：实现 materialized immediate producer 直通

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`
- 测试：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 测试：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

- [ ] **步骤 1：在 `do_addsub_imm()` 中补上与 `do_addsub_reg()` 对齐的相邻 `plain ADC/SBC` 预判**
- [ ] **步骤 2：先只接 materialized immediate producer**
  - `ADDS rd,#imm -> plain ADC`
  - `SUBS rd,#imm -> plain SBC`
- [ ] **步骤 3：让 materialized immediate producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`，并在命中后记录 `pending_cc.kind = MATERIALIZED_ADD/SUB`**
- [ ] **步骤 4：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 5：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`，确认 materialized immediate case 从红灯变绿**

### 任务 4：实现 compare-like immediate producer 直通

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`
- 测试：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 测试：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

- [ ] **步骤 1：在 `do_addsub_imm()` 中补上 compare-like immediate producer 的相邻预判**
  - `SUBS xzr,#imm / CMP #imm -> plain SBC`
  - `ADDS xzr,#imm / CMN #imm -> plain ADC`
- [ ] **步骤 2：命中 compare-like immediate direct path 时，跳过旧 `gen_add_CC()` / `gen_sub_CC()` lowering**
- [ ] **步骤 3：为 compare-like immediate 的 `#imm` 新增局部 temp materialization，并把这个 live temp 记录到 `pending_cc.rhs`**
- [ ] **步骤 4：确保现有 `SUBS xzr,#imm -> B.cond` 的 bcond-only 路径仍然保留原来的 constant-based record 逻辑**
- [ ] **步骤 5：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 6：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`，确认 compare-like immediate case 也全部转绿**

### 任务 5：补语义红灯并跑绿

**文件：**
- 修改：`tests/tcg/aarch64/nzcv-status4.S`
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：在 `tests/tcg/aarch64/nzcv-status4.S` 中新增 immediate-form 语义 case，分别覆盖 compare-like 与 materialized producer 的 64-bit/32-bit 组合**
- [ ] **步骤 2：先运行 `ninja -C build-aarch64-linux-user build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`，确认新 case 在实现未完整前能正确暴露问题；如果前面实现已覆盖，则至少确认新 case 会在去掉实现时失败**
- [ ] **步骤 4：修正前端实现中暴露出的 immediate 语义问题**
- [ ] **步骤 5：重新运行 `nzcv-status4`，确认回归转绿**

### 任务 6：给 benchmark 补 immediate dedicated mode

**文件：**
- 修改：`tests/tcg/aarch64/adcsbc-bench.c`
- 修改：`tests/tcg/aarch64/adcsbc-bench.out`

- [ ] **步骤 1：在 `tests/tcg/aarch64/adcsbc-bench.c` 中新增 immediate-form dedicated mode，至少包含**
  - `cmnadc64_imm`
  - `cmnadc32_imm`
  - `addsadc64_imm`
  - `addsadc32_imm`
  - `subsbc64_imm`
  - `subsbc32_imm`
- [ ] **步骤 2：让这些 mode 真正使用 immediate producer，而不是重新落回 register-form**
- [ ] **步骤 3：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`，观察 `.out` 红灯**
- [ ] **步骤 4：更新 `tests/tcg/aarch64/adcsbc-bench.out` 为新的 hash**
- [ ] **步骤 5：再次运行 `run-adcsbc-bench`，确认 benchmark regression 绿灯**

### 任务 7：做 focused correctness 全量回归

**文件：**
- 无代码改动；验证为主

- [ ] **步骤 1：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 2：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 5：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`**

### 任务 8：执行 immediate dedicated perf hard gate

**文件：**
- 无代码改动；验证为主

- [ ] **步骤 1：对 `cmnadc64_imm` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 2：对 `cmnadc32_imm` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 3：对 `addsadc64_imm` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 4：对 `addsadc32_imm` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 5：对 `subsbc64_imm` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`**
- [ ] **步骤 6：对 `subsbc32_imm` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`**
- [ ] **步骤 7：记录 compare-like immediate 的 temp materialization 是否带来稳定负回退；若有，就暂停收尾，先决定是否只保留 materialized immediate producer**

### 任务 9：更新记录文档并完成收尾验证

**文件：**
- 修改：`a64_tcg_cmpjcc_perf_results.md`
- 修改：`codex_a64_x86_status4_cmpjcc_plan.md`

- [ ] **步骤 1：把 focused correctness 结果写入 `a64_tcg_cmpjcc_perf_results.md`**
- [ ] **步骤 2：把 immediate dedicated A/B 结果和结论写入 `a64_tcg_cmpjcc_perf_results.md`**
- [ ] **步骤 3：把本次实现状态写回 `codex_a64_x86_status4_cmpjcc_plan.md`**
- [ ] **步骤 4：最终再次运行 `ninja -C build-aarch64-linux-user qemu-aarch64`、`check-adc-sbc-host-direct.sh ...`、`nzcv-status4`、`cmpstress-o3`、`run-adcsbc-bench` 作为 fresh 证据**

## 实施后更新（2026-03-30）

计划执行到 perf hard gate 后，最终做了一个刻意的范围收窄：

- 保留大部分 immediate-form direct-consumer 路径
- 单独移除 `CMN32 / ADDS xzr,#imm -> ADC32` 的 compare-like direct producer

原因：

- full-scope immediate 版本里，只有 `cmnadc32_imm` 是稳定负回退
- 这符合 plan 里“若 compare-like immediate 带来稳定负回退，就暂停收尾并裁剪范围”
  的预案

实现落点：

- `do_addsub_imm()` 中 compare-like immediate add 只在 `sf=1` 时设置
  `lazy_adc_add`
- `check-adc-sbc-host-direct.sh` 取消对 `cmn-imm->adc32` host-direct codegen
  的硬断言
- guest 语义 case 与 benchmark mode 保留，便于继续观察这条路径

收窄后 fresh 结果：

- `ninja -C build-aarch64-linux-user qemu-aarch64`：通过
- `check-adc-sbc-host-direct.sh`：通过
- `nzcv-status4`：`PASS`
- `cmpstress-o3`：`cmpstress-o3 0x03c9d1a1e84724d4`
- `run-adcsbc-bench`：通过

收窄后 add-side immediate A/B：

- `cmnadc64_imm`
  - `200000000` iterations：`0.33 0.34 0.33` vs `0.36 0.38 0.37`
  - `400000000` spot-check：`0.65 0.65` vs `0.72 0.74`
- `cmnadc32_imm`
  - `200000000` iterations：`0.35 0.35 0.35` vs `0.35 0.34 0.34`
  - `400000000` spot-check：`0.71 0.71` vs `0.69 0.68`

结论：

- 收窄后，`cmnadc64_imm` 继续保留正收益
- `cmnadc32_imm` 不再复现原先 15%+ 的明显稳定负回退
- immediate-form 这一步可以按“保留其余路径、排除单一亏损点”来收
