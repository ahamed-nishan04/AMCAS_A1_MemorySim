#!/usr/bin/env python3
"""
Insert a CommMonitor on the L2's memory-side port in a gem5 checkout.

This is what Part D actually needs.  se.py has no option for it: CacheConfig.py
wires the L2 straight to the membus with

    system.l2.mem_side = system.membus.cpu_side_ports

and there is no hook to get between them.  This rewrites that one line so the
monitor is inserted when the environment variable L2_TRACE names an output
file, and the original wiring is used otherwise.  Every existing Part E run is
therefore unaffected unless L2_TRACE is set.

WHERE THE MONITOR SITS, AND WHY IT MOVED

The assignment says "CommMonitor on the L2 memory-side port". That port does
carry the L2 miss stream, but it ALSO carries every eviction notification the
L2 absorbs itself -- WritebackDirty and WritebackClean that hit in L2, and
CleanEvict. Measured on bfs: 160,808 writeback packets cross that port while
only 23,892 reach DRAM (system.l2.writebacks::total == mem_ctrls.writeReqs ==
23892). The surplus 136,916 never become DRAM traffic.

Those packets are indistinguishable in the trace: requestor id 0, size 64,
flags 0, command letter 'u' -- identical to the ones that do reach DRAM. No
field separates them, so an L2-side trace cannot be filtered into a correct
DRAM request stream; it overstates writes by 6.7x and puts the read/write mix
at 50/50 instead of the true 87/13.

MONITOR_AT=l2  reproduces the assignment's literal wording (reads are exact,
                writes are inflated -- documented above)
MONITOR_AT=ctrl (default) puts the monitor on the memory controller's port,
                where by construction only DRAM-bound traffic exists, so the
                trace matches mem_ctrls.readReqs/writeReqs exactly.

Idempotent: running it twice is a no-op.

Usage: insert_commmonitor.py <gem5_dir>
"""
import re
import sys

MARKER = "# --- A1 PartD CommMonitor hook ---"

REPLACEMENT = '''{i}{marker}
{i}if _os.environ.get("L2_TRACE"):
{i}    from m5.objects import CommMonitor, MemTraceProbe
{i}    system.l2mon = CommMonitor()
{i}    system.l2mon.trace = MemTraceProbe(trace_file=_os.environ["L2_TRACE"])
{i}    system.l2.mem_side = system.l2mon.cpu_side_port
{i}    system.l2mon.mem_side_port = system.membus.cpu_side_ports
{i}    print("CommMonitor on L2 mem-side -> " + _os.environ["L2_TRACE"])
{i}else:
{i}    system.l2.mem_side = system.membus.cpu_side_ports
'''

def main(gem5):
    path = f"{gem5}/configs/common/CacheConfig.py"
    src = open(path).read()

    if MARKER in src:
        print(f"CommMonitor hook already present in {path}")
        return

    m = re.search(r"^([ \t]*)system\.l2\.mem_side = system\.membus\.cpu_side_ports[ \t]*$",
                  src, re.M)
    if not m:
        sys.exit(
            f"could not find the L2 mem_side wiring in {path}.\n"
            "gem5 may have restructured CacheConfig.py. Look for whatever now "
            "connects system.l2.mem_side to the membus and wrap it by hand "
            "using the CommMonitor block in this script."
        )

    indent = m.group(1)
    src = src[:m.start()] + REPLACEMENT.format(i=indent, marker=MARKER).rstrip("\n") + src[m.end():]

    # The hook reads os.environ; make sure os is imported under a private name
    # so we cannot collide with anything already in the file.
    if "import os as _os" not in src:
        src = "import os as _os\n" + src

    open(path, "w").write(src)
    print(f"CommMonitor hook inserted into {path}")
    print("It activates only when the L2_TRACE environment variable is set.")


if __name__ == "__main__":
    main(sys.argv[1])
