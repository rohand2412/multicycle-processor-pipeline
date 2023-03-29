`timescale 1ps/1ps

module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(0,main);
    end

    // clock
    wire clk;
    clock c0(clk);

    reg halt = 0;

    counter ctr(halt,clk);

    // PC
    reg [15:0]pc = 16'h0000;

    // read from memory
    wire [15:0]something;

    // memory
    mem mem(clk,
         pc[15:1],something,,,,,);


    // registers
    regs regs(clk,
        ,,
        ,,
        ,,);

    always @(posedge clk) begin
        if (pc == 10) begin
            halt <= 1;
        end
        $write("pc = %d\n",pc);
        pc <= pc + 1;
    end


endmodule
