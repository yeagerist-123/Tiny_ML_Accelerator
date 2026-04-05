#define the clock
create_clock -name clk -period 11 [get_ports clk]
#Set input delays
set_input_delay -clock clk 2.0 [all_inputs]
#Set output delays
set_output_delay -clock clk 2.0 [all_outputs]
#environment constraints
set_load 0.033 [all_outputs]
