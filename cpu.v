`define ALU_ADD     3'b000
`define ALU_SUB     3'b001
`define ALU_AND     3'b010
`define ALU_OR      3'b011
`define ALU_XOR     3'b100
`define ALU_NAND    3'b101
`define ALU_SHL     3'b110
`define ALU_SHR     3'b111

`define OP_ALU_RRR  3'b000
`define OP_ALU_RRI  3'b001
`define OP_J        3'b010
`define OP_MEM      3'b011

module instruction_memory(addr, data);
    input [7:0] addr;
    output [31:0] data;

    reg [31:0] memory [0:255];

    initial begin
        $readmemh("instructions.hex", memory);
    end

    assign data = memory[addr];
endmodule

module register_file(
            clk,
            read_reg0, read_reg1,
            write_reg, write_data, write_reg_enable,
            read_data0, read_data1);
    input clk;
    input [4:0] read_reg0, read_reg1, write_reg;
    input [31:0] write_data;
    input write_reg_enable;
    output [31:0] read_data0, read_data1;

    reg [31:0] registers [0:31];
    initial begin
        $readmemh("registers.hex", registers);
    end

    always @(posedge clk) begin
        if (write_reg_enable)
            registers[write_reg] <= write_data;
    end

    assign read_data0 = read_reg0 ? registers[read_reg0] : 0;
    assign read_data1 = read_reg1 ? registers[read_reg1] : 0;
endmodule

module data_memory(
            clk,
            addr,
            write_data,
            write_enable, 
            read_data);
    input clk;
    input [7:0] addr;
    input [31:0] write_data;
    input write_enable;
    output [31:0] read_data;

    reg [31:0] memory [0:255];

    always @(posedge clk) begin
        if (write_enable) begin
            memory[addr] <= write_data;
        end
    end

    assign read_data = memory[addr];
endmodule

module alu(data0, data1, control, result);
    input [31:0] data0, data1;
    input [2:0] control;
    output reg [31:0] result;

    always @(*) begin
        case (control)
            `ALU_ADD:  result <= data0 + data1;
            `ALU_SUB:  result <= data0 - data1;
            `ALU_AND:  result <= data0 & data1;
            `ALU_OR:   result <= data0 | data1;
            `ALU_XOR:  result <= data0 ^ data1;
            `ALU_NAND: result <= ~(data0 & data1);
            `ALU_SHL:  result <= data0 << data1;
            `ALU_SHR:  result <= data0 >> data1;
        endcase
    end
endmodule

module control(
            opcode,
            write_reg_enable,
            rd_or_rt_data1_select,
            mem_or_alu_write_reg_select,
            imm_or_reg_data1_select,
            branch_enable,
            write_mem_enable);
    input [5:0] opcode;
    output write_reg_enable, rd_or_rt_data1_select, mem_or_alu_write_reg_select, imm_or_reg_data1_select, branch_enable, write_mem_enable;

    wire [2:0] insn_type;
    assign insn_type = opcode[5:3];

    wire insn_lw;
    assign insn_lw = insn_type == `OP_MEM && opcode[0] == 0;

    wire insn_sw;
    assign insn_sw = insn_type == `OP_MEM && opcode[0] == 1;

    assign write_reg_enable = insn_type == `OP_ALU_RRR || insn_type == `OP_ALU_RRI || insn_lw;
    assign rd_or_rt_data1_select = insn_sw;
    assign mem_or_alu_write_reg_select = insn_lw;
    assign imm_or_reg_data1_select = insn_type == `OP_ALU_RRI;
    assign branch_enable = insn_type == `OP_J;
    assign write_mem_enable = insn_sw;
endmodule

module cpu(clk);
    input clk;

    reg [31:0] pc;
    initial begin
        pc <= 0;
    end

    wire [31:0] pc1;
    assign pc1 = pc + 1;

    wire [31:0] branch_target;
    assign branch_target = pc1 + {{16{imm[15]}}, imm};

    wire [31:0] insn;

    wire [5:0] opcode;
    assign opcode = insn[31:26];

    wire [4:0] rd;
    assign rd = insn[25:21];

    wire [4:0] rs;
    assign rs = insn[20:16];

    wire [4:0] rt;
    assign rt = insn[15:11];

    wire [15:0] imm;
    assign imm = insn[15:0];

    wire branch_enable;

    wire write_reg_enable;

    wire [31:0] reg_data0, reg_data1, alu_result;

    wire imm_or_reg_data1_select;
    wire rd_or_rt_data0_select;
    wire mem_or_alu_write_reg_select;

    wire [4:0] read_reg1;
    assign read_reg1 = rd_or_rt_data1_select ? rd : rt;

    wire [31:0] write_reg_data;
    assign write_reg_data = mem_or_alu_write_reg_select ? mem_data : alu_result;

    wire [31:0] alu_data1;
    assign alu_data1 = imm_or_reg_data1_select ? {16'b0, imm} : reg_data1;

    wire [31:0] write_mem_data;
    assign write_mem_data = reg_data1;

    wire [7:0] mem_addr;
    assign mem_addr = reg_data0[7:0] + imm[7:0];

    wire write_mem_enable;

    wire [31:0] mem_data;

    always @(posedge clk) begin
        pc <= branch_enable ? branch_target : pc1;
    end

    control ctl(
        .opcode(opcode),
        .write_reg_enable(write_reg_enable),
        .rd_or_rt_data1_select(rd_or_rt_data1_select),
        .mem_or_alu_write_reg_select(mem_or_alu_write_reg_select),
        .imm_or_reg_data1_select(imm_or_reg_data1_select),
        .branch_enable(branch_enable),
        .write_mem_enable(write_mem_enable));

    instruction_memory im(.addr(pc[7:0]), .data(insn));

    register_file rf(
        .clk(clk),
        .read_reg0(rs), .read_reg1(read_reg1),
        .write_reg(rd), .write_data(write_reg_data), .write_reg_enable(write_reg_enable),
        .read_data0(reg_data0), .read_data1(reg_data1));

    alu alu(
        .data0(reg_data0), .data1(alu_data1),
        .control(insn[28:26]),
        .result(alu_result));

    data_memory mem(
        .clk(clk),
        .addr(mem_addr),
        .write_data(write_mem_data), .write_enable(write_mem_enable),
        .read_data(mem_data));

    initial begin
        $monitor("time=%d pc=%x insn=%x rd=%x rs=%x rt=%x imm=%x r1=%x r2=%x r3=%x mem[0]=%x mem[1]=%x mem_addr=%x write_mem_data=%x write_mem_enable=%x",
            $time, pc, insn, rd, rs, rt, imm, rf.registers[1], rf.registers[2], rf.registers[3], mem.memory[0], mem.memory[1], mem_addr, write_mem_data, write_mem_enable);
    end
endmodule

module test;
    reg clk;
    integer i;

    cpu cpu(clk);

    initial begin
        #100 clk <= 0;
        for (i = 0; i < 100; i++) begin
            #100 clk <= ~clk;
        end
    end
endmodule
