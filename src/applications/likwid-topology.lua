#!<PREFIX>/bin/likwid-lua

--[[
 * =======================================================================================
 *
 *      Filename:  likwid-topology.lua
 *
 *      Description:  A application to determine the thread and cache topology
 *                    on x86 processors.
 *
 *      Version:   <VERSION>
 *      Released:  <DATE>
 *
 *      Author:   Thomas Roehl (tr), thomas.roehl@gmail.com
 *      Project:  likwid
 *
 *      Copyright (C) 2014 Thomas Roehl
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
 * =======================================================================================]]
package.path = package.path .. ';<PREFIX>/share/lua/?.lua'

local likwid = require("likwid")
stdout_print = print

function version()
    print(string.format("likwid-topology --  Version %d.%d",likwid.version,likwid.release))
end

function usage()
    version()
    print("A tool to print the thread and cache topology on x86 CPUs.\n")
    print("Options:")
    print("-h, --help\t\t Help message")
    print("-v, --version\t\t Version information")
    print("-V, --verbose <level>\t Set verbosity")
    print("-c, --caches\t\t List cache information")
    print("-C, --clock\t\t Measure processor clock")
    print("-O\t\t\t CSV output")
    print("-o, --output <file>\t Store output to file. (Optional: Apply text filter)")
    print("-g\t\t\t Graphical output")
end

print_caches = false
print_graphical = false
measure_clock = false
outfile = nil
output_csv = {}

for opt,arg in likwid.getopt(arg, {"h","v","c","C","g","o:","V:","O","help","version","verbose:","clock","caches","output:"}) do
    if (type(arg) == "string") then
        local s,e = arg:find("-");
        if s == 1 then
            print(string.format("Argmument %s to option -%s starts with invalid character -.", arg, opt))
            print("Did you forget an argument to an option?")
            os.exit(1)
        end
    end
    if opt == "h" or opt == "help" then
        usage()
        os.exit(0)
    elseif opt == "v" or opt == "version" then
        version()
        os.exit(0)
    elseif opt == "V" or opt == "verbose" then
        likwid.setVerbosity(tonumber(arg))
    elseif opt == "c" or opt == "caches" then
        print_caches = true
    elseif opt == "C" or opt == "clock" then
        measure_clock = true
    elseif opt == "g" then
        print_graphical = true
    elseif opt == "O" then
        print_csv = true
    elseif opt == "o" or opt == "output" then
        local suffix = string.match(arg, ".-[^\\/]-%.?([^%.\\/]*)$")
        if suffix ~= "txt" then
            print_csv = true
        end
        outfile = arg:gsub("%%h", likwid.gethostname())
        io.output(arg:gsub(string.match(arg, ".-[^\\/]-%.?([^%.\\/]*)$"),"tmp"))
        print = function(...) for k,v in pairs({...}) do io.write(v .. "\n") end end
    end
end

local config = likwid.getConfiguration()
local cpuinfo = likwid.getCpuInfo()
local cputopo = likwid.getCpuTopology()
local numainfo = likwid.getNumaInfo()
local affinity = likwid.getAffinityInfo()


table.insert(output_csv, likwid.hline)
local lines = 3
if measure_clock then
    lines = 4
end
table.insert(output_csv, "STRUCT,Info,"..tostring(lines))
table.insert(output_csv, string.format("CPU name:\t%s",cpuinfo["osname"]))
table.insert(output_csv, string.format("CPU type:\t%s",cpuinfo["name"]))
table.insert(output_csv, string.format("CPU stepping:\t%s",cpuinfo["stepping"]))
if (measure_clock) then
    if cpuinfo["clock"] == 0 then
        table.insert(output_csv, string.format("CPU clock:\t%3.2f GHz", likwid.getCpuClock() * 1.E-09))
    else
        table.insert(output_csv, string.format("CPU clock:\t%3.2f GHz", cpuinfo["clock"] * 1.E-09))
    end
end

table.insert(output_csv, likwid.sline)
table.insert(output_csv, "STRUCT,Hardware Thread Topology,3")
table.insert(output_csv, "Hardware Thread Topology")
table.insert(output_csv, likwid.sline)
table.insert(output_csv, string.format("Sockets:\t\t%u",cputopo["numSockets"]))
table.insert(output_csv, string.format("Cores per socket:\t%u",cputopo["numCoresPerSocket"]))
table.insert(output_csv, string.format("Threads per core:\t%u",cputopo["numThreadsPerCore"]))
table.insert(output_csv, likwid.hline)
table.insert(output_csv, "TABLE,Topology,"..tostring(cputopo["numHWThreads"]))
table.insert(output_csv, "HWThread\tThread\t\tCore\t\tSocket\t\tAvailable")

for cntr=0,cputopo["numHWThreads"]-1 do
    if cputopo["threadPool"][cntr]["inCpuSet"] then
        table.insert(output_csv, string.format("%d\t\t%u\t\t%u\t\t%u\t\t*",cntr,
                            cputopo["threadPool"][cntr]["threadId"],
                            cputopo["threadPool"][cntr]["coreId"],
                            cputopo["threadPool"][cntr]["packageId"]))
    else
        table.insert(output_csv, string.format("%d\t\t%u\t\t%u\t\t%u",cntr,
                            cputopo["threadPool"][cntr]["threadId"],
                            cputopo["threadPool"][cntr]["coreId"],
                            cputopo["threadPool"][cntr]["packageId"]))
    end
end
table.insert(output_csv, likwid.hline)

table.insert(output_csv, "STRUCT,Sockets,"..tostring(cputopo["numSockets"]))
for socket=0,cputopo["numSockets"]-1 do
    csv_str = string.format("Socket %d:\t\t( ",cputopo["topologyTree"][socket]["ID"])
    for core=0,cputopo["numCoresPerSocket"]-1 do
        for thread=0, cputopo["numThreadsPerCore"]-1 do
            csv_str = csv_str ..tostring(cputopo["topologyTree"][socket]["Childs"][core]["Childs"][thread]).. ","
        end
    end
    table.insert(output_csv, csv_str:sub(1,#csv_str-1).." )")
end

table.insert(output_csv, likwid.hline)


table.insert(output_csv, likwid.sline)
table.insert(output_csv, "Cache Topology")
table.insert(output_csv, likwid.sline)

for level=1,cputopo["numCacheLevels"] do
    if (cputopo["cacheLevels"][level]["type"] ~= "INSTRUCTIONCACHE") then
        lines = 3
        if print_caches then lines = 9 end
        table.insert(output_csv, string.format("STRUCT,Cache Topology L%d,%d", cputopo["cacheLevels"][level]["level"],lines))
        table.insert(output_csv, string.format("Level:\t\t\t%d",cputopo["cacheLevels"][level]["level"]))
        if (cputopo["cacheLevels"][level]["size"] < 1048576) then
            table.insert(output_csv, string.format("Size:\t\t\t%d kB",cputopo["cacheLevels"][level]["size"]/1024))
        else
            table.insert(output_csv, string.format("Size:\t\t\t%d MB",cputopo["cacheLevels"][level]["size"]/1048576))
        end
        
        if (print_caches) then
            if (cputopo["cacheLevels"][level]["type"] == "DATACACHE") then
                table.insert(output_csv, "Type:\t\t\tData cache")
            elseif (cputopo["cacheLevels"][level]["type"] == "UNIFIEDCACHE") then
                table.insert(output_csv, "Type:\t\t\tUnified cache")
            end

            table.insert(output_csv, string.format("Associativity:\t\t%d",cputopo["cacheLevels"][level]["associativity"]))
            table.insert(output_csv, string.format("Number of sets:\t\t%d",cputopo["cacheLevels"][level]["sets"]))
            table.insert(output_csv, string.format("Cache line size:\t%d",cputopo["cacheLevels"][level]["lineSize"]))
            
            if (cputopo["cacheLevels"][level]["inclusive"] > 0) then
                table.insert(output_csv, "Cache type:\t\tNon Inclusive")
            else
                table.insert(output_csv, "Cache type:\t\tInclusive")
            end
            table.insert(output_csv, string.format("Shared by threads:\t%d",cputopo["cacheLevels"][level]["threads"]))
        end
        local threads = cputopo["cacheLevels"][level]["threads"]
        str = "Cache groups:\t\t( "
        for socket=0,cputopo["numSockets"]-1 do
            for core=0,cputopo["numCoresPerSocket"]-1 do
                for cpu=0,cputopo["numThreadsPerCore"]-1 do
                    if (threads ~= 0) then
                        str = str .. cputopo["topologyTree"][socket]["Childs"][core]["Childs"][cpu] .. " "
                        threads = threads - 1
                    else
                        str = str .. string.format(") ( %d ",cputopo["topologyTree"][socket]["Childs"][core]["Childs"][cpu])
                        threads = cputopo["cacheLevels"][level]["threads"]
                        threads = threads - 1
                    end
                end
            end
        end
        str = str .. ")"
        table.insert(output_csv, str)
        table.insert(output_csv, likwid.hline)
    end
end


table.insert(output_csv, likwid.sline)
table.insert(output_csv, "NUMA Topology")
table.insert(output_csv, likwid.sline)

if (numainfo["numberOfNodes"] == 0) then
    table.insert(output_csv, "No NUMA")
else
    table.insert(output_csv, string.format("NUMA domains:\t\t%d",numainfo["numberOfNodes"]))
    table.insert(output_csv, likwid.hline)
    for node=1,numainfo["numberOfNodes"] do
        table.insert(output_csv, string.format("STRUCT,NUMA Topology %d,5",numainfo["nodes"][node]["id"]))
        table.insert(output_csv, string.format("Domain:\t\t\t%d",numainfo["nodes"][node]["id"]))
        csv_str = "Processors:\t\t( "
        for cpu=1,numainfo["nodes"][node]["numberOfProcessors"] do
            csv_str = csv_str .. numainfo["nodes"][node]["processors"][cpu] .. ","
        end
        table.insert(output_csv, csv_str:sub(1,#csv_str-1).. " )")
        csv_str = "Distances:\t\t"
        for cpu=1,numainfo["nodes"][node]["numberOfDistances"] do
            csv_str = csv_str .. numainfo["nodes"][node]["distances"][cpu][cpu-1] .. ","
        end
        table.insert(output_csv, csv_str:sub(1,#csv_str-1))
        table.insert(output_csv, string.format("Free memory:\t\t%g MB",tonumber(numainfo["nodes"][node]["freeMemory"]/1024.0)))
        table.insert(output_csv, string.format("Total memory:\t\t%g MB",tonumber(numainfo["nodes"][node]["totalMemory"]/1024.0)))
        table.insert(output_csv, likwid.hline)
    end
end



if print_csv then
    longest_line = 0
    local tmpList = {}
    for i=#output_csv,1,-1 do
        output_csv[i] = output_csv[i]:gsub("[\t]+",",")
        output_csv[i] = output_csv[i]:gsub("%( ","")
        output_csv[i] = output_csv[i]:gsub(" %)[%s]*",",")
        output_csv[i] = output_csv[i]:gsub(",$","")
        if  output_csv[i]:sub(1,1) == "*" or
            output_csv[i]:sub(1,1) == "-" or
            output_csv[i]:match("^Hardware Thread Topology") or
            output_csv[i]:match("^Cache Topology") or
            output_csv[i]:match("^NUMA Topology") then
            table.remove(output_csv,i)
        end
        tmpList = likwid.stringsplit(output_csv[i],",")
        if #tmpList > longest_line then longest_line = #tmpList end
    end
    for i=1,#output_csv do
        tmpList = likwid.stringsplit(output_csv[i],",")
        if #tmpList < longest_line then
            output_csv[i] = output_csv[i]..string.rep(",",longest_line-#tmpList)
        end
    end
else
    for i=#output_csv,1,-1 do
        output_csv[i] = output_csv[i]:gsub(","," ")
        if output_csv[i]:match("^TABLE") or
           output_csv[i]:match("^STRUCT") then
            table.remove(output_csv,i)
        end
    end
end

for _,line in pairs(output_csv) do print(line) end

if print_graphical and not print_csv then
    print("\n")
    print(likwid.sline)
    print("Graphical Topology")
    print(likwid.sline)
    for socket=0,cputopo["numSockets"]-1 do
        print(string.format("Socket %d:",cputopo["topologyTree"][socket]["ID"]))
        container = {}
        for core=0,cputopo["numCoresPerSocket"]-1 do
            local tmpString = ""
            for thread=0,cputopo["numThreadsPerCore"]-1 do
                if thread == 0 then
                    tmpString = tmpString .. tostring(cputopo["topologyTree"][socket]["Childs"][core]["Childs"][thread])
                else
                    tmpString = tmpString .. " " .. tostring(cputopo["topologyTree"][socket]["Childs"][core]["Childs"][thread]).. " "
                end
            end
            likwid.addSimpleAsciiBox(container, 1, core+1, tmpString)
        end
        
        local columnCursor = 1
        local lineCursor = 2
        for cache=1,cputopo["numCacheLevels"] do
            if cputopo["cacheLevels"][cache]["type"] ~= "INSTRUCTIONCACHE" then
                local cachesAtCurLevel = 0
                local sharedCores = cputopo["cacheLevels"][cache]["threads"]/cputopo["numThreadsPerCore"]
                if sharedCores >= cputopo["numCoresPerSocket"] then
                    cachesAtCurLevel = 1
                else
                    cachesAtCurLevel = cputopo["numCoresPerSocket"]/sharedCores
                end
                columnCursor = 1
                for cachesAtLevel=1,cachesAtCurLevel do
                    local tmpString = ""
                    local cacheWidth = 0
                    if cputopo["cacheLevels"][cache]["size"] < 1048576 then
                        tmpString = string.format("%dkB", cputopo["cacheLevels"][cache]["size"]/1024)
                    else
                        tmpString = string.format("%dMB", cputopo["cacheLevels"][cache]["size"]/1048576)
                    end
                    if sharedCores > 1 then
                        if sharedCores > cputopo["numCoresPerSocket"] then
                            cacheWidth = sharedCores
                        else
                            cacheWidth = sharedCores - 1
                        end
                        likwid.addJoinedAsciiBox(container, lineCursor, columnCursor,columnCursor + cacheWidth, tmpString)
                        columnCursor = columnCursor + cacheWidth
                    else
                        likwid.addSimpleAsciiBox(container, lineCursor, columnCursor, tmpString)
                        columnCursor = columnCursor + 1
                    end
                end
                lineCursor = lineCursor + 1
            end
        end
        likwid.printAsciiBox(container);
    end
end

if outfile then
    local suffix = string.match(outfile, ".-[^\\/]-%.?([^%.\\/]*)$")
    local command = "<PREFIX>/share/likwid/filter/" .. suffix 
    if suffix ~= "txt" and suffix ~= "csv" then
        command = command .." ".. outfile:gsub("."..suffix,".tmp",1) .. " topology"
        local f = io.popen(command)
        local o = f:read("*a")
        if o:len() > 0 then
            print(string.format("Failed to executed filter script %s.",command))
        end
    else
        os.rename(outfile:gsub("."..suffix,".tmp",1), outfile)
    end
end

likwid.putAffinityInfo()
likwid.putNumaInfo()
likwid.putTopology()
likwid.putConfiguration()
os.exit(0)
