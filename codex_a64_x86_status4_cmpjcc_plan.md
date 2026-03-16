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
