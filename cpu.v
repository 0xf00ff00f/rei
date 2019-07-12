`define ALU_ADD     4'b0000
`define ALU_ADDC    4'b0001
`define ALU_SUB     4'b0010
`define ALU_SUBC    4'b0011
`define ALU_AND     4'b0100
`define ALU_OR      4'b0101
`define ALU_XOR     4'b0110
`define ALU_NAND    4'b0111
`define ALU_SHL     4'b1000
`define ALU_SHR     4'b1001

`define ALU_CMP     4'b1111

`define OP_ALU_RRR  4'b0000
`define OP_ALU_RRI  4'b0001
`define OP_J        4'b0010
`define OP_MEM      4'b0011
`define OP_TRAP     4'b1111

`define J_ALWAYS    4'b0000
`define J_Z         4'b0001
`define J_NZ        4'b0010
`define J_C         4'b0011
`define J_NC        4'b0100

module instruction_memory(addr, data);
    input [7:0] addr;
    output [31:0] data;

    reg [31:0] memory [0:255];

    assign data = memory[addr];
endmodule

module register_file(
            clk,
            read_reg0, read_reg1,
            write_reg, write_data, write_reg_enable,
            read_data0, read_data1);
    input clk;
    input [3:0] read_reg0, read_reg1, write_reg;
    input [31:0] write_data;
    input write_reg_enable;
    output [31:0] read_data0, read_data1;
    integer i;

    reg [31:0] registers [0:15];

    initial begin
        for (i = 0; i < 16; i++)
            registers[i] <= 0;
    end

    always @(posedge clk) begin
        if (write_reg_enable)
            registers[write_reg] <= write_data;
    end

    assign read_data0 = registers[read_reg0];
    assign read_data1 = registers[read_reg1];
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
    integer i;

    reg [31:0] memory [0:255];

    always @(posedge clk) begin
        if (write_enable) begin
            memory[addr] <= write_data;
        end
    end

    assign read_data = memory[addr];
endmodule

module alu(data0, data1, in_carry, control, carry, result);
    input [31:0] data0, data1;
    input in_carry;
    input [3:0] control;
    output reg carry;
    output reg [31:0] result;

    always @(*) begin
        case (control)
            `ALU_ADD:  {carry, result} <= {1'b0, data0} + {1'b0, data1};
            `ALU_ADDC: {carry, result} <= {1'b0, data0} + {1'b0, data1} + {32'b0, in_carry};
            `ALU_SUB:  {carry, result} <= {1'b0, data0} + {1'b0, ~data1} + 33'b1;
            `ALU_SUBC: {carry, result} <= {1'b0, data0} + {1'b0, ~data1} + {32'b0, in_carry};
            `ALU_AND:  begin carry <= 0; result <= data0 & data1; end
            `ALU_OR:   begin carry <= 0; result <= data0 | data1; end
            `ALU_XOR:  begin carry <= 0; result <= data0 ^ data1; end
            `ALU_NAND: begin carry <= 0; result <= ~(data0 & data1); end
            `ALU_SHL:  begin carry <= 0; result <= data0 << data1; end
            `ALU_SHR:  begin carry <= 0; result <= data0 >> data1; end
        endcase
    end
endmodule

module control(
            opcode,
            zero_flag,
            carry_flag,
            write_reg_enable,
            write_flags_enable,
            rd_or_rt_data1_select,
            mem_or_alu_write_reg_select,
            imm_or_reg_data1_select,
            branch_enable,
            write_mem_enable);
    input [7:0] opcode;
    input zero_flag;
    input carry_flag;
    output write_reg_enable;
    output write_flags_enable;
    output rd_or_rt_data1_select;
    output mem_or_alu_write_reg_select;
    output imm_or_reg_data1_select;
    output branch_enable;
    output write_mem_enable;

    wire [3:0] insn_type;
    assign insn_type = opcode[7:4];

    wire [3:0] insn_subtype;
    assign insn_subtype = opcode[3:0];

    wire insn_lw;
    assign insn_lw = insn_type == `OP_MEM && opcode[0] == 0;

    wire insn_sw;
    assign insn_sw = insn_type == `OP_MEM && opcode[0] == 1;

    assign write_reg_enable = ((insn_type == `OP_ALU_RRR || insn_type == `OP_ALU_RRI) && insn_subtype != `ALU_CMP) || insn_lw;
    assign write_flags_enable = insn_type == `OP_ALU_RRR || insn_type == `OP_ALU_RRI;
    assign rd_or_rt_data1_select = insn_sw;
    assign mem_or_alu_write_reg_select = insn_lw;
    assign imm_or_reg_data1_select = insn_type == `OP_ALU_RRI;
    assign branch_enable = insn_type == `OP_J &&
                           ((insn_subtype == `J_ALWAYS) ||
                            (insn_subtype == `J_Z && zero_flag) ||
                            (insn_subtype == `J_NZ && !zero_flag) ||
                            (insn_subtype == `J_C && carry_flag) ||
                            (insn_subtype == `J_NC && !carry_flag));
    assign write_mem_enable = insn_sw;
endmodule

module cpu(clk, trap);
    input clk;
    output reg trap;

    reg [31:0] pc;
    initial begin
        pc <= 0;
        trap <= 0;
    end

    reg carry_flag, zero_flag;
    initial begin
        carry_flag <= 0;
        zero_flag <= 0;
    end

    wire [31:0] pc1;
    assign pc1 = pc + 1;

    always @(posedge clk) begin
        pc <= branch_enable ? branch_target : pc1;
    end

    always @(posedge clk) begin
        if (write_flags_enable) begin
            carry_flag <= alu_carry;
            zero_flag <= alu_result == 0;
        end
    end

    always @(posedge clk) begin
        trap <= opcode[7:4] == `OP_TRAP;
    end

    wire [31:0] branch_target;
    assign branch_target = pc1 + {{16{imm[15]}}, imm};

    wire [31:0] insn;

    wire [7:0] opcode;
    assign opcode = insn[31:24];

    input [3:0] alu_control;
    assign alu_control = opcode[3:0] != `ALU_CMP ? opcode[3:0] : `ALU_SUB;

    wire [3:0] rd;
    assign rd = insn[23:20];

    wire [3:0] rs;
    assign rs = insn[19:16];

    wire [3:0] rt;
    assign rt = insn[15:12];

    wire [15:0] imm;
    assign imm = insn[15:0];

    wire branch_enable;

    wire write_reg_enable, write_flags_enable;

    wire [31:0] reg_data0, reg_data1, alu_result;
    wire alu_carry;

    wire imm_or_reg_data1_select;
    wire rd_or_rt_data0_select;
    wire mem_or_alu_write_reg_select;

    wire [3:0] read_reg1;
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

    control ctl(
        .opcode(opcode),
        .zero_flag(zero_flag),
        .carry_flag(carry_flag),
        .write_reg_enable(write_reg_enable),
        .write_flags_enable(write_flags_enable),
        .rd_or_rt_data1_select(rd_or_rt_data1_select),
        .mem_or_alu_write_reg_select(mem_or_alu_write_reg_select),
        .imm_or_reg_data1_select(imm_or_reg_data1_select),
        .branch_enable(branch_enable),
        .write_mem_enable(write_mem_enable));

    instruction_memory im(.addr(pc[7:0]), .data(insn));

    register_file rf(
        .clk(clk),
        .read_reg0(rs),
        .read_reg1(read_reg1),
        .write_reg(rd),
        .write_data(write_reg_data),
        .write_reg_enable(write_reg_enable),
        .read_data0(reg_data0),
        .read_data1(reg_data1));

    alu alu(
        .data0(reg_data0),
        .data1(alu_data1),
        .in_carry(carry_flag),
        .control(alu_control),
        .carry(alu_carry),
        .result(alu_result));

    data_memory mem(
        .clk(clk),
        .addr(mem_addr),
        .write_data(write_mem_data), .write_enable(write_mem_enable),
        .read_data(mem_data));
endmodule
