/*
 * =======================================================================================
 *
 *      Filename:  pci.h
 *
 *      Description:  Header File pci Module.
 *
 *      Version:   <VERSION>
 *      Released:  <DATE>
 *
 *      Author:   Jan Treibig (jt), jan.treibig@gmail.com
 *      Project:  likwid
 *
 *      Copyright (C) 2013 Jan Treibig
 *
 *      This program is free software: you can redistribute it and/or modify it under
 *      the terms of the GNU General Public License as published by the Free Software
 *      Foundation, either version 3 of the License, or (at your option) any later
 *      version.
 *
 *      This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *      WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 *      PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 *      You should have received a copy of the GNU General Public License along with
 *      this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * =======================================================================================
 */

#ifndef PCI_H
#define PCI_H

#include <types.h>


/* PCI config memory space access is addressed
 * BUS - DEVICE - FUNCTION
 * Listing for Uncore devices DEVICE.FUNCTION
 */

extern int pci_init(int socket_fd);
extern void pci_finalize();
extern int pci_checkDevice(PciDeviceIndex index, int cpu);
extern int pci_read(int cpu, PciDeviceIndex index, uint32_t reg, uint32_t *data);
extern int pci_write(int cpu, PciDeviceIndex index, uint32_t reg, uint32_t data);
extern int pci_tread(int socket_fd, int cpu, PciDeviceIndex index, uint32_t reg, uint32_t *data);
extern int pci_twrite(int socket_fd, int cpu, PciDeviceIndex index, uint32_t reg, uint32_t data);

#endif /* PCI_H */
