// SPDX-License-Identifier: GPL-2.0-or-later

//! Register definitions for the QEMU Agent device.

use common::TryInto;

/// MMIO register offsets for the QEMU Agent device.
#[allow(non_camel_case_types)]
#[repr(u64)]
#[derive(Debug, Eq, PartialEq, TryInto)]
pub enum RegisterOffset {
    /// Magic ID register (RO) - returns 0x51454D55 ('QEMU')
    MAGIC = 0x00,
    /// Version register (RO) - returns 0x00010000
    VERSION = 0x04,
    /// Status register (RO)
    STATUS = 0x08,
    /// Control register (RW)
    CONTROL = 0x0C,
    /// Command register (WO) - write to execute a control command
    COMMAND = 0x10,
    /// Argument 0 (RW)
    ARG0 = 0x14,
    /// Argument 1 (RW)
    ARG1 = 0x18,
    /// Argument 2 (RW)
    ARG2 = 0x1C,
    /// Result 0 (RO)
    RESULT0 = 0x20,
    /// Result 1 (RO)
    RESULT1 = 0x24,
    /// Interrupt status (RW1C)
    IRQ_STATUS = 0x28,
    /// Report type (WO) - data category being reported
    REPORT_TYPE = 0x2C,
    /// Report value 0 (WO)
    REPORT_V0 = 0x30,
    /// Report value 1 (WO)
    REPORT_V1 = 0x34,
    /// Report value 2 (WO)
    REPORT_V2 = 0x38,
    /// Report submit (WO) - write 1 to latch the report
    REPORT_SUBMIT = 0x3C,
    /// Latest latched report type (RO)
    LATCHED_TYPE = 0x40,
    /// Latest latched value 0 (RO)
    LATCHED_V0 = 0x44,
    /// Latest latched value 1 (RO)
    LATCHED_V1 = 0x48,
    /// Latest latched value 2 (RO)
    LATCHED_V2 = 0x4C,
}
