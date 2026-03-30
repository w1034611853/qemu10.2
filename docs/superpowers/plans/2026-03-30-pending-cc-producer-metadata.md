# pending-cc producer 轻量泛化实现计划

> **给执行型 agent 的要求：** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 在不新增任何新直通语义的前提下，把当前 compare-centric 的 `a64_cmp_pending_*` metadata 收敛成统一的 pending-cc producer 小结构，并以 focused correctness + same-binary spot-check 证明这次整理没有引入稳定性能回退。

**架构：** 采用“小 struct 泛化”方案：先引入 `A64PendingCCProducerKind` 和 `A64PendingCCProducer`，再分阶段迁移 init / clear / record / trace / drop / consumer shared predicates，最后移除旧的散落字段和 `a64_cmp_pending_materialized`。整个过程不扩覆盖面、不改 env gate 语义，不改现有 add/sub/cmp direct path 的 emit 形状。

**技术栈：** QEMU AArch64 TCG 前端、x86 host direct flags/carry/borrow 路径、现有 AArch64 focused regression、dedicated `adcsbc-bench` microbenchmark。

---

### 任务 1：先锁住 correctness 和 perf baseline

**文件：**
- 无代码改动；验证为主
- 测试：`build-aarch64-linux-user/qemu-aarch64`
- 测试：`tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- 测试：`build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

- [ ] **步骤 1：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`，确认当前 build 作为 refactor baseline 可用**
- [ ] **步骤 2：运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`**
- [ ] **步骤 3：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`**
- [ ] **步骤 4：运行 `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`**
- [ ] **步骤 5：运行 `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`**
- [ ] **步骤 6：对 `cmnadc64/cmnadc32/addsadc64/addsadc32` 用同一棵树、同一二进制、只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1` 做 3 轮 baseline 采样**
- [ ] **步骤 7：对 `subsbc64/subsbc32` 用同一棵树、同一二进制、只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1` 做 3 轮 baseline 采样**
- [ ] **步骤 8：把 baseline 秒数记到临时工作笔记里，后续每个重构阶段只允许与这组结果基本持平**

### 任务 2：先引入统一数据结构和 clear helper，不改行为

**文件：**
- 修改：`target/arm/tcg/translate.h`
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：在 `target/arm/tcg/translate.h` 中新增 `A64PendingCCProducerKind`，只包含当前树里已经真实存在的 3 类 producer：`REWINDABLE_CMP`、`MATERIALIZED_ADD`、`MATERIALIZED_SUB`**
- [ ] **步骤 2：在 `target/arm/tcg/translate.h` 中新增 `A64PendingCCProducer` 小结构，把当前 `a64_cmp_pending_*` 所承载的信息完整搬进去**
- [ ] **步骤 3：在 `DisasContext` 中增加 `a64_pending_cc`，暂时允许旧字段与新结构短暂并存，只要本阶段行为不变**
- [ ] **步骤 4：在 `target/arm/tcg/translate-a64.c` 中新增统一 clear helper，例如 `a64_clear_pending_cc_producer(DisasContext *s)`**
- [ ] **步骤 5：把 `aarch64_tr_init_disas_context()` 和 translation 尾部 drop 路径先切到新 clear helper**
- [ ] **步骤 6：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 7：重新运行 `nzcv-status4` 与 `cmpstress-o3`，确认“只搬结构、不改语义”的第一阶段没有引入明显回退**

### 任务 3：把 record / trace / drop 统一迁到 `pending_cc`

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：把 `a64_record_cmp_for_bcond()` 演进成统一 record helper，例如 `a64_record_pending_cc_producer(...)`；如果要减 churn，可以保留旧名字作为薄包装**
- [ ] **步骤 2：让 record helper 显式写入 `kind`，不再依赖 `materialized + cc_op` 的侧推**
- [ ] **步骤 3：把 consume / overwrite / drop 相关 trace helper 改为统一读取 `s->a64_pending_cc`**
- [ ] **步骤 4：把 `a64_cmp_pending_valid/keep/sf/...` 这类直接字段访问逐步迁成 `a64_pending_cc.valid/keep/sf/...`**
- [ ] **步骤 5：移除 `a64_cmp_pending_materialized` 的直接写法，用 `kind` 表达 materialized add/sub**
- [ ] **步骤 6：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 7：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...` 与 `nzcv-status4`，确认 compare-like 路径没有因为 metadata 搬运退回旧形状**

### 任务 4：收敛 consumer 共享判断与 canonical raw-state 恢复

**文件：**
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：把“adjacent-only 判定”统一成 `a64_pending_cc_is_adjacent_to_curr_insn()` 一类 helper**
- [ ] **步骤 2：把“pending producer 仍有 live split flags / rewind 状态”的共享判断收敛成 helper**
- [ ] **步骤 3：把 `a64_try_emit_x86_cmp_sbc()` 与 `a64_try_emit_x86_add_adc()` 里的公共入口判定改成读取 `kind + cc_op + rewind`，而不是旧的 compare-centric 布尔拼装**
- [ ] **步骤 4：把 consumer 命中后的 canonical raw-state 恢复收敛成单独 helper，例如 `a64_pending_cc_restore_raw_state_after_consume(...)`**
- [ ] **步骤 5：保留两个 consumer helper 的 emit 细节分离，不要在本任务里把它们合并成一个“大 dispatch”**
- [ ] **步骤 6：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 7：重新运行 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`，确保 `cmnadc/addsadc/subsbc` 对应 block 仍然维持当前 direct codegen 形状**

### 任务 5：删除旧散落字段并完成最终收口

**文件：**
- 修改：`target/arm/tcg/translate.h`
- 修改：`target/arm/tcg/translate-a64.c`

- [ ] **步骤 1：在所有读写点都已迁到 `a64_pending_cc` 后，删除 `DisasContext` 中旧的 `a64_cmp_pending_*` 散落字段**
- [ ] **步骤 2：删除不再需要的中间兼容代码和重复 helper**
- [ ] **步骤 3：保留必要的旧函数名薄包装仅在它们确实能减少 churn 时存在；否则直接切到新 helper**
- [ ] **步骤 4：重新检查 `do_addsub_reg()`、`do_adc_sbc()`、`a64_try_emit_x86_cmp_sbc()`、`a64_try_emit_x86_add_adc()` 这几个核心入口，确认没有残留旧字段访问**
- [ ] **步骤 5：运行 `ninja -C build-aarch64-linux-user qemu-aarch64`**
- [ ] **步骤 6：重新运行 `nzcv-status4`、`cmpstress-o3`、`run-adcsbc-bench`**

### 任务 6：执行性能 hard gate spot-check

**文件：**
- 无代码改动；验证为主

- [ ] **步骤 1：对 `cmnadc64` 做 same-binary 3 轮 spot-check，方法与 baseline 完全一致，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 2：对 `cmnadc32` 做 same-binary 3 轮 spot-check，方法与 baseline 完全一致，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 3：对 `addsadc64` 做 same-binary 3 轮 spot-check，方法与 baseline 完全一致，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 4：对 `addsadc32` 做 same-binary 3 轮 spot-check，方法与 baseline 完全一致，只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`**
- [ ] **步骤 5：对 `subsbc64` 做 same-binary 3 轮 spot-check，方法与 baseline 完全一致，只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`**
- [ ] **步骤 6：对 `subsbc32` 做 same-binary 3 轮 spot-check，方法与 baseline 完全一致，只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`**
- [ ] **步骤 7：把 post-refactor 结果与任务 1 的 baseline 对比；只有在结果基本持平、没有超出噪音的稳定负回退时，这一步才可继续收尾**
- [ ] **步骤 8：如果出现稳定负回退，不要继续写结果文档，先回到最近阶段定位是结构搬运、共享 helper 还是 emit 判定变化导致**

### 任务 7：更新记录文档并形成最终结论

**文件：**
- 修改：`a64_tcg_cmpjcc_perf_results.md`
- 修改：`codex_a64_x86_status4_cmpjcc_plan.md`

- [ ] **步骤 1：如果任务 6 证明结果持平，新增一节记录这次 “pending-cc producer 轻量泛化” 的 focused correctness 与 spot-check 结果**
- [ ] **步骤 2：在结果文档里明确写清：这一步是结构整理，不新增新直通语义；其验收重点是“无稳定性能回退”**
- [ ] **步骤 3：如果出现稳定负回退并决定放弃本重构路径，也要在记录文档里简要记下失败原因，避免后续重复踩坑**
- [ ] **步骤 4：最终再次运行 `ninja -C build-aarch64-linux-user qemu-aarch64`、`tests/tcg/aarch64/check-adc-sbc-host-direct.sh ...`、`nzcv-status4`、`cmpstress-o3`、`run-adcsbc-bench`，作为完成前的 fresh 证据**
