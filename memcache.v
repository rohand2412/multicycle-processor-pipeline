`timescale 1ps/1ps

module memcache(input clk,
                input [15:1] raddr0, output rexists0, output [15:0] rdata0,
                input [15:1] raddr1, output rexists1, output [15:0] rdata1,
                input wen, input [15:1] waddr, input [15:0] wdata,
                output mem_wen, output [15:1] mem_waddr, output [15:0] mem_wdata);

    parameter LEN = 10;

    reg mem_en [0:LEN-1];
    reg [15:1] mem_addr [0:LEN-1];
    reg [15:0] mem_data [0:LEN-1];

    integer i;
    initial begin
        for (i = 0; i < LEN; i = i + 1) begin
            mem_en[i] = 0;
            mem_addr[i] = 0;
            mem_data[i] = 0;
        end
    end

    wire [LEN-1:0] rfound0;
    wire [LEN-1:0] rfound1;
    wire [LEN-1:0] wfound;

    genvar j;
    generate
        for (j = 0; j < LEN; j = j + 1) begin
            assign rfound0[j] = mem_en[j] & (mem_addr[j] == raddr0);
            assign rfound1[j] = mem_en[j] & (mem_addr[j] == raddr1);
            assign wfound[j] = mem_en[j] & (mem_addr[j] == waddr);
        end
    endgenerate

    assign rexists0 = |rfound0;
    assign rexists1 = |rfound1;

    wire wexists;
    assign wexists = |wfound;

    wire [LEN-1:0] mem_rdata0 [0:15];
    wire [LEN-1:0] mem_rdata1 [0:15];

    genvar k;
    genvar k2;
    generate
        for (k = 0; k < LEN; k = k + 1) begin
            for (k2 = 0; k2 <= 15; k2 = k2 + 1) begin
                assign mem_rdata0[k2][k] = rfound0[k] & mem_data[k][k2];
                assign mem_rdata1[k2][k] = rfound1[k] & mem_data[k][k2];
            end
        end
    endgenerate

    genvar k3;
    generate
        for (k3 = 0; k3 <= 15; k3 = k3 + 1) begin
            assign rdata0[k3] = |mem_rdata0[k3];
            assign rdata1[k3] = |mem_rdata1[k3];
        end
    endgenerate

    wire mem_en_in [0:LEN-1];
    wire [15:1] mem_addr_in [0:LEN-1];
    wire [15:0] mem_data_in [0:LEN-1];

    genvar l;
    generate
        for (l = 1; l < LEN; l = l + 1) begin
            assign mem_en_in[l] = (wen & wexists) ? (wfound[l] ? wen : mem_en[l]) : (wen ? mem_en[l-1] : mem_en[l]);
            assign mem_addr_in[l] = (wen & wexists) ? (wfound[l] ? waddr : mem_addr[l]) : (wen ? mem_addr[l-1] : mem_addr[l]);
            assign mem_data_in[l] = (wen & wexists) ? (wfound[l] ? wdata : mem_data[l]) : (wen ? mem_data[l-1] : mem_data[l]);
        end
    endgenerate

    assign mem_en_in[0] = (wen & (~wexists | mem_addr[0] == waddr)) ? wen : mem_en[0];
    assign mem_addr_in[0] = (wen & (~wexists | mem_addr[0] == waddr)) ? waddr : mem_addr[0];
    assign mem_data_in[0] = (wen & (~wexists | mem_addr[0] == waddr)) ? wdata : mem_data[0];

    assign mem_wen = wen & mem_en[LEN-1] & ~wexists;
    assign mem_waddr = mem_addr[LEN-1];
    assign mem_wdata = mem_data[LEN-1];

    integer p;
    always @(posedge clk) begin
        for (p = 0; p < LEN; p = p + 1) begin
            mem_en[p] <= mem_en_in[p];
            mem_addr[p] <= mem_addr_in[p];
            mem_data[p] <= mem_data_in[p];
        end
    end

endmodule