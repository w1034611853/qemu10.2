# QEMU Agent Device (`qemu-agent`)

A Rust SysBus MMIO device that provides two interfaces:

1. **Command interface** – guest asks QEMU to do things (read phys mem, etc.).
2. **Report interface** – guest pushes structured telemetry into QEMU so the
   emulator can react to it in real time.

## Registers (little-endian, 32-bit aligned)

### Common / Control

| Offset | Name            | Access | Description                                                  |
|--------|-----------------|--------|--------------------------------------------------------------|
| 0x00   | MAGIC           | RO     | 0x51454D55 ('QEMU')                                          |
| 0x04   | VERSION         | RO     | 0x00010000                                                   |
| 0x08   | STATUS          | RO     | bit0: READY, bit1: BUSY, bit2: REPORT_READY, bit3: REPORT_OVERRUN |
| 0x0C   | CONTROL         | RW     | bit0: IRQ_EN, bit1: SW_RESET, bit2: REPORT_INT_EN            |

### Command interface

| Offset | Name       | Access | Description                                                  |
|--------|------------|--------|--------------------------------------------------------------|
| 0x10   | COMMAND    | WO     | Write a command code to execute                              |
| 0x14   | ARG0       | RW     | Command argument 0                                           |
| 0x18   | ARG1       | RW     | Command argument 1                                           |
| 0x1C   | ARG2       | RW     | Command argument 2                                           |
| 0x20   | RESULT0    | RO     | Result value 0                                               |
| 0x24   | RESULT1    | RO     | Result value 1                                               |
| 0x28   | IRQ_STATUS | RW1C   | bit0: CMD_DONE, bit1: REPORT                               |

### Report interface (guest → QEMU telemetry)

| Offset | Name          | Access | Description                                                  |
|--------|---------------|--------|--------------------------------------------------------------|
| 0x2C   | REPORT_TYPE   | WO     | Data category (1=CPU, 2=MEM, 3=IO, 4=NET, 0xFF=CUSTOM)      |
| 0x30   | REPORT_V0     | WO     | Value 0                                                      |
| 0x34   | REPORT_V1     | WO     | Value 1                                                      |
| 0x38   | REPORT_V2     | WO     | Value 2                                                      |
| 0x3C   | REPORT_SUBMIT | WO     | Write 1 to latch the report                                  |
| 0x40   | LATCHED_TYPE  | RO     | Latest latched report type                                   |
| 0x44   | LATCHED_V0    | RO     | Latest latched value 0                                       |
| 0x48   | LATCHED_V1    | RO     | Latest latched value 1                                       |
| 0x4C   | LATCHED_V2    | RO     | Latest latched value 2                                       |

## Command protocol

1. Fill `ARG0`..`ARG2`.
2. Write the command code to `COMMAND`.
3. Hardware sets `BUSY=1`, executes, then clears `BUSY` and sets `READY=1` and
   `IRQ_STATUS.CMD_DONE`.
4. Guest reads `RESULT0`/`RESULT1`.

## Report protocol (guest → QEMU)

1. Guest writes `REPORT_TYPE`, `REPORT_V0`..`REPORT_V2`.
2. Guest writes `REPORT_SUBMIT = 1`.
3. Device copies the staging values into `LATCHED_TYPE`/`LATCHED_Vx`, sets
   `STATUS.REPORT_READY` and `IRQ_STATUS.REPORT`.
4. QEMU internal `handle_report()` is called **synchronously** inside the
   emulator.  You can read the latched registers and call any QEMU API to
   change emulation behavior.
5. If `CONTROL.REPORT_INT_EN` is set, the level interrupt is raised.
6. Emulator (or guest) clears `IRQ_STATUS.REPORT` when done.

> If a new report is submitted before the previous one was consumed, the old
> data is overwritten and `STATUS.REPORT_OVERRUN` is set.

## Built-in commands

| Code | Name           | ARG0        | ARG1    | RESULT0              |
|------|----------------|-------------|---------|----------------------|
| 0    | NOP            | —           | —       | 0                    |
| 1    | READ_PHYS_U32  | phys_addr   | —       | value at address     |
| 2    | WRITE_PHYS_U32 | phys_addr   | value   | 0=ok, 1=error        |

## Built-in report types

| Type | Name            | V0              | V1              | V2  |
|------|-----------------|-----------------|-----------------|-----|
| 1    | CPU_USAGE       | percent (0-100) | —               | —   |
| 2    | MEM_USAGE       | used MB         | total MB        | —   |
| 3    | IO_THROUGHPUT   | read KB/s       | write KB/s      | —   |
| 4    | NETWORK_STATS   | rx KB/s         | tx KB/s         | —   |
| 0xFF | CUSTOM          | user-defined    | user-defined    | —   |

## Extending the device

### Add a new command

Open `src/device.rs`, edit `execute_command()`:

```rust
let (res0, res1) = match cmd {
    commands::NOP => (0, 0),
    commands::READ_PHYS_U32 => self.cmd_read_phys_u32(arg0),
    commands::WRITE_PHYS_U32 => self.cmd_write_phys_u32(arg0, arg1),
    0x10 => self.cmd_my_custom_action(arg0), // ← 新命令
    _ => { ... }
};
```

### React to a new report type

Open `src/device.rs`, edit `handle_report()`:

```rust
match typ {
    report_types::CPU_USAGE => { ... }
    report_types::MEM_USAGE => { ... }
    0xAB => {
        // 读取 latched_v0..v2，调用 QEMU API 做调整
        if v0 > 80 {
            // 例如：降低某个设备的频率、注入中断、暂停 VM 等
        }
    }
    _ => { ... }
}
```

因为 `handle_report()` 在 QEMU 大锁（BQL）内执行，你可以安全地调用任何
QEMU 内部 C API。

## QEMU command line usage

```bash
-device qemu-agent,addr=0x09000000
```

## Guest driver sketch

```c
#define REG_REPORT_TYPE   0x2C
#define REG_REPORT_V0     0x30
#define REG_REPORT_V1     0x34
#define REG_REPORT_SUBMIT 0x3C
#define REG_STATUS        0x08
#define REG_IRQ_STATUS    0x28

#define STATUS_REPORT_READY  (1U << 2)
#define CTRL_REPORT_INT_EN   (1U << 2)
#define IRQ_REPORT           (1U << 1)

/* 汇报 CPU 占用率 75% */
agent_writel(mmio, REG_REPORT_TYPE, 1);   // CPU_USAGE
agent_writel(mmio, REG_REPORT_V0, 75);    // 75%
agent_writel(mmio, REG_REPORT_SUBMIT, 1); // 提交

/* 汇报内存使用率 */
agent_writel(mmio, REG_REPORT_TYPE, 2);   // MEM_USAGE
agent_writel(mmio, REG_REPORT_V0, 512);   // used 512MB
agent_writel(mmio, REG_REPORT_V1, 2048);  // total 2048MB
agent_writel(mmio, REG_REPORT_SUBMIT, 1);
```
