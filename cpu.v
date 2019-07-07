`define ALU_ADD     3'b000
`define ALU_SUB     3'b001
`define ALU_AND     3'b010
`define ALU_OR      3'b011
`define ALU_XOR     3'b100
`define ALU_NAND    3'b101
`define ALU_SHL     3'b110
`define ALU_SHR     3'b111

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
            read_reg0, read_reg1, write_reg,
            read_data0, read_data1);
    input [4:0] read_reg0, read_reg1, write_reg;
    output [31:0] read_data0, read_data1;

    reg [31:0] registers [0:31];
    initial begin
        $readmemh("registers.hex", registers);
    end

    assign read_data0 = registers[read_reg0];
    assign read_data1 = registers[read_reg1];
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

    wire [31:0] pc1 = pc + 1;
    always @(posedge clk) begin
        pc <= pc1;
    end

    wire [31:0] insn;

    wire [4:0] rd;
    assign rd = insn[25:21];

    wire [4:0] rs;
    assign rs = insn[20:16];

    wire [4:0] rt;
    assign rt = insn[15:11];

    wire [31:0] reg_data0, reg_data1, alu_result;

    instruction_memory im(.addr(pc[7:0]), .data(insn));

    register_file rf(
        .read_reg0(rs), .read_reg1(rt), .write_reg(rd),
        .read_data0(reg_data0), .read_data1(reg_data1));

    alu alu(
        .data0(reg_data0), .data1(reg_data1),
        .control(`ALU_ADD),
        .result(alu_result));

    initial begin
        $monitor("time=%d pc=%x insn=%x rs=%x rt=%x reg_data0=%x reg_data1=%x",
            $time, pc, insn, rs, rt, reg_data0, reg_data1);
    end
endmodule

module test;
    reg clk;
    integer i;

    cpu cpu(clk);

    initial begin
        #100 clk <= 0;
        for (i = 0; i < 20; i++) begin
            #100 clk <= ~clk;
        end
    end
endmodule
