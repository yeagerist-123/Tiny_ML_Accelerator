# 1. Read all RTL source files
# (Adjust paths if your files are in an /rtl folder)
read_verilog rtl/compute/systolic_array.v
read_verilog rtl/compute/relu.v
read_verilog rtl/memory/weight_buffer.v
read_verilog rtl/memory/activation_buffer.v
read_verilog rtl/control/controller_fsm.v
read_verilog rtl/top/top_tinyml.v


# 2. Check hierarchy and set the top module
hierarchy -check -top top_tinyml

# 3. High-level Synthesis (Translates Verilog to internal RTLIL)
synth -top top_tinyml

# 4. Map to Internal Registers (Flip-Flops)
dfflibmap -liberty /home/mohan123/pdk/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 5. Map to Gate-Level Logic (ABC tool)
# This maps your logic to the actual Sky130 standard cells
abc -liberty /home/mohan123/pdk/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 6. Clean up unused wires and optimize the design
opt
clean
flatten

# 7. Write the final Gate-Level Netlist
# IMPORTANT: -noattr removes the metadata that caused the OpenSTA syntax error
write_verilog -noattr synth_output.v

# 8. Print Area Statistics (For your GitHub README)
stat -liberty /home/mohan123/pdk/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
