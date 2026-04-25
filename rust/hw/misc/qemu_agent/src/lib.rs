// SPDX-License-Identifier: GPL-2.0-or-later

//! QEMU Agent Device Model
//!
//! A SysBus MMIO device for guest introspection and telemetry reporting.

mod device;
mod registers;

pub const TYPE_QEMU_AGENT: &::std::ffi::CStr = c"qemu-agent";
