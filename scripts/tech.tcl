#####################################################################################
# Technology Setup file
#####################################################################################
# -----------------------------------------------------------------------------------
# Set Host Options
# -----------------------------------------------------------------------------------
set rm_multi_core 1

# -----------------------------------------------------------------------------------
# Path to library directories
# -----------------------------------------------------------------------------------

set rm_foundry_lib_dirs /usr/cots/ip_libraries/tsmc/N16ADFP
set rm_foundry_kit_dirs /usr/cots/pdk/N16ADFP
set rm_sram_lib_dirs ${rm_foundry_lib_dirs}/sram/N16ADFP_SRAM/


# -----------------------------------------------------------------------------------
# P&R Technology File Locations
# -----------------------------------------------------------------------------------
set rm_lef_tech_file ${rm_foundry_kit_dirs}/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_11M.10a.tlef
set rm_gds_layer_map ${rm_foundry_kit_dirs}/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_Gdsout_11M.10a.map
set rm_lef_layer_map ${rm_foundry_kit_dirs}/APR/N16ADFP_APR_Innovus/N16ADFP_APR_Innovus_Qrc_11M.10a.map


# -----------------------------------------------------------------------------------
# Technology Library Setup
# -----------------------------------------------------------------------------------

##  Path to Standard Cell libraries
set rm_base_reflib ${rm_foundry_lib_dirs}/stdcell/N16ADFP_StdCell

set rm_lef_reflib   [list ${rm_lef_tech_file} \
                        ${rm_base_reflib}/LEF/lef/N16ADFP_StdCell.lef \
                        ${rm_sram_lib_dirs}/LEF/N16ADFP_SRAM_100a.lef \
]
  
# Used to generate search_path - contains the directory paths to libraries that do
# not have a directory component

set rm_db_search_path [concat ${rm_base_reflib}/CCS/ \
                                ${rm_sram_lib_dirs}/NLDM/ \
                              . \
]

# set rm_qrc_typ_file 
set rm_qrc_min_file ${rm_foundry_kit_dirs}/RC/N16ADFP_QRC/best/qrcTechFile
set rm_qrc_max_file ${rm_foundry_kit_dirs}/RC/N16ADFP_QRC/worst/qrcTechFile


## Logical names of libraries
set base_tt_0p8v_25c_lib               "N16ADFP_StdCelltt0p8v25c_ccs"
set base_ss_0p72v_m40c_lib             "N16ADFP_StdCellss0p72vm40c_ccs"
set base_ss_0p72v_125c_lib             "N16ADFP_StdCellss0p72v125c_ccs"
set base_ff_0p88v_m40c_lib             "N16ADFP_StdCellff0p88vm40c_ccs"
set base_ff_0p88v_125c_lib             "N16ADFP_StdCellff0p88v125c_ccs"

# Logical names of SRAM libraries
set sram_tt_0p8v_25c_lib               "N16ADFP_SRAM_tt0p8v0p8v25c_100a"
set sram_ss_0p72v_m40c_lib             "N16ADFP_SRAM_ss0p72v0p72vm40c_100a"
set sram_ss_0p72v_125c_lib             "N16ADFP_SRAM_ss0p72v0p72v125c_100a"
set sram_ff_0p88v_m40c_lib             "N16ADFP_SRAM_ff0p88v0p88vm40c_100a"
set sram_ff_0p88v_125c_lib             "N16ADFP_SRAM_ff0p88v0p88v125c_100a"

## These logical library variables are used for reference in setting dont_use cells
## and reporting Vt library percentages.
set rm_base_lib "${base_ss_0p72v_125c_lib}.db:${base_ss_0p72v_125c_lib}"

# Target libraries for Multi-Vt synthesis and optimisation. Contains the standard
# cell libraries
set rm_target_library [list ${base_ss_0p72v_125c_lib}.db \ ${sram_ss_0p72v_125c_lib}.db
]

# -----------------------------------------------------------------------------------
# Min/Typ/Max library triplets for synthesis, optmization and analysis
# -----------------------------------------------------------------------------------
# The rm_mintypmax_libs variable contains 'triplets' of library files used to create
# link paths, etc. in the implementation and analysis scripts. Each triplet is made
# up of the fast, typical and slow (in that order) db's for a particular library of
# cell(s). 

set rm_mintypmax_libs [list \
    ${base_ff_0p88v_125c_lib}.db ${base_ff_0p88v_m40c_lib}.db ${base_tt_0p8v_25c_lib}.db ${base_ss_0p72v_125c_lib}.db ${base_ss_0p72v_m40c_lib}.db \
]

# -----------------------------------------------------------------------------------
# INVS Nominal Library Set
# -----------------------------------------------------------------------------------
                          
set rm_base_dirs   ${rm_base_reflib}/CCS/ 
set rm_sram_dirs   ${rm_sram_lib_dirs}/NLDM/
# set rm_sram_dirs        ${rm_sram_reflib}
 
set tt_0p8v_25c_libs   [list ${rm_base_dirs}/${base_tt_0p8v_25c_lib}.lib ${rm_sram_dirs}/${sram_tt_0p8v_25c_lib}.lib ]
set ff_0p88v_m40c_libs [list ${rm_base_dirs}/${base_ff_0p88v_m40c_lib}.lib ${rm_sram_dirs}/${sram_ff_0p88v_m40c_lib}.lib ]
set ff_0p88v_125c_libs [list ${rm_base_dirs}/${base_ff_0p88v_125c_lib}.lib ${rm_sram_dirs}/${sram_ff_0p88v_125c_lib}.lib ]
set ss_0p72v_m40c_libs [list ${rm_base_dirs}/${base_ss_0p72v_m40c_lib}.lib ${rm_sram_dirs}/${sram_ss_0p72v_m40c_lib}.lib ]
set ss_0p72v_125c_libs [list ${rm_base_dirs}/${base_ss_0p72v_125c_lib}.lib ${rm_sram_dirs}/${sram_ss_0p72v_125c_lib}.lib ]

# -----------------------------------------------------------------------------------
# SDC File
# -----------------------------------------------------------------------------------
set constraints_sdc         "../scripts/constraints.tcl"
set cts_constraints_sdc     "../scripts/constraints_cts.tcl"
set postcts_constraints_sdc "../scripts/constraints_postcts.tcl"

# Tie cells used to provide logic-1 and logic-0. 
set rm_tie_hi_lo_list [list TIEHBWP16P90 TIELBWP16P90]

# Output pin on the above-mentioned tie cells
set rm_tie_cell_pin [list "Z" "ZN"]

set rm_clock_cell [list]
set rm_clock_buf_cap_cell [list ]
set rm_clock_inv_cap_cell [list ]
set rm_clock_icg_cell [list ]
set rm_clock_size_cell [list $rm_clock_inv_cap_cell $rm_clock_buf_cap_cell]

set lvs_exclude_cells [list FILL64BWP16P90 FILL32BWP16P90 FILL16BWP16P90 FILL8BWP16P90 FILL4BWP16P90 FILL2BWP16P90 FILL1BWP16P90]

# If delay cells are needed they are referenced from this list
set rm_logic_delay_cell [list BUFFD2BWP16P90 BUFFD4BWP16P90 BUFFD8BWP16P90 BUFFD16BWP16P90]
set rm_clock_delay_cell $rm_logic_delay_cell

# List of hold-fixing delay cells. User may use the list in $rm_logic_delay_cell in combination with other delay or buffer cells
set hold_fixing_cells [list BUFFD2BWP16P90 BUFFD4BWP16P90 BUFFD8BWP16P90 BUFFD16BWP16P90]

# -----------------------------------------------------------------------------------
# Design Clock Period 
# -----------------------------------------------------------------------------------

set rm_clock_period 20 ;# Target clock period in ns of the macro

# ---------------------------------------------------------------------------------------------------
# Parameters used in Timing Characterization
# The numerical values in the [] brackets in the associated comment are some reasonable examples the user may adopt
# ---------------------------------------------------------------------------------------------------

set rm_load_value 0.05 ;# Capacitive load in pF placed on all outputs
set rm_driving_cell BUFFD8BWP16P90 ;# The driving cell for all inputs
set rm_driving_pin Z ;# The output pin of the driving cell

set rm_dont_use_list [list *BWP20* *LVT]
#set rm_dont_use_list [list *BWP20*]

set rm_clock_driving_cell [list CKBD1BWP20P90 CKBD2BWP20P90 CKBD4BWP20P90 CKBD8BWP20P90 CKBD12BWP20P90 CKBD16BWP20P90] ;# The driving cell for clock ports
set rm_clock_driving_pin Z ;# The output pin of the clock driving cell

set rm_setup_margin 0.050 ;# in ns. Setup margin 
set rm_hold_margin 0.0 ;# in ns. Hold margin 
set rm_clock_uncertainty 0.100 ;# in ns. Pre-CTS clock skew estimate 
set rm_pre_cts_clock_uncertainty 0.100 ;# in ns. Pre-CTS clock skew estimate
set rm_post_cts_clock_uncertainty 0.075 ;# in ns. Post-CTS clock skew estimate 
set rm_critical_range 0.1 ;# Critical range. % of the rm_clock_period 
set rm_icg_name integrated ;# Name of ICG cell
set rm_max_fanout 32 ;# Maximum fanout threshold 
set rm_cts_max_fanout 16 ;# Maximum fanout threshold 
set rm_max_transition 0.500 ;# Maximum rise/fall signal transition time in ns 
set rm_max_clock_transition 0.500 ;# Maximum rise/fall clock transition time in ns 
set rm_clock_latency 1 ;# Predicted clock insertion delay in ns 
set rm_icg_latency 0.070 ;# Latency in ns for integrated clock gating cell 



# -----------------------------------------------------------------------------------
# Floorplan Control Setup
# -----------------------------------------------------------------------------------
set rm_core_utilization 0.8 ;# Utilization ratio of the macro floorplan 
set rm_aspect_ratio 1.00 ;# Height-to-width ratio of the macro floorplan 
