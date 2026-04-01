module weight_buffer (
    input clk,
    input write_en,
    input [3:0] addr,
    input [7:0] data_in,
    output reg [127:0] weight_bus
);

    reg [7:0] mem [0:15];

    integer i;

    always @(posedge clk) begin
        if (write_en)
            mem[addr] <= data_in;

        for (i=0;i<16;i=i+1)
            weight_bus[i*8 +: 8] <= mem[i];
    end
endmodule
