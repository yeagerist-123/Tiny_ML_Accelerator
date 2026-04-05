# ---------------------------------------------------------
# 1. Read the Sky130 Standard Cell Library 
# ---------------------------------------------------------
read_liberty /home/mohan123/pdk/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# ---------------------------------------------------------
# 2. Read the Netlist and Link Design
# ---------------------------------------------------------
# Ensure 'synth_output.v' is the name of the file created by Yosys
read_verilog synth_output.v
link_design top_tinyml

# ---------------------------------------------------------
# 3. Read Constraints (SDC)
# ---------------------------------------------------------
read_sdc constraints/sky130.sdc

# ---------------------------------------------------------
# 4. Analysis & Reporting
# ---------------------------------------------------------
# We use 'report_power' without 'set_switching_activity' to avoid 
# command errors in this version of OpenSTA. It will use library defaults.

puts "--- GENERATING TIMING REPORT ---"
report_checks -path_delay max -format full_clock_expanded

puts "--- GENERATING POWER REPORT ---"
report_power

# ---------------------------------------------------------
# 5. Exit
# ---------------------------------------------------------
exit
