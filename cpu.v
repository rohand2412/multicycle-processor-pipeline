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
    wire halt_in;

    counter ctr(halt,clk);

    always @(posedge clk) begin
        halt <= halt_in;
    end

    // memory
    wire [15:1] mem_raddr0;
    wire [15:0] mem_rdata0;
    wire [15:1] mem_raddr1;
    wire [15:0] mem_rdata1;
    wire [15:1] mem_waddr;
    wire [15:0] mem_wdata;
    wire mem_wen;
    mem mem(
        clk,
        mem_raddr0, mem_rdata0,
        mem_raddr1, mem_rdata1,
        mem_wen, mem_waddr, mem_wdata
    );

    // registers
    wire [3:0] reg_raddr0;
    wire [15:0] reg_rdata0;
    wire [3:0] reg_raddr1;
    wire [15:0] reg_rdata1;
    wire [3:0] reg_waddr;
    wire [15:0] reg_wdata;
    wire reg_wen;
    regs regs(
        clk,
        reg_raddr0, reg_rdata0,
        reg_raddr1, reg_rdata1,
        reg_wen, reg_waddr, reg_wdata
    );

    // branch prediction
    wire [15:1] bp_raddr0;
    wire [15:1] bp_rdata0;
    wire [15:1] bp_waddr;
    wire [15:1] bp_wdata;
    wire bp_wen;
    bp bp(
        clk,
        bp_raddr0, bp_rdata0,
        bp_wen, bp_waddr, bp_wdata
    );

    // control
    wire flush;
    wire stall0;
    wire stall1;

    // fetch
    reg f_valid = 0;
    wire f_valid_in;
    assign f_valid_in = 1;

    reg [15:1] f_pc = 15'h0000;

    assign bp_raddr0 = flush ? e_jmp_addr : f_pc;
    assign bp_wdata = e_jmp_addr;
    assign bp_waddr = e_pc;
    assign bp_wen = flush;

    wire [15:1] f_pc_in;
    assign f_pc_in = stall0 ? f_pc : bp_rdata0;

    reg [15:1] f_oldpc;
    wire [15:1] f_oldpc_next;
    wire [15:1] f_oldpc_in;
    assign f_oldpc_next = flush ? e_jmp_addr : f_pc;
    assign f_oldpc_in = stall0 ? f_oldpc : f_oldpc_next;

    assign mem_raddr0 = f_oldpc_in;
    assign mem_raddr1 = e_ldp_bit1 ? e_ra[15:1] + 1 : e_ra[15:1];
    assign mem_wdata = e_rbt;
    assign mem_waddr = e_stp_bit ? e_ra[15:1] + 1 : e_ra[15:1];
    assign mem_wen = (e_st | e_stp) & e_valid;

    reg [15:1] f_pc1;
    wire [15:1] f_pc1_in;
    assign f_pc1_in = mem_raddr0;

    reg [15:1] f_pc2;
    wire [15:1] f_pc2_in;
    assign f_pc2_in = f_pc1;

    reg [15:0] f_nextinst;
    wire [15:0] f_nextinst_in;
    assign f_nextinst_in = stall1 ? f_nextinst : mem_rdata0;

    wire [15:0] f_nextinst_out;
    assign f_nextinst_out = stall1 ? f_nextinst : mem_rdata0;

    reg [15:0] f_oldinst;
    wire [15:0] f_oldinstmux_in;
    wire [15:0] f_oldinst_in;
    assign f_oldinstmux_in = stall1 ? f_nextinst : mem_rdata0;
    assign f_oldinst_in = stall0 ? f_oldinst : f_oldinstmux_in;

    wire [15:0] f_inst_out;
    assign f_inst_out = stall0 ? f_oldinst : f_nextinst_out;

    always @(posedge clk) begin
        f_valid <= f_valid_in;
        f_pc <= f_pc_in;
        f_oldpc <= f_oldpc_in;
        f_pc1 <= f_pc1_in;
        f_pc2 <= f_pc2_in;
        f_oldinst <= f_oldinst_in;
        f_nextinst <= f_nextinst_in;
    end

    // decode
    reg d_valid = 0;
    wire d_valid_in;
    assign d_valid_in = f_valid & ~flush;

    reg [15:1] d_pc;
    wire [15:1] d_pc_in;
    assign d_pc_in = f_pc2;

    reg [15:0] d_inst;
    wire [15:0] d_inst_in;
    assign d_inst_in = f_inst_out;

    wire [3:0] d_raddr1_in;
    assign d_raddr1_in = d_inst_in[15] ? d_inst_in[3:0] : d_inst_in[7:4];

    assign reg_raddr0 = d_inst_in[11:8];
    assign reg_raddr1 = e_stp_bit_in ? d_inst_in[3:0] + 1 : d_raddr1_in;
    assign reg_wdata = (e_ld_bit2 | e_ldp_bit2) ? mem_rdata1 : e_rt;
    assign reg_waddr = e_ldp_bit3 ? e_inst_t + 1 : e_inst_t;
    assign reg_wen = ((e_sub | e_se | e_sh) & e_valid) | (e_ld_bit2 | e_ldp_bit2);

    assign halt_in = d_valid & ~flush & (d_inst_in === 16'hxxxx | (
        d_inst_in[15:12] != 4'b0000
        & d_inst_in[15:13] != 3'b100
        & (d_inst_in[15:13] != 3'b111 | d_inst_in[7:6] != 2'b00)
    ));

    always @(posedge clk) begin
        d_valid <= d_valid_in;
        d_pc <= d_pc_in;
        d_inst <= d_inst_in;

        if (reg_wen & reg_waddr == 0) begin
            $write("%c", reg_wdata[7:0]);
        end
    end

    // execute
    reg e_valid = 0;
    wire e_valid_in;
    assign e_valid_in = d_valid & ~flush;

    wire [15:1] e_pc;
    assign e_pc = d_pc;

    wire [15:0] e_inst;
    assign e_inst = d_inst;

    wire e_sub;
    wire e_se;
    wire e_sh;
    wire e_jz;
    wire e_jnz;
    wire e_js;
    wire e_jns;
    wire e_ld;
    wire e_st;
    wire e_ldp;
    wire e_stp;
    assign e_sub = e_inst[15:12] == 4'b0000;
    assign e_se  = e_inst[15:12] == 4'b1000;
    assign e_sh  = e_inst[15:12] == 4'b1001;
    assign e_jz  = e_inst[15:12] == 4'b1110 & e_inst[7:4] == 4'b0000;
    assign e_jnz = e_inst[15:12] == 4'b1110 & e_inst[7:4] == 4'b0001;
    assign e_js  = e_inst[15:12] == 4'b1110 & e_inst[7:4] == 4'b0010;
    assign e_jns = e_inst[15:12] == 4'b1110 & e_inst[7:4] == 4'b0011;
    assign e_ld  = e_inst[15:12] == 4'b1111 & e_inst[7:4] == 4'b0000;
    assign e_st  = e_inst[15:12] == 4'b1111 & e_inst[7:4] == 4'b0001;
    assign e_ldp = e_inst[15:12] == 4'b1111 & e_inst[7:4] == 4'b0010;
    assign e_stp = e_inst[15:12] == 4'b1111 & e_inst[7:4] == 4'b0011;

    reg e_wen = 0;
    wire e_wen_in;
    assign e_wen_in = reg_wen;

    reg [3:0] e_waddr;
    wire [3:0] e_waddr_in;
    assign e_waddr_in = reg_waddr;

    reg [15:0] e_wdata;
    wire [15:0] e_wdata_in;
    assign e_wdata_in = reg_wdata;

    wire [3:0] e_inst_a;
    assign e_inst_a = e_inst[11:8];

    wire [3:0] e_inst_bt_in;
    assign e_inst_bt_in = e_inst[15] ? e_inst[3:0] : e_inst[7:4];

    wire [3:0] e_inst_bt;
    assign e_inst_bt = e_stp_bit ? e_inst[3:0] + 1 : e_inst_bt_in;

    wire [7:0] e_inst_i;
    assign e_inst_i = e_inst[11:4];

    wire [3:0] e_inst_t;
    assign e_inst_t = e_inst[3:0];

    wire [15:0] e_ra;
    assign e_ra = e_inst_a == 0 ? 0 : (e_inst_a == e_waddr & e_wen ? e_wdata : reg_rdata0);

    wire [15:0] e_rbt;
    assign e_rbt = e_inst_bt == 0 ? 0 : (e_inst_bt == e_waddr & e_wen ? e_wdata : reg_rdata1);

    wire [15:0] e_sub_rt;
    assign e_sub_rt = e_ra - e_rbt;

    wire [15:0] e_se_rt;
    assign e_se_rt = { {8{e_inst_i[7]}}, e_inst_i };

    wire [15:0] e_sh_rt;
    assign e_sh_rt = { e_inst_i, e_rbt[7:0] };

    wire [15:0] e_rt;
    assign e_rt = e_sh ? e_sh_rt : (e_se ? e_se_rt : e_sub_rt);

    wire e_jmp;
    assign e_jmp = (
        (e_ra == 0 & e_jz)
        | (e_ra != 0 & e_jnz)
        | (e_ra[15] & e_js)
        | (~e_ra[15] & e_jns)
    );

    reg e_ld_bit1 = 0;
    reg e_ld_bit2 = 0;
    wire e_ld_bit1_in;
    wire e_ld_bit2_in;
    assign e_ld_bit1_in = (e_ld & e_valid) & ~e_ld_bit2;
    assign e_ld_bit2_in = e_ld_bit1 & ~e_ld_bit2;

    reg e_ldp_bit1 = 0;
    reg e_ldp_bit2 = 0;
    reg e_ldp_bit3 = 0;
    wire e_ldp_bit1_in;
    wire e_ldp_bit2_in;
    wire e_ldp_bit3_in;
    assign e_ldp_bit1_in = (e_ldp & e_valid) & ~e_ldp_bit3;
    assign e_ldp_bit2_in = e_ldp_bit1 & ~e_ldp_bit3;
    assign e_ldp_bit3_in = e_ldp_bit2 & ~e_ldp_bit3;

    reg e_stp_bit = 0;
    wire e_stp_bit_in;
    assign e_stp_bit_in = (e_stp & e_valid) & ~e_stp_bit;

    wire [15:1] e_jmp_addr;
    assign e_jmp_addr = e_jmp ? e_rbt[15:1] : e_pc + 1;

    wire e_inst_j;
    assign e_inst_j = e_jz | e_jnz | e_js | e_jns;

    wire e_wrong_branch;
    assign e_wrong_branch = e_inst_j & (e_jmp_addr != d_pc_in);

    assign flush = e_valid & e_wrong_branch;
    assign stall0 = e_ld_bit1_in | e_ldp_bit1_in | e_stp_bit_in;
    assign stall1 = e_ld_bit1 | e_ldp_bit1 | e_stp_bit;

    always @(posedge clk) begin
        e_valid <= e_valid_in;
        e_wen <= e_wen_in;
        e_waddr <= e_waddr_in;
        e_wdata <= e_wdata_in;
        e_ld_bit1 <= e_ld_bit1_in;
        e_ld_bit2 <= e_ld_bit2_in;
        e_ldp_bit1 <= e_ldp_bit1_in;
        e_ldp_bit2 <= e_ldp_bit2_in;
        e_ldp_bit3 <= e_ldp_bit3_in;
        e_stp_bit <= e_stp_bit_in;
    end

endmodule
