# extended-form `ADDS/SUBS/CMN/CMP -> ADC/SBC` 直通实现计划

> **给执行型 agent 的要求：** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 让 `do_addsub_ext()` 支持 same-TB adjacent 的 extended-form `CMN/CMP/ADDS/SUBS -> plain ADC/SBC` x86 direct-consumer 路径，并用 focused correctness + dedicated `_ext` benchmark 证明语义正确且无稳定性能负回退。

**架构：** 沿用现有 `pending_cc.kind + cc_op + lhs/rhs` 骨架，不新增新 env gate，不重做 consumer 主体逻辑。compare-like ext producer 命中时跳过旧的 flags lowering，materialized ext producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`；同时显式保护现有 `SUBS xzr,<ext> -> B.cond` fast path，不让新的相邻 `ADC/SBC` 预判误伤它。

**技术栈：** QEMU AArch64 TCG 前端、x86 host ADC/SBB / cmp+jcc direct path、AArch64 汇编回归、`adcsbc-bench` `_ext` microbenchmark。

---

### 任务 1：先锁住当前 focused baseline

**文件：**
- 无代码改动；验证为主
- 测试：`build-aarch64-linux-user/qemu-aarch64`
- 测试：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

- [ ] **步骤 1：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`，确认当前 build 可作为 ext-form 实现起点**
- [ ] **步骤 2：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 5：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`**
- [ ] **步骤 6：确认当前 benchmark 还没有 `_ext` dedicated mode，避免后续误把 register-form 结果当成 ext-form 收益**

### 任务 2：先写 ext-form `ADC/SBC` host-direct 红灯测试

**文件：**
- 修改：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 修改：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

- [ ] **步骤 1：在 `tests/tcg/aarch64/adc-sbc-host-direct.S` 中新增 ext-form guest case，至少覆盖**
  - `CMN <ext> -> ADC` 的 64-bit/32-bit case
  - `CMP <ext> -> SBC` 的 64-bit/32-bit case
  - `ADDS rd,<ext> -> ADC` 的 64-bit/32-bit case
  - `SUBS rd,<ext> -> SBC` 的 64-bit/32-bit case
- [ ] **步骤 2：在 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh` 中新增这些 case 的 codegen 断言，先写成会失败的检查**
- [ ] **步骤 3：运行 `ninja -C build-aarch64-linux-user build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`**
- [ ] **步骤 4：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`，确认新加的 ext-form case 在当前树下正确红灯**

### 任务 3：给 ext-form `B.cond` 先立独立保护红灯

**文件：**
- 创建：`tests/tcg/aarch64/cmp-bcond-ext-host-direct.S`
- 创建：`tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh`
- 修改：`tests/tcg/aarch64/Makefile.target`

- [ ] **步骤 1：新增一个最小 ext-form `SUBS xzr,<ext> -> B.eq` 汇编测试，只覆盖 future-branch fast path，不混入 `ADC/SBC` consumer**
- [ ] **步骤 2：新增 `tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh`，在 `-d in_asm,out_asm` 输出里定位这段 guest block，并断言它仍然命中 `cmp+jcc` 风格 host codegen**
  - 至少检查 host block 中出现 `cmpq/cmpl`
  - 至少检查后续条件跳转是 `jcc`
  - 并显式排除 canonical flags decode 形状，例如 `lahf/seto`、`shr/and/setcc`
- [ ] **步骤 3：在 `tests/tcg/aarch64/Makefile.target` 中新增对应 run target，名字固定为 `run-cmp-bcond-ext-host-direct-codegen`**
- [ ] **步骤 4：运行 `ninja -C build-aarch64-linux-user build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct`**
- [ ] **步骤 5：运行新的 codegen 检查脚本，确认它在实现前是红灯或至少能准确暴露当前 ext-form 空白/顺序问题**

### 任务 4：实现 materialized ext producer 直通

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`
- 测试：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 测试：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`

- [ ] **步骤 1：在 `do_addsub_ext()` 中补上与 `do_addsub_reg()` 对齐的相邻 `plain ADC/SBC` 预判**
- [ ] **步骤 2：先只接 materialized ext producer**
  - `ADDS rd, rn, rm, <ext> -> plain ADC`
  - `SUBS rd, rn, rm, <ext> -> plain SBC`
- [ ] **步骤 3：让 materialized ext producer 继续走现有 `gen_add_CC()` / `gen_sub_CC()`，并在命中后记录 `pending_cc.kind = MATERIALIZED_ADD/SUB`**
- [ ] **步骤 4：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 5：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`，确认 materialized ext case 从红灯变绿**

### 任务 5：实现 compare-like ext producer 直通，并保护 `B.cond` 优先级

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`
- 测试：`tests/tcg/aarch64/adc-sbc-host-direct.S`
- 测试：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 测试：`tests/tcg/aarch64/cmp-bcond-ext-host-direct.S`
- 测试：`tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh`

- [ ] **步骤 1：在 `do_addsub_ext()` 中补上 compare-like ext producer 的相邻预判**
  - `SUBS xzr, rn, rm, <ext> / CMP ... <ext> -> plain SBC`
  - `ADDS xzr, rn, rm, <ext> / CMN ... <ext> -> plain ADC`
- [ ] **步骤 2：保持 `a64_find_future_bcond_gap()` 的判断优先于相邻 plain `SBC`，防止误伤现有 `B.cond` fast path**
- [ ] **步骤 3：命中 compare-like ext direct path 时，跳过旧 `gen_add_CC()` / `gen_sub_CC()` lowering**
- [ ] **步骤 4：记录 `pending_cc.kind = A64_PENDING_CC_REWINDABLE_CMP`，并确保 `pending_cc.rhs` 使用的是 `ext_and_shift_reg()` 之后的 live `tcg_rm`**
- [ ] **步骤 5：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 6：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`，确认 compare-like ext case 转绿**
- [ ] **步骤 7：运行 `tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh ...`，确认 ext-form `B.cond` 保护仍然为绿**

### 任务 6：补 ext-form 语义红灯并跑绿

**文件：**
- 修改：`tests/tcg/aarch64/nzcv-status4.S`
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：在 `tests/tcg/aarch64/nzcv-status4.S` 中新增 ext-form compare-like 与 materialized producer 的 64-bit/32-bit 语义 case**
- [ ] **步骤 2：额外补一个 ext-form `SUBS xzr,<ext> -> shared B.eq consumer` 语义 case，保护 future-branch fast path**
- [ ] **步骤 3：先运行 `ninja -C build-aarch64-linux-user build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`，确认新 case 能正确暴露实现问题；如果前面实现已覆盖，则至少确认去掉实现后会失败**
- [ ] **步骤 5：修正前端实现里暴露出的 ext-form 语义问题**
- [ ] **步骤 6：重新运行 `nzcv-status4`，确认回归转绿**

### 任务 7：给 benchmark 补 `_ext` dedicated mode

**文件：**
- 修改：`tests/tcg/aarch64/adcsbc-bench.c`
- 修改：`tests/tcg/aarch64/adcsbc-bench.out`

- [ ] **步骤 1：在 `tests/tcg/aarch64/adcsbc-bench.c` 中新增 `_ext` dedicated mode，至少包含**
  - `cmnadc64_ext`
  - `cmnadc32_ext`
  - `addsadc64_ext`
  - `addsadc32_ext`
  - `cmpsbc64_ext`
  - `cmpsbc32_ext`
  - `subsbc64_ext`
  - `subsbc32_ext`
- [ ] **步骤 2：确保这些 mode 真正使用 `ADD/SUB (extended register)` 编码，而不是把扩展结果预先算进通用寄存器后退回 register-form**
- [ ] **步骤 3：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`，观察 `.out` 红灯**
- [ ] **步骤 4：更新 `tests/tcg/aarch64/adcsbc-bench.out` 为新的 hash**
- [ ] **步骤 5：再次运行 `run-adcsbc-bench`，确认 benchmark regression 绿灯**

### 任务 8：做 focused correctness 全量回归

**文件：**
- 无代码改动；验证为主

- [ ] **步骤 1：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 2：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`**
- [ ] **步骤 3：运行 `tests/tcg/aarch64/check-cmp-bcond-ext-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmp-bcond-ext-host-direct`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 5：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 6：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`**

### 任务 9：执行 `_ext` perf hard gate

**文件：**
- 无代码改动；验证为主

- [ ] **步骤 1：对 `cmnadc64_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 2：对 `cmnadc32_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 3：对 `addsadc64_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 4：对 `addsadc32_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 5：对 `cmpsbc64_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_CMP_SBC_DIRECT=1`**
- [ ] **步骤 6：对 `cmpsbc32_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_CMP_SBC_DIRECT=1`**
- [ ] **步骤 7：对 `subsbc64_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`**
- [ ] **步骤 8：对 `subsbc32_ext` 做 same-binary 3 轮 A/B，只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`**
- [ ] **步骤 9：A/B 默认口径固定为 `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench <mode> 200000000`，每侧 3 轮，结果按中位数记录**
- [ ] **步骤 10：对 `cmnadc32_ext` 与 `cmpsbc32_ext` 再各做一轮更长迭代的 spot-check，口径固定为 `400000000` iterations，确认不是短跑噪音**
- [ ] **步骤 11：如果某一条 ext 子路径稳定负收益，先暂停收尾，优先通过 producer 侧 scope narrowing 裁掉单一路径，而不是扩大到整家族回滚**

### 任务 10：更新记录文档并完成收尾验证

**文件：**
- 修改：`a64_tcg_cmpjcc_perf_results.md`
- 修改：`codex_a64_x86_status4_cmpjcc_plan.md`

- [ ] **步骤 1：把 ext-form focused correctness 结果写入 `a64_tcg_cmpjcc_perf_results.md`**
- [ ] **步骤 2：把 `_ext` dedicated A/B 结果和结论写入 `a64_tcg_cmpjcc_perf_results.md`**
- [ ] **步骤 3：把本次实现状态与是否发生 scope narrowing 写回 `codex_a64_x86_status4_cmpjcc_plan.md`**
- [ ] **步骤 4：最终再次运行 `ninja -C build-aarch64-linux-user qemu-aarch64`、`check-adc-sbc-host-direct.sh ...`、`check-cmp-bcond-ext-host-direct.sh ...`、`nzcv-status4`、`cmpstress-o3`、`run-adcsbc-bench` 作为 fresh 证据**
