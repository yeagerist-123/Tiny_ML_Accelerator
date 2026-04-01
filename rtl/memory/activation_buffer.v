module activation_buffer (
    input clk,
    input write_en,
    input [1:0] addr,
    input [7:0] data_in,
    output reg [31:0] act_bus
);

    reg [7:0] mem [0:3];

    always @(posedge clk) begin
        if (write_en)
            mem[addr] <= data_in;

        act_bus <= {mem[3], mem[2], mem[1], mem[0]};
    end
endmodule
