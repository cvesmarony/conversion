# ---------------------------------------------------------------------------
# Genus synthesis script for convert_top (wrapper around ConvertCore)
# All inputs come from environment variables set by the Makefile.
# ---------------------------------------------------------------------------
proc getenv {name {default ""}} {
    if {[info exists ::env($name)]} { return $::env($name) }
    return $default
}

set TOP    [getenv SYN_TOP convert_top]
set RUN    [getenv SYN_RUN build/run]
set RTL    [getenv SYN_RTL]
set LIBDIR [getenv SYN_LIBDIR]
set LIBS   [getenv SYN_LIBS]
set LEFS   [getenv SYN_LEFS]
set EFFORT [getenv SYN_EFFORT medium]

file mkdir $RUN/reports $RUN/out

# ---- libraries -------------------------------------------------------------
set_db init_lib_search_path $LIBDIR
set_db library              $LIBS
if {[string trim $LEFS] ne ""} { set_db lef_library $LEFS }

# ---- read + elaborate ------------------------------------------------------
# Order matters: package first (the Makefile already lists it first).
foreach f $RTL { read_hdl -sv $f }
elaborate $TOP
check_design -unresolved > $RUN/reports/check_design_pre.rpt

# ---- constraints -----------------------------------------------------------
read_sdc $RUN/constraints.sdc

# Keep hierarchy so the area report separates the two table banks from the
# converter logic (u_bank0 / u_bank1 vs. everything else).
set_db auto_ungroup none

set_db syn_generic_effort $EFFORT
set_db syn_map_effort     $EFFORT
set_db syn_opt_effort     $EFFORT

# ---- synthesize ------------------------------------------------------------
syn_generic
syn_map
syn_opt

# ---- reports ---------------------------------------------------------------
report_area                  > $RUN/reports/area.rpt
report_gates                 > $RUN/reports/gates.rpt
report_timing -max_paths 3   > $RUN/reports/timing.rpt
report_power                 > $RUN/reports/power.rpt
report_qor                   > $RUN/reports/qor.rpt
check_design                 > $RUN/reports/check_design_post.rpt

# ---- outputs (netlist + sdc, plus an Innovus hand-off) ---------------------
write_hdl > $RUN/out/${TOP}_netlist.v
write_sdc > $RUN/out/${TOP}.sdc
catch { write_design -innovus -base_name $RUN/out/${TOP} }

puts "SYNTHESIS DONE: $RUN"
exit
