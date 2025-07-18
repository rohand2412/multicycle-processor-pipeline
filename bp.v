`timescale 1ps/1ps

module bp(input clk,
          input [15:1] raddr0, output [15:1] rdata0,
          input wen, input [15:1] waddr, input [15:1] wdata);

    reg [14:0] data [0:15'h7fff];

    integer i;
    initial begin
        for (i = 0; i <= 15'h7fff; i = i + 1) begin
            data[i] = i + 1;
        end
    end

    assign rdata0 = data[raddr0];

    always @(posedge clk) begin
        if (wen) begin
            data[waddr] <= wdata;
        end
    end
endmodule
