create_clock -name clk -period $rm_clock_period [get_ports clk]
create_clock -name VCLK -period $rm_clock_period

set_clock_uncertainty 0.02 [get_ports clk]

set_clock_transition -rise -min 0.002 [get_clocks clk]
set_clock_transition -rise -max 0.005 [get_clocks clk]
set_clock_transition -fall -min 0.002 [get_clocks clk]
set_clock_transition -fall -max 0.005 [get_clocks clk]

set inputs [remove_from_collection [all_inputs] clk]
set outputs [all_outputs]

set_input_delay 0.3 -clock VCLK -max  $inputs
set_output_delay 0.3 -clock VCLK -max  $outputs

set_input_delay 0 -clock VCLK -min $inputs
set_output_delay 0 -clock VCLK -min  $outputs
