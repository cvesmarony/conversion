# Base Library Sets

create_library_set -name tt_0p8v_25c_lib_set \
   -timing $tt_0p8v_25c_libs 

create_library_set -name ff_0p88v_125c_lib_set \
  -timing $ff_0p88v_125c_libs 

create_library_set -name ss_0p72v_m40c_lib_set \
   -timing $ss_0p72v_m40c_libs 


if {${rm_task} == "synthesis"} {
    create_opcond -name tc_corner -process 1.0 -temperature 25 -voltage 0.8
    create_opcond -name bc_corner -process 1.0 -temperature 125 -voltage 0.88
    create_opcond -name wc_corner -process 1.0 -temperature -40 -voltage 0.72
   
    create_timing_condition -name typ_time_cond \
        -opcond tc_corner \
        -library_sets tt_0p8v_25c_lib_set 
    
    create_timing_condition -name slow_time_cond \
        -opcond wc_corner \
        -library_sets ss_0p72v_m40c_lib_set 
    
    create_timing_condition -name fast_time_cond \
       -opcond bc_corner \
       -library_sets ff_0p88v_125c_lib_set 


    # Create Base delay corners                   
    create_delay_corner -name tt_0p8v_25c_delay_corner \
        -timing_condition typ_time_cond \
        -si_enabled true
    
    create_delay_corner -name ff_0p88v_125c_delay_corner \
       -timing_condition fast_time_cond \
       -si_enabled true
    
    create_delay_corner -name ss_0p72v_m40c_delay_corner \
        -timing_condition slow_time_cond \
        -si_enabled true

} else {
    # Create RC Corners
   #  There is no typical RC corner file provided for this technology
    create_rc_corner -name rc_typ_25c \
       -qx_tech_file  ${rm_qrc_min_file} \
       -T 25
    
   create_rc_corner -name rc_best_125c \
       -qx_tech_file  ${rm_qrc_min_file} \
       -T 125
    
    create_rc_corner -name rc_worst_m40c \
       -qx_tech_file  ${rm_qrc_max_file} \
       -T -40
   
    # Create Base delay corners
    create_delay_corner -name tt_0p8v_25c_delay_corner \
       -library_set tt_0p8v_25c_lib_set \
       -rc_corner rc_typ_25c \
       -si_enabled true
    
    create_delay_corner -name ff_0p88v_125c_delay_corner \
      -library_set ff_0p88v_125c_lib_set \
      -rc_corner rc_best_125c \
      -si_enabled true
    
    create_delay_corner -name ss_0p72v_m40c_delay_corner \
       -library_set ss_0p72v_m40c_lib_set \
       -rc_corner rc_worst_m40c \
       -si_enabled true
}    

# Constraints mode
create_constraint_mode -name tt0p8v25c_mode \
                       -sdc_files $constraints_sdc

create_constraint_mode -name ss0p72vm40c_mode \
                       -sdc_files $constraints_sdc

create_constraint_mode -name ff0p88v125c_mode \
                       -sdc_files $constraints_sdc

# Analysis Views
create_analysis_view -name typical -constraint_mode tt0p8v25c_mode -delay_corner tt_0p8v_25c_delay_corner
create_analysis_view -name normBC -constraint_mode ff0p88v125c_mode -delay_corner ff_0p88v_125c_delay_corner
create_analysis_view -name normWC -constraint_mode ss0p72vm40c_mode -delay_corner ss_0p72v_m40c_delay_corner

    
set_analysis_view -setup [list normWC] \
                  -hold [list normBC] 
