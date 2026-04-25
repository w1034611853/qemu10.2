// SPDX-License-Identifier: GPL-2.0-or-later

//! QEMU Agent device model implementation.
//!
//! This device provides:
//! 1. An internal MMIO **command interface** for guest software to introspect
//!    and control the emulator (read phys mem, etc.).
//! 2. A **report interface** where the guest can push structured telemetry
//!    (CPU usage, memory usage, I/O stats, etc.) into QEMU.  The emulator
//!    latches the latest values and invokes handle_report() synchronously
//!    under the BQL, allowing the device to change emulation behavior in
//!    real time.

use std::ffi::CStr;

use bql::{BqlCell, BqlRefCell};
use common::uninit_field_mut;
use hwcore::{Device, DeviceImpl, ResettablePhasesImpl, ResetType};
use system::{SysBusDeviceClassExt, SysBusDeviceImpl, SysBusDeviceMethods};
use migration::{impl_vmstate_struct, vmstate_fields, vmstate_of, VMStateDescription, VMStateDescriptionBuilder};
use qom::{Object, ObjectImpl, ObjectType, ParentField, ParentInit, qom_isa};
use system::{hwaddr, MemoryRegion, MemoryRegionOps, MemoryRegionOpsBuilder, SysBusDevice, MEMTXATTRS_UNSPECIFIED};
use util::log_mask_ln;
use util::log::Log;

use crate::registers::RegisterOffset;

const MAGIC_VALUE: u32 = 0x51454D55;
const VERSION_VALUE: u32 = 0x00010000;

// STATUS bits
const STATUS_READY: u32 = 1 << 0;
const STATUS_BUSY: u32 = 1 << 1;
const STATUS_REPORT_READY: u32 = 1 << 2;
const STATUS_REPORT_OVERRUN: u32 = 1 << 3;

// CONTROL bits
const CTRL_IRQ_EN: u32 = 1 << 0;
const CTRL_SW_RESET: u32 = 1 << 1;
const CTRL_REPORT_INT_EN: u32 = 1 << 2;

// IRQ_STATUS bits
const IRQ_CMD_DONE: u32 = 1 << 0;
const IRQ_REPORT: u32 = 1 << 1;

/// Well-known command codes (guest -> host).
pub mod commands {
    pub const NOP: u32 = 0;
    /// Read 32-bit from guest physical address (ARG0=phys_addr).
    pub const READ_PHYS_U32: u32 = 1;
    /// Write 32-bit to guest physical address (ARG0=phys_addr, ARG1=value).
    pub const WRITE_PHYS_U32: u32 = 2;
}

/// Well-known report types (guest -> host telemetry).
pub mod report_types {
    pub const CPU_USAGE: u32 = 1;      // v0 = percent (0-100)
    pub const MEM_USAGE: u32 = 2;      // v0 = used MB, v1 = total MB
    pub const IO_THROUGHPUT: u32 = 3;  // v0 = read KB/s, v1 = write KB/s
    pub const NETWORK_STATS: u32 = 4;  // v0 = rx KB/s, v1 = tx KB/s
    pub const CUSTOM: u32 = 0xFF;      // user-defined
}

/// Device registers that need to be migrated.
#[repr(C)]
#[derive(Debug, Default)]
pub struct AgentRegisters {
    pub control: u32,
    pub status: u32,
    pub irq_status: u32,
    pub arg0: u32,
    pub arg1: u32,
    pub arg2: u32,
    pub result0: u32,
    pub result1: u32,
    pub latched_type: u32,
    pub latched_v0: u32,
    pub latched_v1: u32,
    pub latched_v2: u32,
}

impl_vmstate_struct!(
    AgentRegisters,
    VMStateDescriptionBuilder::<AgentRegisters>::new()
        .name(c"qemu_agent/regs")
        .version_id(1)
        .minimum_version_id(1)
        .fields(vmstate_fields! {
            vmstate_of!(AgentRegisters, control),
            vmstate_of!(AgentRegisters, status),
            vmstate_of!(AgentRegisters, irq_status),
            vmstate_of!(AgentRegisters, arg0),
            vmstate_of!(AgentRegisters, arg1),
            vmstate_of!(AgentRegisters, arg2),
            vmstate_of!(AgentRegisters, result0),
            vmstate_of!(AgentRegisters, result1),
            vmstate_of!(AgentRegisters, latched_type),
            vmstate_of!(AgentRegisters, latched_v0),
            vmstate_of!(AgentRegisters, latched_v1),
            vmstate_of!(AgentRegisters, latched_v2),
        })
        .build()
);

/// QEMU Agent state structure.
#[repr(C)]
#[derive(Object, Device)]
pub struct QemuAgentState {
    pub parent_obj: ParentField<SysBusDevice>,
    pub iomem: MemoryRegion,
    pub irq: hwcore::InterruptSource,
    pub regs: BqlRefCell<AgentRegisters>,
    /// Shadow staging area for the report being composed by the guest.
    pub report_type: BqlCell<u32>,
    pub report_v0: BqlCell<u32>,
    pub report_v1: BqlCell<u32>,
    pub report_v2: BqlCell<u32>,
}

qom_isa!(QemuAgentState: SysBusDevice, hwcore::DeviceState, qom::Object);

unsafe impl ObjectType for QemuAgentState {
    type Class = <SysBusDevice as ObjectType>::Class;
    const TYPE_NAME: &'static CStr = crate::TYPE_QEMU_AGENT;
}

impl ObjectImpl for QemuAgentState {
    type ParentType = SysBusDevice;

    const INSTANCE_INIT: Option<unsafe fn(ParentInit<Self>)> = Some(Self::init);
    const INSTANCE_POST_INIT: Option<fn(&Self)> = Some(Self::post_init);
    const CLASS_INIT: fn(&mut Self::Class) = Self::Class::class_init::<Self>;
}

impl DeviceImpl for QemuAgentState {
    const VMSTATE: Option<VMStateDescription<Self>> = Some(VMSTATE_QEMU_AGENT);
}

impl ResettablePhasesImpl for QemuAgentState {
    const HOLD: Option<fn(&Self, ResetType)> = Some(Self::reset_hold);
}

impl SysBusDeviceImpl for QemuAgentState {}

impl QemuAgentState {
    unsafe fn init(mut this: ParentInit<Self>) {
        static AGENT_OPS: MemoryRegionOps<QemuAgentState> =
            MemoryRegionOpsBuilder::<QemuAgentState>::new()
                .read(&QemuAgentState::read)
                .write(&QemuAgentState::write)
                .little_endian()
                .impl_sizes(4, 4)
                .build();

        MemoryRegion::init_io(
            &mut uninit_field_mut!(*this, iomem),
            &AGENT_OPS,
            "qemu-agent",
            0x100,
        );

        uninit_field_mut!(*this, regs).write(Default::default());
        uninit_field_mut!(*this, report_type).write(Default::default());
        uninit_field_mut!(*this, report_v0).write(Default::default());
        uninit_field_mut!(*this, report_v1).write(Default::default());
        uninit_field_mut!(*this, report_v2).write(Default::default());
    }

    fn post_init(&self) {
        self.init_mmio(&self.iomem);
        self.init_irq(&self.irq);
    }

    fn reset_hold(&self, _type: ResetType) {
        let mut regs = self.regs.borrow_mut();
        regs.control = 0;
        regs.status = STATUS_READY;
        regs.irq_status = 0;
        regs.arg0 = 0;
        regs.arg1 = 0;
        regs.arg2 = 0;
        regs.result0 = 0;
        regs.result1 = 0;
        regs.latched_type = 0;
        regs.latched_v0 = 0;
        regs.latched_v1 = 0;
        regs.latched_v2 = 0;
        drop(regs);
        self.report_type.set(0);
        self.report_v0.set(0);
        self.report_v1.set(0);
        self.report_v2.set(0);
        self.irq.lower();
    }

    fn read(&self, offset: hwaddr, _size: u32) -> u64 {
        let regs = self.regs.borrow();
        let val = match RegisterOffset::try_from(offset) {
            Ok(RegisterOffset::MAGIC) => MAGIC_VALUE,
            Ok(RegisterOffset::VERSION) => VERSION_VALUE,
            Ok(RegisterOffset::STATUS) => regs.status,
            Ok(RegisterOffset::CONTROL) => regs.control,
            Ok(RegisterOffset::ARG0) => regs.arg0,
            Ok(RegisterOffset::ARG1) => regs.arg1,
            Ok(RegisterOffset::ARG2) => regs.arg2,
            Ok(RegisterOffset::RESULT0) => regs.result0,
            Ok(RegisterOffset::RESULT1) => regs.result1,
            Ok(RegisterOffset::IRQ_STATUS) => regs.irq_status,
            Ok(RegisterOffset::LATCHED_TYPE) => regs.latched_type,
            Ok(RegisterOffset::LATCHED_V0) => regs.latched_v0,
            Ok(RegisterOffset::LATCHED_V1) => regs.latched_v1,
            Ok(RegisterOffset::LATCHED_V2) => regs.latched_v2,
            Ok(RegisterOffset::COMMAND)
            | Ok(RegisterOffset::REPORT_TYPE)
            | Ok(RegisterOffset::REPORT_V0)
            | Ok(RegisterOffset::REPORT_V1)
            | Ok(RegisterOffset::REPORT_V2)
            | Ok(RegisterOffset::REPORT_SUBMIT) => 0, // write-only
            Err(_) => {
                log_mask_ln!(
                    Log::GuestError,
                    "qemu-agent: read from bad offset 0x{offset:x}"
                );
                0
            }
        };
        val.into()
    }

    fn write(&self, offset: hwaddr, value: u64, _size: u32) {
        let val = value as u32;
        match RegisterOffset::try_from(offset) {
            Ok(RegisterOffset::CONTROL) => {
                let mut regs = self.regs.borrow_mut();
                if val & CTRL_SW_RESET != 0 {
                    regs.status = STATUS_READY;
                    regs.irq_status = 0;
                    regs.result0 = 0;
                    regs.result1 = 0;
                    regs.latched_type = 0;
                    regs.latched_v0 = 0;
                    regs.latched_v1 = 0;
                    regs.latched_v2 = 0;
                }
                regs.control = val & !CTRL_SW_RESET;
                drop(regs);
                self.update_irq_line();
            }
            Ok(RegisterOffset::COMMAND) => {
                self.execute_command(val);
            }
            Ok(RegisterOffset::ARG0) => {
                self.regs.borrow_mut().arg0 = val;
            }
            Ok(RegisterOffset::ARG1) => {
                self.regs.borrow_mut().arg1 = val;
            }
            Ok(RegisterOffset::ARG2) => {
                self.regs.borrow_mut().arg2 = val;
            }
            Ok(RegisterOffset::IRQ_STATUS) => {
                let mut regs = self.regs.borrow_mut();
                regs.irq_status &= !val; // RW1C
                drop(regs);
                self.update_irq_line();
            }
            Ok(RegisterOffset::REPORT_TYPE) => {
                self.report_type.set(val);
            }
            Ok(RegisterOffset::REPORT_V0) => {
                self.report_v0.set(val);
            }
            Ok(RegisterOffset::REPORT_V1) => {
                self.report_v1.set(val);
            }
            Ok(RegisterOffset::REPORT_V2) => {
                self.report_v2.set(val);
            }
            Ok(RegisterOffset::REPORT_SUBMIT) => {
                if val != 0 {
                    self.submit_report();
                }
            }
            Ok(RegisterOffset::MAGIC)
            | Ok(RegisterOffset::VERSION)
            | Ok(RegisterOffset::STATUS)
            | Ok(RegisterOffset::RESULT0)
            | Ok(RegisterOffset::RESULT1)
            | Ok(RegisterOffset::LATCHED_TYPE)
            | Ok(RegisterOffset::LATCHED_V0)
            | Ok(RegisterOffset::LATCHED_V1)
            | Ok(RegisterOffset::LATCHED_V2) => {
                // read-only
            }
            Err(_) => {
                log_mask_ln!(
                    Log::GuestError,
                    "qemu-agent: write to bad offset 0x{offset:x}"
                );
            }
        }
    }

    /// Execute a control command synchronously inside QEMU.
    fn execute_command(&self, cmd: u32) {
        let mut regs = self.regs.borrow_mut();
        let arg0 = regs.arg0;
        let arg1 = regs.arg1;
        let _arg2 = regs.arg2;

        regs.status |= STATUS_BUSY;
        regs.status &= !STATUS_READY;
        drop(regs);

        let (res0, res1) = match cmd {
            commands::NOP => (0, 0),
            commands::READ_PHYS_U32 => self.cmd_read_phys_u32(arg0),
            commands::WRITE_PHYS_U32 => self.cmd_write_phys_u32(arg0, arg1),
            _ => {
                log_mask_ln!(Log::GuestError, "qemu-agent: unknown command {cmd}");
                (0, 0)
            }
        };

        let mut regs = self.regs.borrow_mut();
        regs.result0 = res0;
        regs.result1 = res1;
        regs.status &= !STATUS_BUSY;
        regs.status |= STATUS_READY;
        regs.irq_status |= IRQ_CMD_DONE;
        drop(regs);
        self.update_irq_line();
    }

    /// Guest has finished composing a report; latch it and notify QEMU.
    fn submit_report(&self) {
        let mut regs = self.regs.borrow_mut();
        if (regs.status & STATUS_REPORT_READY) != 0 {
            // Previous report not yet consumed by emulator
            regs.status |= STATUS_REPORT_OVERRUN;
        }
        regs.latched_type = self.report_type.get();
        regs.latched_v0 = self.report_v0.get();
        regs.latched_v1 = self.report_v1.get();
        regs.latched_v2 = self.report_v2.get();
        regs.status |= STATUS_REPORT_READY;
        regs.irq_status |= IRQ_REPORT;
        drop(regs);

        // ---- 这里是 QEMU 内部做出调整的 hook ----
        self.handle_report();
        // ----------------------------------------

        self.update_irq_line();
    }

    /// Hook called whenever a new report is latched.
    /// You can read `self.regs.borrow().latched_*` and call any QEMU internal
    /// API to change emulation behavior.
    fn handle_report(&self) {
        let regs = self.regs.borrow();
        let typ = regs.latched_type;
        let v0 = regs.latched_v0;
        let v1 = regs.latched_v1;
        let v2 = regs.latched_v2;
        drop(regs);

        match typ {
            report_types::CPU_USAGE => {
                log_mask_ln!(
                    Log::Unimp,
                    "qemu-agent: CPU usage report {v0}%"
                );
            }
            report_types::MEM_USAGE => {
                log_mask_ln!(
                    Log::Unimp,
                    "qemu-agent: MEM usage {v0}MB / {v1}MB"
                );
            }
            report_types::IO_THROUGHPUT => {
                log_mask_ln!(
                    Log::Unimp,
                    "qemu-agent: IO read={v0}KB/s write={v1}KB/s"
                );
            }
            report_types::NETWORK_STATS => {
                log_mask_ln!(
                    Log::Unimp,
                    "qemu-agent: NET rx={v0}KB/s tx={v1}KB/s"
                );
            }
            report_types::CUSTOM => {
                log_mask_ln!(
                    Log::Unimp,
                    "qemu-agent: CUSTOM report v0={v0} v1={v1} v2={v2}"
                );
            }
            _ => {
                log_mask_ln!(Log::GuestError, "qemu-agent: unknown report type {typ}");
            }
        }
    }

    fn cmd_read_phys_u32(&self, addr: u32) -> (u32, u32) {
        let mut buf = [0u8; 4];
        let pa = addr as u64;
        let ret = unsafe {
            system::bindings::address_space_rw(
                std::ptr::addr_of_mut!(system::bindings::address_space_memory),
                pa,
                MEMTXATTRS_UNSPECIFIED,
                buf.as_mut_ptr().cast(),
                4,
                false,
            )
        };
        if ret == 0 {
            // MEMTX_OK is 0
            (u32::from_le_bytes(buf), 0)
        } else {
            (0, 0)
        }
    }

    fn cmd_write_phys_u32(&self, addr: u32, value: u32) -> (u32, u32) {
        let mut buf = value.to_le_bytes();
        let pa = addr as u64;
        let ret = unsafe {
            system::bindings::address_space_rw(
                std::ptr::addr_of_mut!(system::bindings::address_space_memory),
                pa,
                MEMTXATTRS_UNSPECIFIED,
                buf.as_mut_ptr().cast(),
                4,
                true,
            )
        };
        (if ret == 0 { 0 } else { 1 }, 0)
    }

    fn update_irq_line(&self) {
        let regs = self.regs.borrow();
        let mut active = false;
        if (regs.irq_status & IRQ_CMD_DONE) != 0 && (regs.control & CTRL_IRQ_EN) != 0 {
            active = true;
        }
        if (regs.irq_status & IRQ_REPORT) != 0 && (regs.control & CTRL_REPORT_INT_EN) != 0 {
            active = true;
        }
        drop(regs);
        self.irq.set(active);
    }
}

/// Migration description for [`QemuAgentState`].
pub const VMSTATE_QEMU_AGENT: VMStateDescription<QemuAgentState> =
    VMStateDescriptionBuilder::<QemuAgentState>::new()
        .name(c"qemu_agent")
        .version_id(1)
        .minimum_version_id(1)
        .fields(vmstate_fields! {
            vmstate_of!(QemuAgentState, regs),
            vmstate_of!(QemuAgentState, report_type),
            vmstate_of!(QemuAgentState, report_v0),
            vmstate_of!(QemuAgentState, report_v1),
            vmstate_of!(QemuAgentState, report_v2),
        })
        .build();
