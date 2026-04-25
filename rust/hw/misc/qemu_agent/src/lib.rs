// SPDX-License-Identifier: GPL-2.0-or-later

//! QEMU Agent Device Model
//!
//! A simple SysBus MMIO device for guest-host communication via chardev.
//!
//! Guest software (via a kernel driver) writes bytes to the DATA register
//! which are forwarded to the host-side chardev backend.  Data sent from
//! the host chardev is buffered in a small RX FIFO and read back by the
//! guest through the same DATA register.

mod device;
mod registers;

pub const TYPE_QEMU_AGENT: &::std::ffi::CStr = c"qemu-agent";
