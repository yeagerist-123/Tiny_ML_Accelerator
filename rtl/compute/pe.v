module pe #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH = 24
)(
    input clk,
    input reset,
    input load_weight,
    input signed [DATA_WIDTH-1:0] weight_in,
    input signed [DATA_WIDTH-1:0] act_in,
    input signed [ACC_WIDTH-1:0] psum_in,
    output reg signed [DATA_WIDTH-1:0] act_out,
    output reg signed [ACC_WIDTH-1:0] psum_out
);

    reg signed [DATA_WIDTH-1:0] weight_reg;

    always @(posedge clk) begin
        if (reset) begin
            weight_reg <= 0;
            act_out <= 0;
            psum_out <= 0;
        end else begin
            if (load_weight)
                weight_reg <= weight_in;

            act_out <= act_in;
            psum_out <= psum_in + (act_in * weight_reg);
        end
    end
endmodule
