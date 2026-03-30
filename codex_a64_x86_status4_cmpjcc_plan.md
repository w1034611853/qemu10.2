# Codex 执行文档：QEMU v7.2 AArch64→x86 TCG 定向优化

## 目标

在 **QEMU v7.2.0** 上，为 **AArch64 guest → x86_64 host** 增加一套面向性能的定向优化，采用下面这条主方案：

- **canonical flags state**：`x86_status4 + x86_cc_op`
- **fast path**：`cmp/subs -> b.cond` 直通成 host `cmp + jcc`

这里的 `x86_status4` 只保存 x86 条件码中 AArch64 后续最常需要的 4 个位：

- `SF`
- `ZF`
- `CF`
- `OF`

`x86_cc_op` 用于解释这 4 个位对应的 AArch64 语义，尤其是：

- `SUB/CMP`：AArch64 `C = !x86_CF`
- `ADD/ADC`：AArch64 `C = x86_CF`
- `LOGIC/TST`：AArch64 `C = 0, V = 0`

## 为什么选这个方案

本方案的核心假设不是“减少 IR 条数”，而是**减少 host 真实执行时间**。

对于 x86 host，`cmp + jcc` 本身极便宜，而且很多 `jcc` 可以与 `cmp` 宏融合；因此，最有价值的热路径是把 **AArch64 `CMP/SUBS` 后紧跟 `B.cond`** 的模式直接翻成 host `cmp + jcc`。官方 TCG/Translator 文档也强调：TB 查找和跳转是热路径，direct block chaining 是关键优化点；TCG globals 则是跨 TB 存活的 canonical state 载体。citeturn219103search2turn219103search3turn219103search16

同时，不能只做 `cmp+jcc` 直通，因为后续仍可能有 `CSEL`、`ADC/SBC`、`MRS NZCV` 等 consumer 读取 flags。为保证 correctness，需要一份**跨 TB 可见**的 canonical flags state。TCG 文档说明 `TEMP_GLOBAL`/global memory alias 是跨 TB 存活的，而 helper/default 调用前 globals 可能需要写回 canonical location。citeturn219103search3

在 canonical state 的选型上，本方案不选：

- 原生 split `NF/ZF/CF/VF`：producer 成本高
- whole `EFLAGS`：保存了大量无关位，且 decode 成本高
- packed ARM NZCV nibble：consumer 最干净，但 producer 端通常更重

因此优先采用折中点：

- `x86_status4`：只保存必要的 4 个 x86 条件码位
- `x86_cc_op`：保存 flags 的语义来源

## 非目标

本轮不做：

- AArch32 / Thumb
- 全局替换共享 `arm_test_cc()` 语义
- 一次性覆盖所有 AArch64 flags producer/consumer
- 一次性改成 packed ARM NZCV canonical state
- 复杂 helper 去 helper 化

本轮只聚焦：

1. 建立正确的 `status4 + cc_op` canonical state
2. 打通 `CMP/SUBS -> B.cond` 直通
3. 保证后续 flags consumer 不会读错

---

# 一、预期成果

完成后应具备：

1. AArch64 `CMP/SUBS` 产生 flags 时，不再强制完整物化原生 split `NF/ZF/CF/VF`
2. `CMP/SUBS` 紧跟 `B.cond` 时，host 后端可发出接近：

```asm
cmp ...
jcc ...
```

3. 同时，必须把一份 `x86_status4 + x86_cc_op` 保存到 `CPUARMState`，供：
   - `B.cond` fallback 路径
   - `CSEL/CSINC/CSINV/CSNEG`
   - `ADC/SBC`
   - `MRS NZCV`
   等后续 consumer 使用
4. 不能修改共享 ARM/A32 路径的语义
5. 不能破坏 TB chaining、条件分支语义、异常恢复语义

---

# 二、数据结构设计

## 2.1 `CPUARMState` 新字段

在 `target/arm/cpu.h` 的 `CPUArchState` 中新增：

```c
uint8_t x86_status4;   /* bit3=SF bit2=ZF bit1=CF bit0=OF */
uint8_t x86_cc_op;     /* enum A64X86CCOp */
uint8_t x86_flags_valid;
uint8_t x86_flags_pad;
```

推荐 `enum A64X86CCOp`：

```c
typedef enum A64X86CCOp {
    A64_X86_CC_INVALID = 0,
    A64_X86_CC_SUB32,
    A64_X86_CC_SUB64,
    A64_X86_CC_ADD32,
    A64_X86_CC_ADD64,
    A64_X86_CC_LOGIC32,
    A64_X86_CC_LOGIC64,
    A64_X86_CC_ADC32,
    A64_X86_CC_ADC64,
    A64_X86_CC_SBC32,
    A64_X86_CC_SBC64,
} A64X86CCOp;
```

说明：

- `x86_status4` 只保存 4 个 x86 flags 位
- `x86_cc_op` 负责把 x86 flags 解释成 AArch64 语义
- `x86_flags_valid` 用于区分：
  - 当前 canonical state 是否来自 x86 flags fast path
  - 若无效，consumer 需回退到原 split-flags 路径

## 2.2 TCG globals

在 `target/arm/translate.c` 中新增 globals：

```c
TCGv_i32 cpu_x86_status4;
TCGv_i32 cpu_x86_cc_op;
TCGv_i32 cpu_x86_flags_valid;
```

并在 `arm_translate_init()` 中初始化：

```c
cpu_x86_status4 = tcg_global_mem_new_i32(cpu_env,
    offsetof(CPUARMState, x86_status4), "x86_status4");

cpu_x86_cc_op = tcg_global_mem_new_i32(cpu_env,
    offsetof(CPUARMState, x86_cc_op), "x86_cc_op");

cpu_x86_flags_valid = tcg_global_mem_new_i32(cpu_env,
    offsetof(CPUARMState, x86_flags_valid), "x86_flags_valid");
```

注意：不要再把 `whole EFLAGS` 作为主 canonical state；这样会引入不必要位、增加 decode 复杂度，并且你已经在现有实现里踩到了 `pushfq/popq` 写 8 字节覆盖 4 字段的问题。

---

# 三、语义约定

## 3.1 `x86_status4` 的位布局

固定定义为：

- bit3 = `SF`
- bit2 = `ZF`
- bit1 = `CF`
- bit0 = `OF`

这不是 ARM NZCV，而是 **x86 四个关键 flags 位的紧凑表示**。

## 3.2 AArch64 consumer 如何解释

### `N`

```c
N = (x86_status4 >> 3) & 1
```

### `Z`

```c
Z = (x86_status4 >> 2) & 1
```

### `V`

```c
V = (x86_status4 >> 0) & 1
```

### `C`

按 `x86_cc_op` 分流：

- `SUB32/SUB64/SBC32/SBC64`：`C = !CF`
- `ADD32/ADD64/ADC32/ADC64`：`C = CF`
- `LOGIC32/LOGIC64`：`C = 0`

这一步必须存在；否则 `SUB/CMP` 的 C 与 `ADD/ADC` 的 C 会混淆。

---

# 四、实现原则

## 4.1 不要改共享 `arm_test_cc()`

只改 **AArch64 路径**。

原因：

- 当前优化只针对 AArch64
- 共享 `arm_test_cc()` 还服务 A32/Thumb 路径
- 共享修改会带来 temp 生命周期、global/temp 混淆、非 A64 路径回归等风险

正确做法：

- 在 `target/arm/translate-a64.c` 中实现 A64-only 的 consumer
- `a64_test_cc()` 优先从 `x86_status4 + x86_cc_op` 解析
- 若 `x86_flags_valid == 0`，再 fallback 到原有 split flags 路径

## 4.2 `cmp+jcc` fast path 只做在 A64 的模式匹配里

只匹配：

- `CMP (imm/reg)`
- `SUBS xzr/wzr, ...` 这种语义等价于 compare 的路径
- 后继紧跟 `B.cond`

不在第一轮覆盖：

- `CSEL`
- `CCMP/CCMN`
- `ADC/SBC`
- 复杂多消费者场景

## 4.3 producer 和 fast path 解耦

同一条 compare producer 需要同时支持：

1. **立即分支消费**：host `cmp + jcc`
2. **架构态保存**：`x86_status4 + x86_cc_op`

也就是说，直通不是替代 canonical save，而是与 canonical save 并存。

---

# 五、分阶段实施步骤

## 阶段 0：清理当前 patch 中的问题

在写新代码前，先清理现有实现中的高风险点：

1. 撤掉 shared `arm_test_cc()` 中对 `get_cpu_*()` 的全局替换
2. 删除 whole `x86_eflags` 方案
3. 删除或停用 `pushfq/popq [mem]` 直接写 `uint32_t` 字段的路径
4. 删除对 `liveness_pass_1()` 中自定义 op 的错误跳过；自定义 op 必须让 liveness 正常识别 def/use
5. 停用 `x86_get_nzcv` 这种“whole flags 输出到 global memory”的过重实现

如果这一步不先做，后续所有调试都很难收敛。

---

## 阶段 1：建立 canonical state（不带 fast path）

目标：先让 `CMP/SUBS` 能正确保存 `x86_status4 + x86_cc_op`，哪怕暂时不做 `jcc` 直通。

### 1.1 新增后端自定义 op

在 `include/tcg/tcg-opc.h` 中新增：

```c
DEF(x86_make_status4_sub_i32, 1, 2, 0, 0)
DEF(x86_make_status4_sub_i64, 1, 2, 0, TCG_OPF_64BIT)
DEF(x86_make_status4_add_i32, 1, 2, 0, 0)
DEF(x86_make_status4_add_i64, 1, 2, 0, TCG_OPF_64BIT)
DEF(x86_make_status4_logic_i32, 1, 1, 0, 0)
DEF(x86_make_status4_logic_i64, 1, 1, 0, TCG_OPF_64BIT)
```

### 1.2 新增 TCG API

在 `include/tcg/tcg-op.h` 中新增包装：

```c
static inline void tcg_gen_x86_make_status4_sub_i64(TCGv_i32 ret,
                                                     TCGv_i64 a,
                                                     TCGv_i64 b);
static inline void tcg_gen_x86_make_status4_sub_i32(TCGv_i32 ret,
                                                     TCGv_i32 a,
                                                     TCGv_i32 b);
```

### 1.3 x86 backend 发射策略

对于 `x86_make_status4_sub_i64(ret, a, b)`：

1. 发 `cmp a, b`
2. 取出 `SF/ZF/CF/OF`
3. 将它们 pack 成 `status4 = (SF<<3) | (ZF<<2) | (CF<<1) | OF`
4. 结果放入 `ret`

注意：这里保存的是 **x86 四状态位**，不是 ARM NZCV。

第一版可直接使用：

- `setcc`
- `movzx`
- `shl`
- `or`

先保证 correctness，再考虑更激进的 micro-opt。

### 1.4 A64 producer 接入

在 `target/arm/translate-a64.c` 里，仅改 compare/subs 语义路径：

- `CMP reg`
- `CMP imm`
- `SUBS` with discarded result / compare-like path

示例：

```c
TCGv_i32 status4 = tcg_temp_new_i32();

if (sf) {
    tcg_gen_x86_make_status4_sub_i64(status4, tcg_rn, tcg_rm);
    tcg_gen_movi_i32(cpu_x86_cc_op, A64_X86_CC_SUB64);
} else {
    TCGv_i32 rn32 = tcg_temp_new_i32();
    TCGv_i32 rm32 = tcg_temp_new_i32();
    tcg_gen_extrl_i64_i32(rn32, tcg_rn);
    tcg_gen_extrl_i64_i32(rm32, tcg_rm);
    tcg_gen_x86_make_status4_sub_i32(status4, rn32, rm32);
    tcg_gen_movi_i32(cpu_x86_cc_op, A64_X86_CC_SUB32);
    tcg_temp_free_i32(rn32);
    tcg_temp_free_i32(rm32);
}

tcg_gen_mov_i32(cpu_x86_status4, status4);
tcg_gen_movi_i32(cpu_x86_flags_valid, 1);
tcg_temp_free_i32(status4);
```

### 1.5 A64 consumer 接入

在 `translate-a64.c` 新增 A64-only consumer：

- `a64_get_n_from_status4()`
- `a64_get_z_from_status4()`
- `a64_get_v_from_status4()`
- `a64_get_c_from_status4_ccop()`

再新增：

```c
static bool a64_can_use_status4(void)
```

实现方式：

- 若 `cpu_x86_flags_valid != 0`，优先从 `status4 + cc_op` 解析
- 否则 fallback 到原来的 split flags 路径

### 1.6 `MRS NZCV` / `MSR NZCV`

第一轮不强制改成只读 `status4`。

先采用保守策略：

- `MRS NZCV` 如果 `x86_flags_valid != 0`，按 `status4 + cc_op` 还原出 AArch64 N/Z/C/V，再拼 bit31:28
- 否则走原有 split flags 路径
- `MSR NZCV` 之后，直接：
  - 更新原有 split flags
  - `cpu_x86_flags_valid = 0`

这样不会破坏现有兼容性。

---

## 阶段 2：加入 `cmp+jcc` fast path

目标：当 compare 后继紧跟 `B.cond` 时，直接发 host `cmp + jcc`。

### 2.1 识别模式

在 `aarch64_tr_translate_insn()` 中，保留最小 lookahead：

- 当前指令是否 `CMP` / compare-like `SUBS`
- 下一条是否 `B.cond`
- 当前 TB 是否还允许继续发分支 fast path

只保留 1 条 lookahead，不做更复杂的窥探。

### 2.2 新增后端 compare op

继续保留自定义 compare op：

```c
x86_cmpi_i32 / x86_cmpi_i64
x86_cmpr_i32 / x86_cmpr_i64
```

这些 op 的职责只做一件事：

- 发 host `cmp`
- **不保存 canonical state**

### 2.3 新增后端 branch op

继续保留自定义：

```c
x86_brcond_eq
x86_brcond_ne
x86_brcond_cs
x86_brcond_cc
...
```

这些 op 负责把 AArch64 cond 映射到正确的 x86 `jcc`：

- `EQ -> JE`
- `NE -> JNE`
- `CS -> JAE` （因为 SUB/CMP 的 A64 C = !CF）
- `CC -> JB`
- `MI -> JS`
- `PL -> JNS`
- `VS -> JO`
- `VC -> JNO`
- `HI -> JA`
- `LS -> JBE`
- `GE -> JGE`
- `LT -> JL`
- `GT -> JG`
- `LE -> JLE`

说明：这里的映射只对 **SUB/CMP 语义下的 x86 flags** 正确，因此必须仅在 compare fast path 中使用。

### 2.4 关键约束：`cmp` 与 `jcc` 必须紧邻

这是整个 fast path 最重要的后端约束。

不要在 `cmp` 和 `jcc` 中间插入：

- 保存 canonical state 的指令
- 额外的标志位解码
- 其他会改 flags 的 host 指令

因为这会破坏 `cmp+jcc` 的最佳执行形态，甚至会让宏融合收益消失。

### 2.5 canonical state 的保存位置

在 fast path 下，canonical state 不能插在 `cmp` 和 `jcc` 中间。

第一轮允许采用较保守的实现：

- `cmp`
- `jcc taken`
- fallthrough 边保存 `status4 + cc_op`
- taken 边保存 `status4 + cc_op`

虽然两条边都会各自保存一次，但可以保证 correctness，且不破坏 `cmp+jcc` 紧邻。

后续如果要进一步优化，再考虑把“`cmp + jcc + save status4`”融合成一个更强的 custom op。

---

## 阶段 3：扩展 consumer（可选）

在 `cmp+b.cond` 跑通并验证收益后，再按优先级逐步扩展：

1. `CSEL/CSINC/CSINV/CSNEG`
2. `ADC/SBC`
3. `MRS NZCV`
4. `CCMP/CCMN`

第一轮不要一口气全做。

---

# 六、关键代码修改点

## 6.1 `target/arm/cpu.h`

新增：

- `x86_status4`
- `x86_cc_op`
- `x86_flags_valid`

## 6.2 `target/arm/translate.h`

新增 extern：

```c
extern TCGv_i32 cpu_x86_status4;
extern TCGv_i32 cpu_x86_cc_op;
extern TCGv_i32 cpu_x86_flags_valid;
```

以及 A64-only helper 声明。

## 6.3 `target/arm/translate.c`

只做 global 初始化。不要在这里改共享 `arm_test_cc()`。

## 6.4 `target/arm/translate-a64.c`

这是主要改动文件：

- `CMP/SUBS` producer
- `B.cond` fast path
- A64-only consumer
- `MRS/MSR NZCV` fallback 逻辑

## 6.5 `include/tcg/tcg-opc.h`

新增：

- `x86_make_status4_sub_i32/i64`
- `x86_make_status4_add_i32/i64`（后续）
- `x86_make_status4_logic_i32/i64`（后续）
- 保留 `x86_cmpi/cmpr`
- 保留 `x86_brcond_*`

## 6.6 `include/tcg/tcg-op.h`

新增 wrapper。

## 6.7 `tcg/i386/tcg-target.c.inc`

新增：

- `tcg_out_x86_make_status4_sub()`
- `x86_cmpi/cmpr` 发射
- `x86_brcond_*` 发射

注意：

- 自定义 op 必须有正确的约束定义
- 不要错误跳过 liveness
- 不要把 global memory side-effect 伪装成普通输出 op

## 6.8 `tcg/tcg.c`

只在需要时为自定义 op 增加生成包装，不要破坏现有通用 pipeline。

---

# 七、参考实现骨架

## 7.1 status4 getter

```c
static TCGv_i32 a64_status4_get_n(void)
{
    TCGv_i32 t = tcg_temp_new_i32();
    tcg_gen_shri_i32(t, cpu_x86_status4, 3);
    tcg_gen_andi_i32(t, t, 1);
    return t;
}

static TCGv_i32 a64_status4_get_z(void)
{
    TCGv_i32 t = tcg_temp_new_i32();
    tcg_gen_shri_i32(t, cpu_x86_status4, 2);
    tcg_gen_andi_i32(t, t, 1);
    return t;
}

static TCGv_i32 a64_status4_get_v(void)
{
    TCGv_i32 t = tcg_temp_new_i32();
    tcg_gen_andi_i32(t, cpu_x86_status4, 1);
    return t;
}

static TCGv_i32 a64_status4_get_c(void)
{
    TCGv_i32 raw_cf = tcg_temp_new_i32();
    TCGv_i32 ret = tcg_temp_new_i32();
    TCGv_i32 is_sub = tcg_temp_new_i32();

    tcg_gen_shri_i32(raw_cf, cpu_x86_status4, 1);
    tcg_gen_andi_i32(raw_cf, raw_cf, 1);

    /* 第一轮只处理 SUB/CMP fast path，可先按 SUB 解释 */
    tcg_gen_mov_i32(ret, raw_cf);
    tcg_gen_xori_i32(ret, ret, 1);

    tcg_temp_free_i32(is_sub);
    tcg_temp_free_i32(raw_cf);
    return ret;
}
```

注意：真正实现时，`a64_status4_get_c()` 必须按 `cpu_x86_cc_op` 分流，不要偷懒只写成 SUB 版本。

## 7.2 A64 conditional branch consumer

```c
static bool a64_emit_bcond_from_status4(DisasContext *s, int cond, target_long diff)
{
    if (!tcg_constant_is_nonzero(cpu_x86_flags_valid)) {
        return false;
    }

    /* 第一轮可以只接 fast path 识别到的 compare 产生的 flags */
    /* 其他情况 fallback 到 arm_gen_test_cc(cond, ...) */
    return false;
}
```

实际编码时，不要试图在这里直接从 `cpu_x86_status4` 再生成 host branch；
如果是 fast path，应该在 producer 位置就保留原生 `cmp` 并立刻接 `jcc`。

---

# 八、验收标准

## 8.1 correctness

必须通过以下最小测试：

### compare + branch

- `cmp x0, #1 ; b.eq`
- `cmp x0, #1 ; b.ne`
- `cmp x0, #1 ; b.cs`
- `cmp x0, #1 ; b.cc`
- `cmp x0, #1 ; b.hi`
- `cmp x0, #1 ; b.ls`
- `cmp x0, #1 ; b.ge`
- `cmp x0, #1 ; b.lt`
- `cmp x0, #1 ; b.gt`
- `cmp x0, #1 ; b.le`

覆盖：

- 相等
- 不等
- 有借位/无借位
- 有符号边界
- 溢出边界

### compare + later consumer

- `cmp ; nop ; csel`
- `cmp ; nop ; mrs nzcv`
- `cmp ; nop ; adc`

要求：即使不是紧邻 `b.cond`，后续 consumer 也不能读错。

### 跨 TB

构造 compare 在 TB 末尾、consumer 在下一 TB 的用例，确认：

- `x86_status4 + x86_cc_op` 能跨 TB 传递
- `x86_flags_valid` 不会丢失

## 8.2 性能

至少测三类 workload：

1. branch-heavy 微基准
2. 普通整数程序
3. 带一定函数调用/内存访问的真实程序

必须比较：

- baseline QEMU
- 仅 canonical state，不做 fast path
- canonical state + cmp+jcc

重点观察：

- host retired instructions
- 分支相关指令占比
- cycles / instruction block
- TB exits

---

# 九、明确禁止事项

1. **不要修改共享 `arm_test_cc()`**
2. **不要继续以 whole `x86_eflags` 作为主 canonical state**
3. **不要在 `cmp` 和 `jcc` 中间插入保存 canonical state 的指令**
4. **不要通过错误地跳过 liveness 来“让自定义 op 先跑起来”**
5. **不要在第一轮就同时改 `CMP`、`ADD`、`LOGIC`、`ADC/SBC` 全部路径**
6. **不要把 A32 一起带上**

---

# 十、建议的 Codex 执行顺序

让 Codex 按下面顺序提交小 patch：

### Patch 1
新增 `CPUARMState` 字段与 TCG globals：

- `x86_status4`
- `x86_cc_op`
- `x86_flags_valid`

### Patch 2
删除现有 whole `x86_eflags` 方案相关代码：

- `x86_eflags`
- `get_cpu_*()`
- `x86_get_nzcv`
- `pushfq/popq` whole-flags 保存路径

### Patch 3
新增 backend op：

- `x86_make_status4_sub_i32`
- `x86_make_status4_sub_i64`

并保证 liveness / constraint 正确。

### Patch 4
在 A64 compare producer 上接入 canonical save。

### Patch 5
实现 A64-only consumer：

- `a64_test_cc()` 优先读 `status4 + cc_op`
- fallback 到原 split flags

### Patch 6
实现 `cmp+jcc` fast path，仅覆盖：

- `CMP imm`
- `CMP reg`
- `B.cond`

### Patch 7
增加 `MRS NZCV` 对 `status4 + cc_op` 的支持。

### Patch 8
补测试与性能测量脚本。

---

# 十一、给 Codex 的明确任务描述

下面这段可以直接作为 Codex 的执行说明：

```text
You are modifying QEMU v7.2.0 for a directed AArch64-guest to x86_64-host TCG optimization.

Implement a canonical flags state using:
- x86_status4: compact x86 condition bits {SF,ZF,CF,OF}
- x86_cc_op: enum describing the producer semantics
- x86_flags_valid: whether canonical x86-derived flags are valid

Do NOT modify shared ARM/A32 condition code logic globally.
Only implement AArch64-specific consumers and fast paths.

Primary fast path:
- recognize AArch64 CMP/SUBS(compare-like) followed immediately by B.cond
- emit host cmp + jcc directly
- still save canonical x86_status4 + x86_cc_op for correctness, but do not place save instructions between cmp and jcc

Important constraints:
- remove the current whole-EFLAGS approach
- do not use pushfq/popq to save whole flags into CPUARMState
- do not skip liveness for custom TCG ops
- keep fallback correctness when later consumers use NZCV

Implement in small patches, in this order:
1. CPUARMState fields + TCG globals
2. remove whole-EFLAGS code
3. add x86_make_status4_sub_i32/i64 backend ops
4. hook A64 CMP producer to save canonical status4+cc_op
5. add A64-only consumer path using status4+cc_op
6. add cmp+jcc fast path for CMP/B.cond
7. add MRS NZCV support from canonical state
8. add tests
```

---

# 十二、最终判断

对当前目标来说，最推荐的落地方式是：

- **canonical state**：`x86_status4 + x86_cc_op`
- **核心性能路径**：`cmp+jcc` 直通
- **兼容性兜底**：A64-only consumer fallback 到原 split flags

这个方案比 whole `EFLAGS` 更轻，也比直接上 packed ARM NZCV 更符合当前“普通程序运行、性能核心在 compare/branch”这个目标。`cmp+jcc` 直通利用了 x86 条件分支热路径的天然优势，而 `TEMP_GLOBAL`/global memory alias 为跨 TB 正确性提供了基础。citeturn219103search2turn219103search3turn219103search16

---

# 2026-03-20 Direction Reset

基于当前真实 workload 测试结果，这份计划从“`status4 + cc_op` 主 canonical state”
调整为下面这条新路线，并以此作为后续 Codex 工作的默认输入：

## 新主线

- **主 canonical state**：`x86_raw_flags + x86_cc_op`
- **兜底状态**：原生 split `NF/ZF/CF/VF`
- **核心原则**：尽可能让后续所有 NZCV consumer 直接消费 `raw_flags`
- **仅在必要时**：lazy 地按需解码某一个 N/Z/C/V 位，或最终退回 split

## 调整原因

- 当前 `cmp + b.cond` 局部收益已经存在，但在 SPEC 等真实 workload 上整体仍慢于
  原版，说明“局部直通收益”没有覆盖“全局状态管理成本”。
- 当前代码里 `RAW` 路径已经具备：
  - 条件判断消费
  - `MRS NZCV`
  - carry-only 消费
  这些基础能力；而 `STATUS4` 设计复杂度更高，但目前并没有形成足够高命中的活跃
  producer/consumer 生态。

## 新路线约束

1. 不以 whole `RFLAGS/EFLAGS` 作为主 canonical state。
2. 不依赖“通用恢复 host flags 寄存器”来获得后续直通。
3. `raw_flags` **不能脱离** `x86_cc_op` 单独使用：
   - `SUB/CMP/SBC`: A64 `C = !x86_CF`
   - `ADD/ADC`: A64 `C = x86_CF`
   - `LOGIC/TST`: A64 `C = 0, V = 0`
4. 后续优化优先级从“producer 端多存一种状态”切换为“consumer 端尽可能直接吃
   raw flags”。

## 后续实现顺序

### Step A

先把所有仍然会强制 `a64_ensure_split_flags()` 的 A64 NZCV consumer 逐个改成：

- 优先直接从 `raw_flags` / 当前 canonical state 提取所需位
- 直接生成结果或直接写回新的 split flags
- 避免为了“保留一部分位”而先整包 materialize split flags

第一批目标：

- `CFINV`
- `RMIF`（尤其是 partial-mask 路径）
- `XAFLAG`
- `AXFLAG`

### Step B

扩展“直接消费 raw flags”的高价值 consumer：

- `CSEL/CSET/CSETM/CSINC/CSINV/CSNEG`
- `FCSEL`
- `CCMP/CCMN`
- `ADC/SBC`
- `MRS NZCV`

### Step C

在 consumer 覆盖面扩大后，再回头判断：

- `STATUS4` 是否彻底删除
- `X86_FLAGS_VALID` 是否仍需要进入 TB key
- 哪些 x86 backend custom op 值得继续扩展

## 给后续 Codex 的执行提示

如果你从这份文档继续工作，默认先做两件事：

1. 扩大 consumer 对 `raw_flags + cc_op` 的直接适用范围
2. 每完成一批 consumer 改造，就补 `tests/tcg/aarch64/nzcv-status4.S`
   用例覆盖对应 corner case

## 2026-03-20 继续优化记录：Synthetic Raw Producers

这一步开始把一部分“显式改写 NZCV”的 producer 也往 `RAW` canonical 收，
不再默认回落到 split flags。

### 已完成

- 新增 `a64_write_raw_flags_from_bits()`：
  - 把任意 ARM `N/Z/C/V` bits 重新编码成 compare/sub 语义的 synthetic
    `raw_flags`
  - 这样现有的 raw consumer（条件判断、`MRS NZCV`、carry consumer）无需额外
    改写就能继续消费
- 以下 producer 已改为直接写 synthetic raw：
  - `CFINV`
  - `RMIF`
  - `XAFLAG`
  - `AXFLAG`
  - `MSR NZCV` / `FCCMP false-literal` / `FCMP` 共享的 `gen_set_nzcv()`
  - `SETF8` / `SETF16`

### 这样做的原因

- 之前这些指令虽然已经能“从 raw 读”，但一旦写回 flags 就会重新落回 split，
  导致后续 consumer 失去 raw fast path。
- 现在它们写成 synthetic raw 后，后面的：
  - `B.cond`
  - `CSEL/FCSEL`
  - `ADC/SBC`
  - `MRS NZCV`
  都还有机会继续沿着 raw canonical 走。

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

## 2026-03-24 继续优化记录：SBCS Compare-Like Producer -> B.cond

这一步继续沿着“让直通 producer 尽可能让 consumer 直接利用”的方向推进，但先只做
`SBCS xzr, ... -> B.cond`。

### 思路

- 不再把 compare-like `SBCS xzr, lhs, rhs` 先完整物化成 raw flags 再给 `B.cond` 消费
- 对这种形态，直接把它改写成：
  - `lhs` 与 `rhs_eff = rhs + borrow_in`
  - 然后复用现有 `cmp + b.cond` fast path

这里 `borrow_in = !C`，因此 `rhs_eff` 正好对应 `SBCS` 的真实减数。

### 已完成

- 在 `do_adc_sbc()` 里为 `setflags && is_sub && rd == 31` 增加 lazy `B.cond` 识别
- 新增 `a64_gen_sbc_cmp_rhs()` 计算 `rhs_eff`
- 命中窗口时不再发 `SBCS` raw-producer，而是记录为 pending compare：
  - `lhs`
  - `rhs_eff`
  - `cc_op = SUB32/SUB64`
- 新增 UT：
  - `0x8f`: `SBCS xzr -> B.cs`
  - `0x90`: `SBCS xzr -> B.mi`

### 当前效果

- `0x8f` 的 `out_asm` 已从：
  - `sbbq ...`
  - 后续单独 `b.hs`
  变成：
  - `rhs_eff` 计算
  - `cmpq`
  - `jae`
- `0x90` 的 `out_asm` 已从：
  - `sbbq ...`
  - 后续单独 `b.mi`
  变成：
  - `rhs_eff` 计算
  - `cmpq`
  - `js`

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

## 2026-03-24 继续优化记录：SBCS Dedicated X86 SBB Producer

这一步只处理 `SBCS` 的 setflags producer。

### 根因

- 泛化到 `subbo/subbio` 的做法不成立
- `tcg/optimize.c` 的 borrow-chain 折叠默认假设前一条 borrowout
  属于同一条减法链
- ARM `SBCS` 的 carry-in 初始化不满足这个假设，因此会被错误改写

### 已完成

- 新增专用 TCG opcode：`x86_sbb_capture_rawflags`
- i386 后端直接发：
  - `bt carry, 0`
  - `cmc`
  - `sbb dst, rhs`
  - `lahf`
  - `seto`
- A64 前端仅在 `SBCS` setflags fast path 上使用这个专用 op
- 非置标志 `SBC` 恢复旧链路：
  - `~rm + adc`
- `SBCS xzr, ...` 这类 compare-style producer 现在允许 direct
- 新增 UT `0x8e`：
  - `SBCS32 -> ADC`

### 当前状态

- `SBCS` 的 raw-producer 路已经不再依赖通用 `subbio` 优化器
- `out_asm` 已确认：
  - `SBCS64` 落成 `btl/cmc/sbbq/lahf/seto`
  - `SBCS32` 落成 `btl/cmc/sbbl/lahf/seto`

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4 cmpstress-o3` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

## 2026-03-20 继续优化记录：Host-Direct Producers/Consumers Follow-Up

这一步开始按 `raw_flags + cc_op` 主线，把真正会被优化器看见的
`host-direct` 语义链补完整。

### 已完成

- 修正 `x86_capture_rawflags` 的建模：
  - 不再“隐式写 env”
  - 改成先产出显式 TCG 值，再 `mov` 到 `cpu_x86_raw_flags`
- 这样优化器不会再把后续 `ADC/MRS NZCV` 错误地折叠成读取旧 raw 值
- `ADDS/ADCS/SBCS` 的 direct raw producer 现在可以正确被同 TB 后续
  consumer 使用
- 新增 `x86_and_capture_rawflags`
  - 当前先用于 `gen_logic_CC()` 的 raw 生成
  - 让 `ANDS` 类 flags producer 通过 host flags 产生 canonical raw
- `ADC/SBC` 非置标志路径现在也直接走 host `adc` carry chain

### 当前状态

- `CMP/SUBS -> B.cond` 直通仍然保留
- `ADDS/ADCS/SBCS` 的 direct raw producer 已可用
- `ANDS` 的 raw producer 已重新接上 host-direct 路径
- `ADC/SBC` 非 flags consumer 也开始直接复用 host carry chain

### 下一步

- 继续把 `LOGIC` 路径从“保守 capture 版”推向真正融合版
- 评估是否要补 `TST/BICS` 的专门 direct op
- 再看 `SUBS/SBCS` 是否值得做更纯粹的 host `sbb` 语义直通

## 2026-03-20 继续优化记录：Fused ANDS/BICS/TST Reg Host-Direct

### 已完成

- `ANDS/BICS/TST` 的 register form 现在不再依赖
  `gen_logic_CC()` 里的“结果算完后再补一次 capture”
- 对可融合的 reg-form，前端会直接发射一条 host `and`
  同时产出：
  - guest result
  - canonical raw flags
- 新增用例：
  - `0x89`: `BICS -> ADC`

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

### 当前边界

- 这一步已经覆盖 `ANDS/BICS/TST` reg-form
- immediate logical forms 仍主要走保守路径
- 后续如果继续做，优先补：
  - logical immediate 的可直通子集

## 2026-03-20 继续优化记录：ANDS/TST Immediate Direct Subset

### 已完成

- `ANDS_i/TST_i` 现在也会导入现有 fused logical direct path
- 当前实现先复用已经验证过的 reg-direct helper：
  - 前端把 logical immediate 作为常量 operand 接进 fused path
  - 后端目前仍可能把该常量物化到寄存器
- 新增用例：
  - `0x8a`: `TST #imm -> ADC`
  - `0x8b`: `ANDS #imm -> ADC`

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

### 当前边界

- 这一步已经让 `ANDS_i/TST_i` 进入 direct 子集
- 但还不是最终形态：
  - 64-bit 逻辑 immediate 仍只覆盖 x86 可直接编码的子集
- 下一步如果继续做，优先继续扩大 64-bit immediate 可直通覆盖

## 2026-03-20 继续优化记录：Immediate-Encoded Logical Capture + SUBS Direct

### 已完成

- 后端 `x86_and_capture_rawflags` / `x86_test_capture_rawflags`
  已支持 immediate 编码形式
- `ANDS_i/TST_i` 不再需要先把常量物化到 host 寄存器，至少对当前
  x86 可直接编码的子集已经能直接发 `and imm` / `test imm`
- `SUBS` 现在也进入 direct producer 路径：
  - host `sub`
  - `lahf/seto`
  - canonical raw flags
- 新增用例：
  - `0x8c`: `SUBS -> ADC`

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

### 当前边界

- 64-bit logical immediate 目前仍只覆盖“x86 imm 可直接编码”的那部分
- 更宽的 64-bit logical immediate 仍会退回当前保守 direct/fallback 路径
- 下一步如果继续做，优先考虑：
  - 扩大 64-bit logical immediate 覆盖
  - 看 `SBC/SBCS` 是否进一步做更纯粹的 `sbb` 风格直通

## 2026-03-20 继续优化记录：Remove STATUS4 Legacy State

在前一步把 `STATUS4` 从翻译主路径收出去之后，这一步把 CPU state 里的遗留也清掉了。

### 已完成

- 删除 `CPUARMState.x86_status4`
- 删除 `A64_X86_FLAGS_STATUS4`
- 删除相关注释和 reset / helper / machine init 中的清零逻辑
- `X86_FLAGS_VALID` 现在语义上只剩：
  - `INVALID`
  - `RAW`

### 结果

- `STATUS4` 现在已经不再存在于代码路径或 CPU state 结构里
- flags canonical state 实际上已经收敛成：
  - `RAW`
  - `SPLIT`
  - 翻译期短暂的 `UNKNOWN`

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

### 下一步建议

- 继续减少“producer 写完后又回 split”的剩余路径
- 再看 `ANDS/TST`、`ADDS/SUBS` 这类更通用的 flags producer
  能否继续往 synthetic raw 收

## 2026-03-20 继续优化记录：CCMP/CCMN Raw Producers

这一步把 `CCMP/CCMN` 从“先写 split 再按条件修补”改成了“局部算 bit，最后直接写
synthetic raw”。

### 已完成

- 新增局部 helper：
  - `a64_gen_add_nzcv_bits()`
  - `a64_gen_sub_nzcv_bits()`
  - 以及对应的 32/64-bit `N/Z/C/V` bit 计算函数
- 重写 `trans_CCMP()`：
  - 不再调用 `gen_add_CC()` / `gen_sub_CC()` 去 materialize split flags
  - 改为先得到 compare/add 的 `N/Z/C/V` bits
  - 再根据条件真假在“计算结果”和 literal `nzcv` 之间选择
  - 最后统一写回 `a64_write_raw_flags_from_bits()`

### 意义

- `CCMP/CCMN` 现在自己也能作为 `RAW` producer 继续往后传 flags
- 后面的 `ADC/SBC`、`CSEL/FCSEL`、`MRS NZCV` 不需要先等它回 split 再消费

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

### 用例补充

- `0x80`: `CCMP true -> ADC`
- `0x81`: `CCMN false literal -> ADC`

## 2026-03-20 继续优化记录：Logic Producers Keep RAW

这一步把 `gen_logic_CC()` 也从 split flags 写法切到了 synthetic raw。

### 已完成

- `ANDS/TST/BICS` 这类逻辑 flags producer 现在：
  - 直接从结果提取 `N/Z`
  - 令 `C=0`、`V=0`
  - 最后统一写回 `a64_write_raw_flags_from_bits()`

### 意义

- 逻辑类 producer 不再天然把 canonical flags 拉回 split
- 后面的 `B.cond`、`CSEL/FCSEL`、`ADC/SBC`、`MRS NZCV`
  都能继续直接复用 raw 路径

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

### 用例补充

- `0x82`: `TST -> ADC`，验证逻辑类 raw producer 的 `C=0`

## 2026-03-20 继续优化记录：Generic Arithmetic Producers Keep RAW

这一步把最常用的算术 flags writer 也统一收进了 synthetic raw。

### 已完成

- `gen_add_CC()`
- `gen_sub_CC()`
- `gen_adc_CC()`

现在这些 helper 不再先 materialize split flags，而是：

- 直接在局部 temp 里得到结果和 `N/Z/C/V` bits
- 然后统一走 `a64_write_raw_flags_from_bits()`

### 直接受益的指令族

- `ADDS/SUBS`
- `CMN/CMP` 的普通 flags 生成路径
- `ADCS/SBCS`
- 依赖这些 helper 的 add/sub immediate / extended / shifted 变体

### 意义

- 现在不只是特殊 producer，连最通用的算术写 flags 路径也能继续留在 raw
- 后续 consumer 更容易直接复用 raw，不再频繁被 split 打断

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

### 用例补充

- `0x83`: `ADCS -> ADC`
- `0x84`: `SBCS -> ADC`

## 2026-03-20 继续优化记录：Collapse STATUS4 Out Of Translation

按既定顺序，这一步开始正式收 `STATUS4` 的状态机冗余。

### 结论确认

- 当前代码里没有找到任何还会写入 `STATUS4` 的活跃 producer
- 搜到的 `x86_status4` 相关写入只剩 reset / 清零路径
- 因此可以先把 `STATUS4` 从翻译期主路径移除

### 已完成

- `hflags` 侧不再把 `STATUS4` 送进 TB 入口态
- TB 初始化时，flags 表示只再区分：
  - `RAW`
  - `SPLIT`
- `UNKNOWN` 路径里的 `STATUS4` 分发已删除，统一变成：
  - `RAW`
  - 非 `RAW` 走 split fallback
- translate 侧所有 `STATUS4` helper / decode path 已删除，包括：
  - `a64_note_flags_status4()`
  - `a64_test_cc_status4_cmp()`
  - `gen_get_nzcv_status4()`
  - `cpu_x86_status4` 的 TCG global

### 当前还保留的遗留物

- `CPUARMState.x86_status4`
- `A64_X86_FLAGS_STATUS4`
- reset / machine init 里的清零逻辑

这些还没删，是为了把“翻译路径收敛”和“CPU state 布局清理”分成两步做。

### 当前验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `run-nzcv-status4` 通过
- `run-cmpstress-o3` 通过

## 2026-03-27 调试记录：531.deepsjeng_r train 早期偏离

当前用 `/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64`
直接跑 `531.deepsjeng_r train`，输出会在第一个局面很早开始偏离参考输出；
`clean5ed` 通过。

本轮已确认的结论：

- `a64_test_cc_bool_i32()` 之前的 debug 自校验有盲点：
  - `RAW/SPLIT/pending-compare` 常见路径会提前 `return`
  - 现在已经修正，bool consumer 的自校验会真正执行
- 在修正 consumer 自校验之后，`531` 仍然偏离，但没有触发：
  - `A64 cc mismatch`
  - `A64 NZCV mismatch`
  - `A64 result mismatch`
- 已做的 runtime 分割实验，偏离模式都没有改变：
  - 关掉 `cmp+b.cond` fastpath
  - 关掉 `cmp_pending` 非 branch consumer
  - 关掉跨 TB raw
  - 关掉 direct flag producers
  - 关掉 non-setflags `ADC/SBC` direct path
  - 强制 generic flags writer 退回 split
  - 强制 `CCMP/CCMN` 走 old split-style 路径

当前最重要的结论：

- `531` 的问题已经**不再像是 runtime flags 优化命中逻辑本身**
- 下一步应优先检查：
  - `qemu10.2` 和 `clean5ed` 之间剩余的静态 TCG/backend 接入差异
  - 或者 target/arm 里仍未被 runtime gate 覆盖到的静态语义差异

## 2026-03-28 修复计划：Raw Canonical 语义层校正

### 当前判断

当前最可疑的问题不是某一条 x86 host 指令发错，而是：

- `cpu_x86_raw_flags + cpu_x86_cc_op`
- 到
- ARM `NZCV` / 条件结果

这套 canonical 语义的编码、解码或状态迁移不完全一致。

已经基本排除或降优先级的方向：

- `cmp + b.cond` fast path 本身
- cross-TB RAW 专门化本身
- `cmp_*_capture_rawflags` 的 `RAX` clobber
- 新 x86 custom opcode 的 TCG plumbing 缺失
- `optimize.c` 里 carry-state kill 不全

### 修复原则

- 先修 canonical 语义层，再继续扩性能优化
- 先抓“独立 reference 和现行实现第一次分叉点”，再改实现
- 不再使用“共享同一套 raw decode 假设”的 debug 对照作为 correctness 依据
- 每修一层，都要用现有 UT 和 SPEC 子集回归

### Task 1: 建立独立 reference 校验点

**目标**

给 raw canonical 语义建立一套与现行 decode 逻辑解耦的 reference，对以下两类结果分别做校验：

- 当前 NZCV
- 当前 condition 结果

**文件**

- Modify: `target/arm/tcg/translate-a64.c`
- Modify: `target/arm/tcg/helper-a64.c`
- Modify: `target/arm/tcg/helper-a64.h`

**步骤**

- [ ] 在 `translate-a64.c` 新增“独立 reference”调试入口
- [ ] 这套 reference 不能复用：
  - `a64_raw_flags_get_c_runtime()`
  - `a64_get_current_nzcv_bits()`
  - `a64_test_cc_rawflags()`
- [ ] 对 `RAW` 状态下的：
  - `NZCV`
  - `b.cond/csel/ccmp/fccmp` 条件结果
  做一次现行实现 vs 独立 reference 对照
- [ ] mismatch 时打印：
  - `pc`
  - `cc_op`
  - `x86_flags_valid`
  - `raw_flags`
  - `expected`
  - `actual`
- [ ] 先用 `531.deepsjeng_r train` 抓第一次分叉

### Task 2: 审计所有 raw canonical writer

**目标**

确认每一条 producer 在写入 canonical flags 时都满足：

- `raw_flags` 编码正确
- `cc_op` 正确
- `x86_flags_valid` 正确

**文件**

- Modify: `target/arm/tcg/translate-a64.c`

**重点函数**

- `a64_write_raw_flags_from_bits()`
- `a64_set_raw_flags_state()`
- `gen_logic_CC()`
- `gen_add_CC()`
- `gen_sub_CC()`
- `gen_adc_CC()`
- `trans_CCMP()`
- `trans_FCCMP()`
- `CFINV/RMIF/XAFLAG/AXFLAG`
- `SETF8/SETF16`
- `MSR/MRS NZCV`

**步骤**

- [ ] 按 producer 分类给每类 writer 补站点编号
- [ ] 每类 writer 都加：
  - reference NZCV
  - 当前 canonical state
  的一致性检查
- [ ] 先跑 UT，确认不会在已知简单用例上误报
- [ ] 再跑 `531`，抓第一类真实出错的 writer

### Task 3: 审计 raw canonical reader

**目标**

确认 consumer 侧对同一份 canonical state 的解释保持一致。

**文件**

- Modify: `target/arm/tcg/translate-a64.c`

**重点函数**

- `a64_get_current_nzcv_bits()`
- `a64_test_cc_rawflags()`
- `a64_test_cc_bool_i32()`
- `a64_raw_flags_get_c_runtime()`

**步骤**

- [ ] 建立 reader side matrix：
  - `eq/ne`
  - `cs/cc`
  - `mi/pl`
  - `vs/vc`
  - `hi/ls`
  - `ge/lt`
  - `gt/le`
- [ ] 对每类条件确认：
  - split 语义
  - raw decode 语义
  完全一致
- [ ] 优先关注 carry 相关条件：
  - `cs/cc`
  - `hi/ls`
  - `adc/sbc`

### Task 4: 审计 RAW/SPLIT 状态迁移

**目标**

确认 TB 入口/出口以及 helper/显式 flags 写入后，运行时状态不会错配。

**文件**

- Modify: `target/arm/tcg/hflags.c`
- Modify: `target/arm/tcg/translate-a64.c`
- Modify: `target/arm/cpu.h`

**重点点位**

- `arm_get_tb_cpu_state()`
- `aarch64_tr_init_disas_context()`
- `aarch64_tr_tb_start()`
- `a64_materialize_split_from_raw_runtime()`
- 所有 split materialize / invalidate 点

**步骤**

- [ ] 检查哪些路径会把 `RAW` 物化成 split
- [ ] 检查物化后是否总是同步清理：
  - `x86_flags_valid`
  - `cc_op` 的可解释性
- [ ] 检查哪些路径仍可能错误保留 `RAW`
- [ ] 对进入 TB 的 `RAW/SPLIT` 入口分别打日志，验证不会命中错误 TB 变体

### Task 5: 最小修复与回归

**目标**

在抓到第一处真实 mismatch 后，只做最小修复，不打包 unrelated 改动。

**文件**

- Modify: `target/arm/tcg/translate-a64.c`
- Modify: `target/arm/tcg/helper-a64.c`
- Modify: `target/arm/tcg/helper-a64.h`
- Optional: `target/arm/tcg/hflags.c`
- Optional: `target/arm/cpu.h`

**步骤**

- [ ] 先写 / 复用最小 UT 覆盖该 mismatch
- [ ] 跑出 fail
- [ ] 实施单点修复
- [ ] 先回归：
  - `nzcv-status4`
  - `cmpstress-o3`
- [ ] 再回归：
  - `500.perlbench_r train`
  - `502.gcc_r train`
  - `531.deepsjeng_r train`
  - `557.xz_r train`
- [ ] 只有 correctness 全绿后，才继续做性能优化

### 执行顺序

严格按以下顺序执行：

1. `Task 1` 抓第一次真实 mismatch
2. `Task 2` 确认是哪类 writer 先写错
3. `Task 3` 确认是不是 reader 解读错
4. `Task 4` 确认是不是 RAW/SPLIT 迁移错
5. `Task 5` 做最小修复并回归

### 暂停项

在 canonical 语义问题解决前，暂停以下工作：

- 扩新的 producer fast path
- 扩新的 consumer fast path
- 做新的性能结论

## 2026-03-28 进展记录：独立 Shadow NZCV Reference

本轮已完成：

- 在 `CPUARMState` 中新增 debug shadow state：
  - `a64_debug_shadow_nzcv`
  - `a64_debug_shadow_valid`
- 新增 helper：
  - `a64_debug_set_shadow_nzcv`
  - `a64_debug_check_shadow_nzcv`
  - `a64_debug_check_shadow_cc`
- 将以下路径改成用 shadow 作为独立 reference：
  - `a64_debug_check_current_nzcv()`
  - `a64_debug_check_cc_bool()`
- 已把 shadow 更新接到：
  - `a64_write_raw_flags_from_bits()`
  - `gen_logic_CC()` direct path
  - `gen_add_CC()` direct path
  - `gen_sub_CC()` direct path
  - `gen_adc_CC()` direct path
  - `a64_try_gen_logic_cc_reg_direct()`
  - `a64_try_gen_logic_tst_direct()`
  - `a64_record_cmp_for_bcond()`
- 已给 `cmp_pending -> b.cond` 两条路径补独立校验：
  - generic `a64_try_emit_cmp_bcond()`
  - x86 `a64_try_emit_x86_cmp_bcond()`

### 本轮验证

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `nzcv-status4` 通过
- `cmpstress-o3` 通过

### 531 结果

使用 `QEMU_A64_CC_DEBUG=1` 运行 `531.deepsjeng_r train`：

- 没有触发：
  - shadow NZCV mismatch
  - shadow cc mismatch
- 但输出前缀仍然很早偏离参考输出

这说明：

- 当前已覆盖到的 canonical flags producer / consumer / branch fastpath
  暂时还没有抓到第一处真实分叉
- 后续应优先检查：
  - 尚未纳入 shadow 的 writer
  - 非 canonical-flags 路径
  - 或 `qemu10.2` 相对 `clean5ed` 的其余 always-active 静态差异

## 2026-03-28 继续诊断：all-off 仍然稳定复现 531 偏离

### 诊断命令

- current `qemu10.2`:
  - `QEMU_A64_DISABLE_HOST_CMPJCC=1`
  - `QEMU_A64_DISABLE_TB_RAW=1`
  - `QEMU_A64_DISABLE_CMP_PENDING_CONSUMERS=1`
  - `QEMU_A64_DISABLE_DIRECT_FLAG_PRODUCERS=1`
  - `QEMU_A64_DISABLE_DIRECT_ADC_SBC=1`
  - `QEMU_A64_FORCE_SPLIT_FLAGS=1`
  - `QEMU_A64_FORCE_OLD_CCMP=1`
- clean 对照：
  - `/home/wangruoyu/qemu_nzcv/clean5ed/build-aarch64-linux-user/qemu-aarch64`

### 结果

- `current all-off` 运行 60s 前缀输出：
  - `/tmp/spec531-alloff.out`
- `clean5ed` 运行 60s 前缀输出：
  - `/tmp/spec531-clean5ed-prefix.out`
- 两者 diff 显示：
  - 从深度 5 开始就出现稳定分叉
  - `clean5ed` 前缀与参考输出一致
  - `current all-off` 与之前默认路径输出前缀一致

### 结论

- 这说明当前 `531` 回归不是“只有在 runtime flags 优化命中时才会发生”的问题
- 即使把现有 runtime flags 开关几乎全关掉，当前树仍然会复现同一错误
- 因此后续调查重点应转向：
  - 当前树相对 `clean5ed` 的 always-active 静态语义差异
  - 尤其是 `translate-a64.c` 中不受环境变量 gating 的公共条件计算/consumer 路径

## 2026-03-28 文件簇隔离：问题压缩到 `translate-a64.c`

### 隔离环境

- 所有新实验目录统一放到：
  - `/home/wangruoyu/qemu_nzcv/backendclean-results`
- 新 worktree：
  - `/home/wangruoyu/qemu_nzcv/backendclean`
- base：
  - `5edaaeeda1`

### 实验 1：clean 前端 + current backend

- 在 `backendclean` 中保留 clean 前端簇
- 仅覆写 current backend 簇：
  - `tcg/tcg.c`
  - `tcg/optimize.c`
  - `tcg/i386/tcg-target-opc.h.inc`
  - `tcg/i386/tcg-target-con-set.h`
  - `tcg/i386/tcg-target.c.inc`
- 为兼容编译，clean `translate-a64.c` 中老 opcode 名称：
  - `INDEX_op_x86_a64_capture_cmp_rawflags`
  - 替换为：
  - `INDEX_op_x86_capture_rawflags`

结果：

- `ninja -C build qemu-aarch64` 通过
- `531.deepsjeng_r train` 60s 前缀输出：
  - `/home/wangruoyu/qemu_nzcv/backendclean-results/spec531/backendclean-prefix.out`
- 与参考输出比较：
  - `PREFIX_MATCH 159`

结论：

- current backend 簇单独不会复现当前主树的早期偏离

### 实验 2：在实验 1 基础上只叠 `cpu.h + hflags.c`

- 覆写：
  - `target/arm/cpu.h`
  - `target/arm/tcg/hflags.c`

结果：

- `ninja -C build qemu-aarch64` 通过
- `531.deepsjeng_r train` 60s 前缀输出：
  - `/home/wangruoyu/qemu_nzcv/backendclean-results/spec531/backendclean-cpuhflags-prefix.out`
- 与参考输出比较：
  - `PREFIX_MATCH 160`

结论：

- `cpu.h + hflags.c` 这组单独也不会复现当前主树的早期偏离

### 实验 3：在实验 2 基础上叠 current `translate-a64.c` 及其编译依赖 helper

- 覆写：
  - `target/arm/tcg/translate-a64.c`
  - `target/arm/tcg/helper-a64.h`
  - `target/arm/tcg/helper-a64.c`
  - `target/arm/helper.c`
  - `target/arm/machine.c`

结果：

- `ninja -C build qemu-aarch64` 通过
- `531.deepsjeng_r train` 60s 前缀输出：
  - `/home/wangruoyu/qemu_nzcv/backendclean-results/spec531/backendclean-translate-prefix.out`
- 与参考输出比较：
  - `FIRST_DIFF 26`
  - `REF:  3     256     0     1162  Bg4 ??`
  - `OUT:  3     256     0     1121  Bg4 ??`

### 当前结论

- 问题已经可以从“后端/前端混合怀疑”压缩到：
  - current `translate-a64.c` 这一组前端改动
- backend 簇不是单独根因
- `cpu.h + hflags.c` 也不是单独根因
- 后续应在 `translate-a64.c` 内继续做子簇隔离：
  - compare-form consumer
  - RAW/SPLIT 入口与 materialize
  - synthetic raw writer
  - `cmp_pending` / future-bcond 路径

### 2026-03-28 实验 4：先切 `translate-a64.c` 里的条件 consumer 子簇

先后加了几个仅用于诊断的环境开关：

- `QEMU_A64_FORCE_OLD_CONDSEL`
  - `trans_CSEL()` / `trans_FCSEL()` 强制走旧 bool-select 路径
- `QEMU_A64_FORCE_OLD_BCOND`
  - `a64_gen_test_cc()` 强制走旧 bool-branch 路径
- `QEMU_A64_FORCE_OLD_CCMP`
  - `trans_CCMP()` 强制走旧 literal/split 逻辑

验证：

- `QEMU_A64_FORCE_OLD_CONDSEL=1`
- `QEMU_A64_FORCE_OLD_BCOND=1`
- `QEMU_A64_FORCE_OLD_CONDSEL=1 QEMU_A64_FORCE_OLD_BCOND=1`
- `QEMU_A64_FORCE_OLD_CCMP=1 QEMU_A64_FORCE_OLD_CONDSEL=1 QEMU_A64_FORCE_OLD_BCOND=1`

结果：

- `531.deepsjeng_r train` 60s 前缀都仍然在第 26 行开始偏离
- 第一行关键差异始终不变：
  - `REF:  3     256     0     1162  Bg4 ??`
  - `OUT:  3     256     0     1121  Bg4 ??`

结论：

- `compare-form consumer` / `cond-select` / `generic b.cond` / `CCMP`
  这整个条件 consumer 子簇，可以整体降优先级

### 2026-03-28 实验 5：确认 `deepsjeng` 实际命中的 special-NZCV 指令

对 `deepsjeng_r_base.mytest-64` 反汇编计数：

- `ccmp`: 85
- `csel`: 189
- `cset`: 69
- `csinc`: 3
- `csneg`: 1
- `fcsel`: 2

没有命中：

- `rmif`
- `setf8`
- `setf16`
- `cfinv`
- `xaflag`
- `axflag`
- `fccmp`
- `adc/adcs/sbc/sbcs`

结论：

- `RMIF/SETF/CFINV/XAFLAG/AXFLAG/FCCMP/ADC/SBC` 这些路径不是 `531` 当前
  早期偏离的主嫌疑

### 2026-03-28 实验 6：再切 producer 子簇

新增诊断开关：

- `QEMU_A64_FORCE_OLD_PRODUCERS`
  - `gen_logic_CC()`
  - `gen_add_CC()`
  - `gen_sub_CC()`
  - `gen_adc_CC()`
  跳过当前 direct/raw 分支，强制退回 split producer

并集验证：

- `QEMU_A64_FORCE_OLD_PRODUCERS=1`
- `QEMU_A64_FORCE_OLD_PRODUCERS=1 QEMU_A64_FORCE_OLD_CCMP=1 QEMU_A64_FORCE_OLD_CONDSEL=1 QEMU_A64_FORCE_OLD_BCOND=1`

结果：

- `531.deepsjeng_r train` 60s 前缀仍然是同一个第 26 行偏离
- 关键值仍然是：
  - `OUT:  3     256     0     1121  Bg4 ??`

附带验证：

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `nzcv-status4` 通过
- `cmpstress-o3` 通过

最新结论：

- 目前这轮 `translate-a64.c` 子簇隔离，已经基本把“当前 flags / condition
  改动族”整体降到低优先级
- 下一步应转去第二条线：
  - 重新做早期执行路径差分
  - 或继续找 `translate-a64.c` 中剩余的 always-active 非 flags 差异

### 2026-03-28 实验 7：早期执行路径差分锁定 always-active 非 flags 语义错误

新的约束：

- 所有新的诊断输出都放到 `~/qemu_nzcv/backendclean-results/spec531`
- 不再用 `/tmp`

方法：

- 对当前树和 `clean5ed` 分别开启 `-d exec,nochain`
- 用 `setarch -R` 关闭 ASLR，避免 PIE 基址噪声
- 比对 guest PC 序列，定位第一处真实分叉
- 再把分叉 PC 映射回 `deepsjeng_r_base.mytest-64` 的符号和反汇编

结果：

- 第一处真实分叉不在 loader，而在 guest 函数 `_Z3genP7state_tPi`
- 当前树比 `clean5ed` 更早走到了 `0x7ffff5fb70b0`
- `0x70b0` 位于 `_Z3genP7state_tPi` 的一个回跳边，说明前面的 bitboard
  逻辑已经被提前清空

进一步定位：

- 检查 `target/arm/tcg/translate-a64.c` 里的 `do_logic_reg()`
- 发现当前树在 `a->n` 为真时，先对 `tcg_rm` 做 `not`，随后 fallback 却固定发
  `tcg_gen_and_i64(tcg_rd, tcg_rn, tcg_rm)`
- 这会把：
  - `ORN` 错算成 `AND` with inverted operand
  - `EON` 错算成 `AND` with inverted operand
- 该错误是 always-active 的非 flags 语义错误，和 `RAW/SPLIT`、`cmp+b.cond`
  家族无关

修复：

- 在 `do_logic_reg()` 中恢复使用原本的 `fn(tcg_rd, tcg_rn, tcg_rm)`
- `tcg_rm` 已经在 `a->n` 分支里按需取反，因此：
  - `BIC` 继续走 `and`
  - `ORN` 恢复走 `or`
  - `EON` 恢复走 `xor`

回归补充：

- 新增 `nzcv-status4` 用例：
  - `0x91`: `ORN64 shifted-reg`
  - `0x92`: `EON64 shifted-reg`
- 参考值用 `lsl + mvn + orr/eor` 构造，避免复用同一条可疑路径

验证：

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4 cmpstress-o3` 通过
- `nzcv-status4` 通过
- `cmpstress-o3` 通过
- `531.deepsjeng_r train` 的 60s 前缀重新与参考输出一致
  - 输出文件：
    - `~/qemu_nzcv/backendclean-results/spec531/current-after-logicfix-prefix.out`
- `531.deepsjeng_r train` 完整输出与参考输出一致
  - `diff -u` 无差异
  - 行数：`579 == 579`
  - 输出文件：
    - `~/qemu_nzcv/backendclean-results/spec531/current-after-logicfix-full.out`
- `500/502/557 train` 重新回归通过
  - `500.perlbench_r`
    - `run_base_train_mytest-64.0000` 五个输出全部 `diff -u` 无差异
    - `run_base_train_mytest-64.0001` 五个输出全部 `diff -u` 无差异
  - `502.gcc_r`
    - `200.opts-O3_-finline-limit_50000.s` 无差异
    - `scilab.opts-O3_-finline-limit_50000.s` 无差异
    - `train01.opts-O3_-finline-limit_50000.s` 无差异
  - `557.xz_r`
    - `input.combined-40-8.out` 无差异
    - `IMG_2560.cr2-40-4.out` 无差异

新的判断：

- `531` 当前已知的早期错误主因不是 canonical flags 语义
- 而是 `translate-a64.c` 里一个 always-active 的 inverted logical op
  fallback 退化错误
- 这次修复后，`500/502/531/557 train` 已全部回归通过
- 下一步可以回到原始目标，继续在正确性基线之上推进 raw-only
  producer/consumer 优化

### 2026-03-28 清理：移除定位期调试代码并重新回归

清理内容：

- 删除 `CPUARMState` 里的 shadow NZCV 调试字段
- 删除 `helper-a64.[ch]` 中的 shadow / mismatch / TB RAW abort helper
- 删除 `translate-a64.c` 里的：
  - `QEMU_A64_*` 诊断开关
  - shadow NZCV / condition 校验辅助函数
  - `FORCE_OLD_*` / `DISABLE_*` / `ABORT_ON_*` 调试路径
  - TB 入口强制 split 的诊断逻辑
- 保留：
  - `do_logic_reg()` 的真实语义修复
  - `nzcv-status4` 新增 `0x91/0x92`

fresh 验证：

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `nzcv-status4` 通过
- `cmpstress-o3` 通过
- `500.perlbench_r train`
  - `run_base_train_mytest-64.0000` 五个输出全部 `diff -u` 无差异
  - `run_base_train_mytest-64.0001` 五个输出全部 `diff -u` 无差异
- `502.gcc_r train`
  - 三个 `.s` 输出全部 `diff -u` 无差异
- `531.deepsjeng_r train`
  - `train.out` 与参考输出 `diff -u` 无差异
- `557.xz_r train`
  - 两个 `.out` 输出全部 `diff -u` 无差异

当前代码状态：

- 调试 scaffolding 已移除
- ARM 侧保留下来的功能性代码改动只剩：
  - `translate-a64.c` 的实际语义修复与优化逻辑
  - `nzcv-status4.S` 的回归用例

### 2026-03-28 下一步设计：Non-setflags ADC/SBC 更贴近 Host Carry Chain

目标：

- 在不引入新 flags 状态模型的前提下，继续收紧 plain `ADC/SBC`
  非置标志路径
- 优先把 plain `SBC` 从当前的 `~rm + adc` 退化形式，改成真正的 host
  `sbb` 风格发射
- `ADC` 保持现有正确路径，只在必要时做同类整理

方案对比：

1. 只改 plain `SBC`
   - 改动面最小
   - 能直接消掉当前 `not + adc` 退化序列
   - 风险最低，优先
2. 同时重写 plain `ADC/SBC`
   - 形式更统一
   - 但 `ADC` 当前已经是 host carry chain，收益边际更小
3. 先做更宽的 consumer 扩面
   - 潜在收益高
   - 但当前 correctness 基线刚恢复，不适合先扩大语义面

本步采用：

- 方案 1

实现计划：

- 先补一个最小代码生成回归：
  - 新增独立 AArch64 asm 测试，只包含 plain `ADC` / plain `SBC`
  - 新增 x86-host `out_asm` 检查脚本
  - 当前预期：`ADC` 直接落成 `adc`，`SBC` 仍然失败在缺少 `sbb`
- 红灯确认后，再最小修改 `translate-a64.c`
- 最后回归：
  - `run-adc-sbc-host-direct-codegen`
  - `run-nzcv-status4`
  - `run-cmpstress-o3`
  - `500/502/531/557 train`

### 2026-03-28 实现：Plain SBC 改成 Borrow-Chain Host `sbb`

完成内容：

- 新增最小测试：
  - `tests/tcg/aarch64/adc-sbc-host-direct.S`
  - `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
  - `tests/tcg/aarch64/Makefile.target` 中新增
    `run-adc-sbc-host-direct-codegen`
- 红灯确认：
  - 当前 plain `ADC` 已经落成 host `adc`
  - 当前 plain `SBC` 仍然是 `not + adc`
  - 新脚本初次失败点就是缺少 host `sbb`

根因：

- plain `SBC` 原实现为了表达 `x - y - !C`，在前端把 `y` 先按位取反，
  再复用 `ADC` 路径
- 这在功能上是对的，但 `out_asm` 退化成 `not + adc`
- 第一次把它改成 `addco(borrow, -1) + subbio` 后，`nzcv-status4`
  触发了 `optimize.c:squash_prev_borrowout` 断言
- 原因是 `fold_subbio()` 在优化器里要求前一条 carry producer 必须是
  borrow-out producer（`subbo/subbio/subb1o`），而不是 `addco`

最终修复：

- 新增 `a64_emit_subbio_i64/i32()`
- 新增 `gen_sbc()`，只用于 non-setflags `SBC`
- x86 路径不再用 `addco` 去种 borrow bit，而是：
  - 先算 `borrow_in = carry_in ^ 1`
  - 再发 `subbo(0, borrow_in)` 建立真正的 borrow-out 状态
  - 再发 `subbio(lhs, rhs)`
- 这样：
  - runtime host code 变成真实 `sbb`
  - TCG 优化器看到的也是一条合法的 borrow 链
- `ADC`、`ADCS/SBCS` 和 flags producer 路径这一步都未改

验证：

- `ninja -C build-aarch64-linux-user qemu-aarch64` 通过
- `ninja -C build qemu-system-aarch64` 通过
- `run-adc-sbc-host-direct-codegen` 通过
- `adc-sbc-host-direct` 运行返回 `RC=0`
- `nzcv-status4` 通过
- `cmpstress-o3` 通过
- `500.perlbench_r train`
  - `run_base_train_mytest-64.0000` 五个输出全部 `diff -u` 无差异
  - `run_base_train_mytest-64.0001` 五个输出全部 `diff -u` 无差异
- `502.gcc_r train`
  - 三个 `.s` 输出全部 `diff -u` 无差异
- `531.deepsjeng_r train`
  - `train.out` 与参考输出 `diff -u` 无差异
  - 行数：`579 == 579`
- `557.xz_r train`
  - 两个 `.out` 输出全部 `diff -u` 无差异

当前状态：

- plain `ADC` 继续使用 host `adc`
- plain `SBC` 现在也使用真正的 host `sbb`
- 这一步没有引入新的 flags state，也没有扩大 consumer 语义面

### 2026-03-28 Perf 计划：Plain ADC/SBC Microbenchmark

目标：

- 单独量化这一步 `plain SBC -> sbb` 的局部收益
- 把局部收益和 SPEC / 系统级噪声分开看

执行顺序：

1. 新增独立 microbenchmark：
   - `tests/tcg/aarch64/adcsbc-bench.c`
   - 风格对齐 `cmpstress-o3.c`
   - 无参数时跑一组短自检，输出固定 hash，便于纳入 `run-*`
   - 有参数时支持：
     - `adc64`
     - `sbc64`
     - `adcsbc64`
     - `adc32`
     - `sbc32`
     - `adcsbc32`
     - 以及自定义迭代次数
2. 先做最小 TDD：
   - 先加 `Makefile` 目标并运行
   - 先确认 benchmark 缺失导致失败
   - 再补 benchmark 实现和 `.out`
3. correctness 回归：
   - `run-adcsbc-bench`
   - `run-nzcv-status4`
   - `run-cmpstress-o3`
4. perf 对比：
   - baseline:
     `/home/wangruoyu/qemu10.2_clean/build-aarch64-linux-user/qemu-aarch64`
   - current:
     `/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64`
   - 每个 mode 跑 5 次，取均值/中位数
   - 优先看：
     - `sbc64`
     - `sbc32`
     - `adcsbc64`
     - `adcsbc32`

判定标准：

- 如果 `sbc*` microbenchmark 没有明确改善，则 plain `SBC -> sbb`
  这一步局部收益有限
- 如果 `sbc*` 有改善但 `adcsbc*` 接近中性，说明热点覆盖仍不足
- 如果 microbenchmark 有改善，再决定是否继续扩 plain `ADC`
  或直接转大 workload perf

### 2026-03-28 Perf 结果：第一轮 `adcsbc-bench`（current vs `qemu10.2_clean`）

配置：

- benchmark:
  `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations:
  `200000000`
- baseline:
  `/home/wangruoyu/qemu10.2_clean/build-aarch64-linux-user/qemu-aarch64`
- current:
  `/home/wangruoyu/qemu10.2/build-aarch64-linux-user/qemu-aarch64`
- 每个 mode 跑 5 次

结果：

- `adc64`
  - base mean/median: `0.428 / 0.428`
  - curr mean/median: `0.479 / 0.475`
  - current 慢约 `11.9%`
- `sbc64`
  - base mean/median: `0.455 / 0.455`
  - curr mean/median: `0.516 / 0.513`
  - current 慢约 `13.4%`
- `adcsbc64`
  - base mean/median: `0.551 / 0.554`
  - curr mean/median: `0.618 / 0.618`
  - current 慢约 `12.2%`
- `adc32`
  - base mean/median: `0.547 / 0.548`
  - curr mean/median: `0.509 / 0.504`
  - current 快约 `7.0%`
- `sbc32`
  - base mean/median: `0.551 / 0.552`
  - curr mean/median: `0.558 / 0.553`
  - current 慢约 `1.3%`
- `adcsbc32`
  - base mean/median: `0.675 / 0.676`
  - curr mean/median: `0.677 / 0.679`
  - 基本持平，current 慢约 `0.3%`

当前解读：

- 这批结果说明“当前整棵实验树”相对 `qemu10.2_clean`，在这组
  `ADC/SBC` microbenchmark 上并没有整体占优
- 但它不能单独回答 “plain `SBC -> sbb` 这一个补丁是否有正收益”，
  因为 current 相对 clean 还包含大量其他 raw-flags / direct-path 改动
- 换句话说：
  - `out_asm` 已确认 plain `SBC` 现在确实落成 `sbb`
  - 但这一步的局部收益，仍可能被当前分支的其它全局开销抵消

下一步：

- 若要单独评估这一步 plain `SBC -> sbb` 的收益，需要做
  `current-with-patch` vs `current-without-patch` 的 A/B
- 如果继续测大 workload，则这批 micro 数据的用途主要是：
  - 说明当前实验树总体还没有在 `ADC/SBC` 热路径上赢过 clean

### 2026-03-28 实现：same-TB adjacent `CMP/SUBS(xzr)` -> plain `SBC` direct consumer

目标：

- 先只打通最窄、最值钱的一条链：
  `CMP/SUBS xzr, rn, rm` 紧邻 `SBC rd, rn2, rm2`
- 不做 cross-TB
- 不做 gap
- 不做 immediate compare producer
- 不碰 `ADC`

关键设计：

- 这里不能做“完全不 capture”的 `cmp; sbb`，因为 plain `SBC`
  不改 ARM `NZCV`，guest flags 仍然应该保留 compare 的结果。
- 因此实现采用：
  - 先发 host `cmp`
  - 立刻用 `lahf/seto` 抓取 compare 的 raw flags
  - 再直接发 host `sbb`
- 这样可以同时满足：
  - consumer 直接利用 live host `CF`
  - guest `NZCV` 仍然保留 compare 语义
  - 避免旧路径里 `raw_flags + cc_op -> carry` 的解码链

实现范围：

- producer 侧仅在 `do_addsub_reg()` 里识别：
  - `setflags && sub_op && rd == 31`
  - 且下一条指令是 plain register-form `SBC`
- 命中后不立即 materialize flags，只记录 `cmp_pending`
- consumer 侧在 `do_adc_sbc()` 的 plain `SBC` 分支优先尝试
  `a64_try_emit_x86_cmp_sbc()`
- 后端新增窄 op：
  - `x86_cmp_sbb_capture_cmp_rawflags`

实现文件：

- `target/arm/tcg/translate-a64.c`
- `tcg/i386/tcg-target-opc.h.inc`
- `tcg/i386/tcg-target-con-set.h`
- `tcg/i386/tcg-target.c.inc`
- `tcg/tcg.c`
- `tcg/optimize.c`

TDD 过程：

- 先把 `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
  改成真正检查 “adjacent `cmp -> sbc` 不再走 carry decode”
- 红灯结果：
  - `adjacent CMP->SBC still decodes carry from canonical flags`
- 然后实现新路径，修掉一次真实参数错位 bug：
  - 新 op 的 TCG dispatch 最初把 tied old-dst 当成 `src`
  - 修正后语义恢复正确

验证：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adc-sbc-host-direct-codegen`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

结果：

- `adc-sbc-host-direct` codegen check pass
- `nzcv-status4` pass
- `cmpstress-o3` pass
- `adcsbc-bench` pass

补充覆盖：

- 新增 `nzcv-status4` 用例 `0x93`：
  - adjacent `CMP + plain SBC`
  - 验证结果值正确
  - 验证 `NZCV` 仍保持 compare 的结果

当前 `out_asm` 形态：

- 旧路径是：
  - `cmp/sub`
  - `lahf/seto`
  - `shr/and/xor/...`
  - borrow seed `sub`
  - `sbb`
- 新路径收成：
  - `cmp`
  - `lahf/seto` capture compare rawflags
  - `sbb`

结论：

- 这一步不是“完全无 capture”的极限直通
- 但已经删除了 plain `SBC` 之前那条最贵的 carry decode 链
- 对正确性是保守安全的，因为 compare flags 仍然被保存为 canonical raw

### 2026-03-28 Step 16 的 isolated A/B 结论

方法：

- 增加窄开关：
  - `QEMU_A64_DISABLE_CMP_SBC_DIRECT=1`
- 同一棵树、同一二进制，对比开启/关闭 step 16
- benchmark:
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

结果摘要：

- `sbc64`
  - median `0.48` vs `0.52`
  - 开启 step 16 快约 `7.7%`
- `adcsbc64`
  - median `0.53` vs `0.59`
  - 开启 step 16 快约 `10.2%`
- `sbc32`
  - median `0.42` vs `0.53`
  - 开启 step 16 快约 `20.8%`
- control `adc64`
  - `0.46` vs `0.46`
  - 基本不变

结论：

- 这一步本身是正收益
- 之前 “current tree 仍然比 clean 慢” 的问题，不是这一步导致的
- 下一步应该继续找：
  - 其它仍然存在的 canonical/raw 开销
  - 或其它 always-active 路径的全局负担

### 2026-03-30 Step 17：same-TB adjacent `CMN / ADDS xzr -> plain ADC`

这一步先按最窄 scope 落地：

- producer 只做 compare-like add：
  - `CMN`
  - `ADDS xzr`
- consumer 只做：
  - same-TB
  - adjacent
  - plain register `ADC`

实现结果：

- A64 前端已接上 add-side pending producer
- i386 后端已新增对应 fused op：
  - producer `add`
  - capture rawflags
  - consumer `adc`
- 新增环境变量开关：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`

验证：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user adc-sbc-host-direct`
- `make -B -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user nzcv-status4`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh build-aarch64-linux-user/qemu-aarch64 build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adc-sbc-host-direct`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/cmpstress-o3`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`

当前结果：

- `adc-sbc-host-direct` codegen check pass
- `nzcv-status4` pass
- `cmpstress-o3` pass
- `adcsbc-bench` pass

这一步过程中确认了两个具体问题：

1. 第一版测试不是真正相邻：
   - `CMN` 和 `ADC` 中间还夹着 `mov`
   - 修正后才命中新路径
2. 第一版 fused op 有寄存器别名 bug：
   - `dst` 作为 scratch 时可能和 `adc_lhs` 重叠
   - 会先踩掉 `adc_lhs`，导致结果错误
   - 最终通过给这条 op 加 early-clobber / new-register 约束修正

关于 perf：

- 我已经做了一轮 same-binary A/B，结果几乎持平
- 但随后确认这是 benchmark 选型问题，不是这一步没收益：
  - 现有 `adcsbc-bench` 的 `adc64/adc32/adcsbc64/adcsbc32`
    实际上测的是 `CMP -> ADC`
  - 而 step 17 优化的是 `CMN / ADDS xzr -> ADC`

所以这一步的下一拍应该是：

- 补 dedicated `CMN->ADC` benchmark mode
- 再用同一棵树、同一二进制，只切
  `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
  做真正的 isolated A/B

### 2026-03-30 Step 17 perf 继续记录：dedicated `cmnadc` benchmark

这一步已经继续往前推进了两格：

1. 补 benchmark mode
2. 跑真正命中 `CMN->ADC` 的 isolated A/B

#### benchmark 扩展

`tests/tcg/aarch64/adcsbc-bench.c` 新增：

- `cmnadc64`
- `cmnadc32`

并且同步更新：

- `tests/tcg/aarch64/adcsbc-bench.out`

这样 `run-adcsbc-bench` 现在会固定回归这两个 mode 的 hash。

#### dedicated A/B 结果

同一棵树、同一二进制，只切：

- `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`

`200000000` iterations：

- `cmnadc64`
  - median `0.33` vs `0.42`
  - 开启 direct 快约 `21.4%`
- `cmnadc32`
  - median `0.48` vs `0.45`
  - 当前实现下开启 direct 反而略慢
- control `adc64`
  - `0.45` vs `0.46`
  - 基本平
- control `adc32`
  - `0.49` vs `0.49`
  - 基本平

再用交错顺序、`400000000` iterations 复测：

- `cmnadc64`
  - 开启：`0.68 0.66 0.65`
  - 关闭：`0.83 0.83 0.83`
  - 64-bit 正收益稳定
- `cmnadc32`
  - 开启：`0.99 0.98 0.98`
  - 关闭：`0.88 0.91 0.89`
  - 32-bit 负收益也稳定

#### 当前判断

- 这一步在 64-bit 上已经证明是正收益
- 但在 32-bit 上，当前版本还不能收“正收益”结论
- `out_asm` 已确认 32-bit 也命中了 `addl + adcl`
- 所以问题不是“没打中”，而是：
  - 当前 i32 fused path 的额外胶水/寄存器开销
  - 还没有被删掉的 carry decode 成本完全抵消

因此，step 17 现在的状态是：

- **64-bit 版本可以认为方向正确**
- **32-bit 版本还需要继续优化，之后再决定是否保留/如何收口**

### 2026-03-30 Step 17 继续记录：`cmnadc32` root cause 已定位并修复

这一步又往前走了一拍，已经不是“32-bit 还需要继续优化但没抓到点”，而是：

- root cause 已经定位
- 最小 backend fix 已经落地
- dedicated A/B 也重新证明 `cmnadc32` 翻回了正收益

#### root cause

之前 `cmnadc32` 虽然命中了 direct path，但 loop `out_asm` 里能看到：

- `addl`
- `pushq`
- `lahf`
- `seto`
- `mov rawflags -> env`
- `popq`
- `adcl`

也就是说，i32 fused path 为了保住 add producer 的 rawflags，
在真正消费 host `CF` 之前，还插了一段 `push/pop` 胶水。

对 64-bit 来说，这段额外成本仍然划算；
但对 32-bit 来说，它足以把删掉 carry decode 的收益基本吃掉，
于是 dedicated `cmnadc32` 才会稳定落到“开启 direct 反而略慢”。

#### backend fix

这次的收口方式是故意收窄的：

- 新增 i32-only opcode：
  `x86_add_adc_capture_add_rawflags_i32`
- 只让 `a64_emit_x86_add_adc_capture_add_rawflags_i32()` 走这条新 opcode
- 约束把输出固定到 `EAX`
- 这样 `lahf/seto` 可以直接覆盖 `EAX`，不需要再为了保 `RAX`
  额外插 `pushq/popq`
- 64-bit opcode 完全不动，避免把已经正收益的 `cmnadc64` 一起扰动

同时补了一条更精确的 codegen 回归：

- `tests/tcg/aarch64/adc-sbc-host-direct.S`
  新增 `w32 cmn->adc`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
  现在会检查：
  `addl` 和对应的 `adcl` 之间不再出现 `push/pop`

#### fresh correctness

这次修完后 fresh 跑过：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`
- `nzcv-status4`
- `cmpstress-o3`

#### fresh dedicated A/B

同一棵树、同一二进制，只切：

- `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`

`200000000` iterations，交错顺序：

- `cmnadc32`
  - 开启 direct：`0.44 0.41 0.40`
  - 关闭 direct：`0.45 0.45 0.46`
  - median `0.41` vs `0.45`
  - 开启 direct 快约 `8.9%`

- `cmnadc64`
  - 开启 direct：`0.32 0.32 0.33`
  - 关闭 direct：`0.41 0.43 0.42`
  - median `0.32` vs `0.42`
  - 开启 direct 快约 `23.8%`

#### 当前结论更新

step 17 现在可以更新为：

- `CMN / ADDS xzr -> ADC64`：正收益，结论稳定
- `CMN / ADDS xzr -> ADC32`：在去掉 `push/pop` 胶水后，也已经回到正收益

所以下一拍不再是“先把 32-bit 救回来”，而是可以进入 phase 2：

- 评估是否继续把这个骨架扩到 `ADDS rd,... -> ADC`

### 2026-03-30 Step 18：same-TB adjacent `ADDS rd -> plain ADC`

这一步已经按 `1.5` 路线落地：

- `ADDS rd` producer 不做 defer
- 继续走现有 direct `gen_add_CC(..., allow_direct = true)`
- 只额外记录：
  - 这条 pending producer 已经 materialize
  - 下一条相邻 plain `ADC` 可以直接消费 live host `CF`
- `ADC` consumer 命中后直接发 plain `addci`
  - 不再从 canonical raw flags decode carry
  - 也不再重做 producer `add`

#### 测试与回归

- `tests/tcg/aarch64/adc-sbc-host-direct.S`
  - 新增 `ADDS64 rd -> ADC`
  - 新增 `ADDS32 rd -> ADC`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
  - 新增对应 codegen 检查
  - 要求 consumer 前不再出现 `shr/and/setcc` carry-decode 链
- `tests/tcg/aarch64/nzcv-status4.S`
  - 新增 `0x96` / `0x97`
  - 同时守住 producer 结果值、consumer 结果值和 producer NZCV
- `tests/tcg/aarch64/adcsbc-bench.c`
  - 新增 dedicated mode：
    - `addsadc64`
    - `addsadc32`
- `tests/tcg/aarch64/adcsbc-bench.out`
  - 新增 golden：
    - `adcsbc-bench addsadc64 0x71aa68192aeb1bd2`
    - `adcsbc-bench addsadc32 0x79399d9e4be66630`

fresh 跑过：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../cmpstress-o3`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

#### isolated A/B

方法：

- same tree
- same binary
- 只切：
  - `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- benchmark：
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations：
  - `200000000`

结果：

- `addsadc64`
  - 开启：`0.33 0.34 0.32`
  - 关闭：`0.42 0.41 0.42`
  - median：`0.33` vs `0.42`
  - 开启 direct 快约 `21.4%`

- `addsadc32`
  - 开启：`0.41 0.42 0.42`
  - 关闭：`0.51 0.50 0.50`
  - median：`0.42` vs `0.50`
  - 开启 direct 快约 `16.0%`

- control `cmnadc64`
  - 开启：`0.34 0.34 0.33`
  - 关闭：`0.41 0.43 0.42`
  - median：`0.34` vs `0.42`

- control `cmnadc32`
  - 开启：`0.40 0.41 0.43`
  - 关闭：`0.45 0.45 0.45`
  - median：`0.41` vs `0.45`

- control `adc64`
  - 开启：`0.46 0.45 0.46`
  - 关闭：`0.45 0.46 0.45`
  - median：`0.46` vs `0.45`
  - 基本持平

- control `adc32`
  - 开启：`0.49 0.50 0.49`
  - 关闭：`0.51 0.50 0.48`
  - median：`0.49` vs `0.50`
  - 基本持平

#### 当前判断

- `ADDS64 rd -> ADC`：正收益，结论稳定
- `ADDS32 rd -> ADC`：正收益，结论稳定
- 这一步本身已经证明是正收益，不是当前整棵树慢于 clean 的来源
- 而且 phase-1 的 `CMN / ADDS xzr -> ADC` control 也继续保持正收益

#### fresh SPEC correctness 复核

这轮又用当前树 fresh 跑了一次已跟踪的 SPEC train 子集：

- `500.perlbench_r`
- `502.gcc_r`
- `531.deepsjeng_r`
- `557.xz_r`

结果：

- `531.deepsjeng_r train`
  - `speccmds.cmd`：`rc=0`
  - `compare.cmd`：`rc=0`
  - `train.out` 行数与参考一致：`579 == 579`

- `502.gcc_r train`
  - `speccmds.cmd`：`rc=0`
  - `compare.cmd`：`rc=0`
  - 三个 `.s` 输出全部 `specdiff rc=0`

- `557.xz_r train`
  - `speccmds.cmd`：`rc=0`
  - `compare.cmd`：`rc=0`
  - 两个 `.out` 输出全部 `specdiff rc=0`

- `500.perlbench_r train`
  - `run_base_train_mytest-64.0000` / `0001` 的 `speccmds.cmd` 都 `rc=0`
  - `0001` 的 `compare.cmd`：`rc=0`
  - `0000` 目录缺 `compare.cmd`，改用逐文件 `cmp -s`
    对 6 个参考输出手工核对，全部一致

所以 step 18 在 UT、microbenchmark 和 fresh SPEC 子集上都仍然保持
correctness 全绿。

### 2026-03-30 Step 19：same-TB adjacent `SUBS rd -> plain SBC`

这一步沿用 step 18 的 `1.5` 路线，但 producer 换成 `SUBS rd`：

- `SUBS rd` producer 不做 defer
- 继续走现有 direct `gen_sub_CC(..., allow_direct = true)`
- 只额外记录：
  - 这条 pending producer 已经 materialize
  - 下一条相邻 plain `SBC` 可以直接消费 live host borrow
- `SBC` consumer 命中后直接发 plain `sbb`
  - 不再从 canonical raw flags decode carry/borrow
  - 也不再重做 producer `sub`

#### 测试与回归

- `tests/tcg/aarch64/adc-sbc-host-direct.S`
  - 新增 `SUBS64 rd -> SBC`
  - 新增 `SUBS32 rd -> SBC`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh`
  - 新增对应 codegen 检查
  - 检查 producer `sub` 到 consumer `sbb` 之间不再出现 decode 链
- `tests/tcg/aarch64/nzcv-status4.S`
  - 新增 `0x98` / `0x99`
  - 同时守住 producer 结果值、consumer 结果值和 producer NZCV
- `tests/tcg/aarch64/adcsbc-bench.c`
  - 新增 dedicated mode：
    - `subsbc64`
    - `subsbc32`
- `tests/tcg/aarch64/adcsbc-bench.out`
  - 新增 golden：
    - `adcsbc-bench subsbc64 0xb87bc1bc406b2d11`
    - `adcsbc-bench subsbc32 0xdd06b595106b03a2`

fresh 跑过：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../cmpstress-o3`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

#### isolated A/B

方法：

- same tree
- same binary
- 只切：
  - `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`
- benchmark：
  - `build-aarch64-linux-user/tests/tcg/aarch64-linux-user/adcsbc-bench`
- iterations：
  - `200000000`

结果：

- `subsbc64`
  - 开启：`0.39 0.37 0.38`
  - 关闭：`0.48 0.48 0.48`
  - median：`0.38` vs `0.48`
  - 开启 direct 快约 `20.8%`

- `subsbc32`
  - 开启：`0.54 0.54 0.53`
  - 关闭：`0.61 0.60 0.59`
  - median：`0.54` vs `0.60`
  - 开启 direct 快约 `10.0%`

- control `sbc64`
  - 开启：`0.41 0.41 0.40`
  - 关闭：`0.40 0.41 0.41`
  - median：`0.41` vs `0.41`
  - 基本持平

- control `sbc32`
  - 开启：`0.47 0.45 0.46`
  - 关闭：`0.46 0.47 0.46`
  - median：`0.46` vs `0.46`
  - 基本持平

#### 当前判断

- `SUBS64 rd -> SBC`：正收益，结论稳定
- `SUBS32 rd -> SBC`：正收益，结论稳定
- 这一步本身已经证明是正收益，不是当前整棵树慢于 clean 的来源
- 控制项 `sbc64/sbc32` 基本持平，说明差异确实对着新路径来的

### 2026-03-30 Step 20：pending-cc producer 轻量泛化

这一步不新增任何新直通语义，纯粹是把已经存在的 metadata 模型收整：

- 在 `translate.h` 中引入：
  - `A64PendingCCProducerKind`
  - `A64PendingCCProducer`
- 把当前真实存在的 3 类 producer 统一收敛为：
  - `REWINDABLE_CMP`
  - `MATERIALIZED_ADD`
  - `MATERIALIZED_SUB`
- 在 `translate-a64.c` 中收敛共享 helper：
  - clear / reset
  - record / trace / drop
  - adjacent-only 判定
  - consumer 命中后的 canonical raw-state 恢复
- `DisasContext` 中原来散落的 `a64_cmp_pending_*` 字段已经删除，
  `a64_pending_cc` 成为唯一真源

#### focused correctness

fresh 跑过：

- `ninja -C build-aarch64-linux-user qemu-aarch64`
- `tests/tcg/aarch64/check-adc-sbc-host-direct.sh ... adc-sbc-host-direct`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../nzcv-status4`
- `build-aarch64-linux-user/qemu-aarch64 -L /usr/aarch64-linux-gnu .../cmpstress-o3`
- `make -C build-aarch64-linux-user/tests/tcg/aarch64-linux-user run-adcsbc-bench`

结果：

- codegen 形状回归：通过
- `nzcv-status4`：`PASS`
- `cmpstress-o3`：`cmpstress-o3 0x03c9d1a1e84724d4`
- `run-adcsbc-bench`：通过

#### performance hard gate

仍然按 spec 里的 hard gate 做 same-binary spot-check：

- same tree
- same binary
- `200000000` iterations
- add-side 只切 `QEMU_A64_DISABLE_ADD_ADC_DIRECT=1`
- sub-side 只切 `QEMU_A64_DISABLE_SUB_SBC_DIRECT=1`

与任务开始前 baseline 的中位数对比：

- `cmnadc64`
  - baseline：`0.34` vs `0.43`
  - refactor 后：`0.36` vs `0.42`
- `cmnadc32`
  - baseline：`3.15` vs `3.18`
  - refactor 后：`3.17` vs `3.18`
  - 这项有噪音，但中位数没有稳定负回退
- `addsadc64`
  - baseline：`0.35` vs `0.42`
  - refactor 后：`0.35` vs `0.42`
- `addsadc32`
  - baseline：`0.47` vs `0.50`
  - refactor 后：`0.42` vs `0.50`
- `subsbc64`
  - baseline：`0.38` vs `0.46`
  - refactor 后：`0.35` vs `0.46`
- `subsbc32`
  - baseline：`0.51` vs `0.55`
  - refactor 后：`0.50` vs `0.54`

#### 当前判断

- 这一步没有新增新优化语义
- focused correctness 维持全绿
- six-mode spot-check 未出现超出噪音的稳定负回退
- 所以这次轻量泛化可以收

下一步可以顺着这个骨架继续看：

- 再往更中性的 pending-producer metadata 收一小步
- 或者开始评估下一类相邻 producer/consumer 直通
