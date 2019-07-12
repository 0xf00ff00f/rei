`include "cpu.v"

module test;
    reg clk;
    wire trap;
    integer i;

    cpu cpu(clk, trap);

    initial begin
        $readmemh("test_alu.hex", cpu.im.memory);
    end

    initial begin
        #100 clk <= 0;
        for (i = 0; i < 14*2; i++) begin
            #100 clk <= ~clk;
        end
    end

    initial begin
        $monitor("time=%0d pc=%x r0=%x r1=%x r2=%x cf=%x mem[0]=%x",
            $time,
            cpu.pc,
            cpu.rf.registers[0], cpu.rf.registers[1], cpu.rf.registers[2],
            cpu.carry_flag,
            cpu.mem.memory[0]);
    end
endmodule
