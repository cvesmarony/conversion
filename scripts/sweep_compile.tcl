#####################################################################################
# Parameter-sweep variant of compile.tcl.
# Identical technology / library / mmmc setup; only the top module, clock period,
# file list and output directories come from environment variables set by the Makefile.
#####################################################################################
proc getenv {name {default ""}} {
    if {[info exists ::env($name)]} { return $::env($name) }
    return $default
}

sh hostname
date

set start_time [clock seconds]
set rm_task synthesis

# -----------------------------------------------------------------------------------
# Setup the Configuration (same files as compile.tcl) + sweep overrides
# -----------------------------------------------------------------------------------
source -echo -verbose ../scripts/core_config.tcl

set rm_core_top     [getenv SYN_TOP   convert_top]
set rm_reset_ports  [list [getenv SYN_RST rst_n]]
set SYN_VC          [getenv SYN_VC]
set DATA            [getenv SYN_DATA    ../data/sweep]
set REPORTS         [getenv SYN_REPORTS ../reports/sweep]
set SYN_OPT         [getenv SYN_OPT 1]
file mkdir $DATA $REPORTS

# -----------------------------------------------------------------------------------
# Setup the Target Technology
# -----------------------------------------------------------------------------------
source -echo -verbose ../scripts/tech.tcl

# tech.tcl sets rm_clock_period (20 ns); override AFTER it, BEFORE the SDC is read.
# (works if scripts/constraints.tcl uses $rm_clock_period)
set rm_clock_period [getenv SYN_CLK_NS 1.0]

set_db information_level 9

set_db tns_opto true
set_db lp_insert_clock_gating false

set_db timing_report_load_unit pf
set_db timing_report_time_unit ps

# -----------------------------------------------------------------------------------
# Setup Library
# -----------------------------------------------------------------------------------
set link_library [concat ${ss_0p72v_m40c_libs} ${ff_0p88v_125c_libs} ]
set_db library ${link_library}

foreach dont_use ${rm_dont_use_list} {
  set_dont_use [get_lib_cells */${dont_use} ]
}

# -----------------------------------------------------------------------------------
# Read + elaborate (same as init_genus.tcl, but with the generated file list)
# -----------------------------------------------------------------------------------
read_mmmc ../scripts/viewDefinitions.tcl
read_physical -lef $rm_lef_reflib

read_hdl -f $SYN_VC -language sv
elaborate ${rm_core_top}

init_design

# keep hierarchy so area.rpt separates the table banks (u_bank*) from the logic
set_db auto_ungroup none

# -----------------------------------------------------------------------------------
# Synthesize
# -----------------------------------------------------------------------------------
syn_generic
write_hdl > ${DATA}/${rm_core_top}-map.v
syn_map
if {$SYN_OPT} { syn_opt }

check_design -unresolved > ${REPORTS}/check_design.rpt
report_timing            > ${REPORTS}/timing.rpt
report_area              > ${REPORTS}/area.rpt
report_power             > ${REPORTS}/power.rpt
report_qor               > ${REPORTS}/qor.rpt
write_hdl                > ${DATA}/${rm_core_top}-compile.v

puts "SYNTHESIS DONE: elapsed [expr {[clock seconds]-$start_time}] s"
exit
