`include "cpu.v"

module test;
    reg clk;
    wire trap;
    integer i;

    cpu cpu(.clk(clk), .trap(trap));

    initial begin
        $readmemh("sieve.hex", cpu.im.memory);
    end

    always @(posedge trap) begin
        $display("%0d", cpu.rf.registers[0]);
    end

    initial begin
        #100 clk <= 0;
        for (i = 0; i < 50000; i++) begin
            #100 clk <= ~clk;
        end
    end
endmodule
