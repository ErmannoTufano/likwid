/*
 * =======================================================================================
 *
 *      Filename:  C-likwidAPI.c
 *
 *      Description:  Example how to use the LIKWID API in C/C++ applications
 *
 *      Version:   <VERSION>
 *      Released:  <DATE>
 *
 *      Author:  Thomas Roehl (tr), thomas.roehl@googlemail.com
 *      Project:  likwid
 *
 *      Copyright (C) 2015 Thomas Roehl
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

#include <stdlib.h>
#include <stdio.h>

#include <likwid.h>

#define EVENTSET "INSTR_RETIRED_ANY:FIXC0"


int main(int argc, char* argv[])
{
    int i;
    int* cpus;
    int gid;
    double result = 0.0;

    // Load the topology module and print some values.
    topology_init();
    // CpuInfo_t contains global information like name, CPU family, ...
    CpuInfo_t info = get_cpuInfo();
    // CpuTopology_t contains information about the topology of the CPUs.
    CpuTopology_t topo = get_cpuTopology();
    printf("Likwid example on a %s with %d CPUs\n", info->name, topo->numHWThreads);

    cpus = malloc(topo->numHWThreads * sizeof(int));
    if (!cpus)
        return 1;

    for (i=0;i<topo->numHWThreads;i++)
    {
        cpus[i] = topo->threadPool[i].apicId;
    }

    // Must be called before perfmon_init() but only if you want to use another
    // access mode as the pre-configured one. For direct access (0) you have to
    // be root.
    //accessClient_setaccessmode(0);

    // Initialize the perfmon module.
    perfmon_init(topo->numHWThreads, cpus);

    // Add eventset string to the perfmon module.
    gid = perfmon_addEventSet(EVENTSET);

    // Setup the eventset identified by group ID (gid).
    perfmon_setupCounters(gid);
    // Start all counters in the previously set up event set.
    perfmon_startCounters();
    // Perform something
    sleep(2);
    // Stop all counters in the previously started event set.
    perfmon_stopCounters();


    // Print the result of every thread/CPU.
    for (i = 0;i < topo->numHWThreads; i++)
    {
        result = perfmon_getResult(gid, 0, i);
        printf("Measurement result for event set %s at CPU %d: %f\n", EVENTSET, cpus[i], result);
    }

    // Uninitialize the perfmon module.
    perfmon_finalize();
    // Uninitialize the topology module.
    topology_finalize();
    return 0;
}
