/* SPDX-License-Identifier: GPL-2.0-or-later */

#include "qemu/osdep.h"
#include "system/address-spaces.h"
#include "system/memory.h"

uint32_t qemu_agent_read_phys_u32(uint64_t addr, uint32_t *val);
uint32_t qemu_agent_write_phys_u32(uint64_t addr, uint32_t val);

uint32_t qemu_agent_read_phys_u32(uint64_t addr, uint32_t *val)
{
    uint8_t buf[4];
    MemTxResult ret = address_space_rw(&address_space_memory, addr,
                                         MEMTXATTRS_UNSPECIFIED, buf, 4, false);
    if (ret == MEMTX_OK) {
        memcpy(val, buf, 4);
    }
    return ret;
}

uint32_t qemu_agent_write_phys_u32(uint64_t addr, uint32_t val)
{
    uint8_t buf[4];
    memcpy(buf, &val, 4);
    return address_space_rw(&address_space_memory, addr,
                            MEMTXATTRS_UNSPECIFIED, buf, 4, true);
}
