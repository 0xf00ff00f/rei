`define ALU_ADD     3'b000
`define ALU_SUB     3'b001
`define ALU_AND     3'b010
`define ALU_OR      3'b011
`define ALU_XOR     3'b100
`define ALU_NAND    3'b101
`define ALU_SHL     3'b110
`define ALU_SHR     3'b111

module mux(data0, data1, select, result);
    input [31:0] data0, data1;
    input select;
    output [31:0] result;
    assign result = select ? data1 : data0;
endmodule

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

module cpu(clk);
    input clk;

    reg [31:0] pc;
    initial begin
        pc <= 0;
    end

    wire [31:0] pc1, pc_branch;

    wire [31:0] insn;

    wire [4:0] rd;
    assign rd = insn[25:21];

    wire [4:0] rs;
    assign rs = insn[20:16];

    wire [4:0] rt;
    assign rt = insn[15:11];

    wire [15:0] imm;
    assign imm = insn[15:0];

    assign pc1 = pc + 1;
    assign pc_branch = pc1 + {{16{imm[15]}}, imm};

    wire write_pc_enable;
    assign write_pc_enable = insn[30];

    wire write_reg_enable;
    assign write_reg_enable = ~write_pc_enable;

    wire [31:0] reg_data0, reg_data1, alu_result;

    wire imm_or_reg_data1_select;
    assign imm_or_reg_data1_select = insn[29];

    wire [31:0] alu_data1;

    instruction_memory im(.addr(pc[7:0]), .data(insn));

    register_file rf(
        .clk(clk),
        .read_reg0(rs), .read_reg1(rt),
        .write_reg(rd), .write_data(alu_result), .write_reg_enable(write_reg_enable),
        .read_data0(reg_data0), .read_data1(reg_data1));

    mux alu_data1_mux(
        .data0(reg_data1), .data1({16'b0, imm}),
        .select(imm_or_reg_data1_select),
        .result(alu_data1));

    alu alu(
        .data0(reg_data0), .data1(alu_data1),
        .control(insn[28:26]),
        .result(alu_result));

    always @(posedge clk) begin
        pc <= write_pc_enable ? pc_branch : pc1;
    end

    initial begin
        $monitor("time=%d pc=%x insn=%x rs=%x rt=%x imm=%x r1=%d r2=%d r3=%d",
            $time, pc, insn, rs, rt, imm, rf.registers[1], rf.registers[2], rf.registers[3]);
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
