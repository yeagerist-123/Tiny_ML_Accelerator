module top_tinyml (
    input clk, reset, start,
    input [7:0] data_in,
    input [3:0] addr,
    input wr_weight_en, wr_act_en,
    output [31:0] ml_output,
    output done
);

    wire [127:0] w_bus;
    wire [31:0]  a_bus;
    wire [95:0]  psum_bus;

    controller_fsm fsm (
        .clk(clk), .reset(reset), .start(start), .done(done)
    );

    weight_buffer wb (
        .clk(clk), .reset(reset), .write_en(wr_weight_en), .addr(addr), .data_in(data_in), .weight_bus(w_bus)
    );

    activation_buffer ab (
        .clk(clk), .reset(reset), .write_en(wr_act_en), .addr(addr[1:0]), .data_in(data_in), .act_bus(a_bus)
    );

    systolic_array sa (
        .weight_bus(w_bus), .act_in_bus(a_bus), .psum_out_bus(psum_bus)
    );

    relu r0(.data_in(psum_bus[23:0]),  .data_out(ml_output[7:0]));
    relu r1(.data_in(psum_bus[47:24]), .data_out(ml_output[15:8]));
    relu r2(.data_in(psum_bus[71:48]), .data_out(ml_output[23:16]));
    relu r3(.data_in(psum_bus[95:72]), .data_out(ml_output[31:24]));

endmodule
