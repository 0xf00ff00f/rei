# rei

Verilog code and assembler for a very simple 32-bit CPU.

To keep things as simple as possible, all instructions execute in one cycle, code and data memory are separate,
and of course there's no pipelining. I'm not even sure this is synthesizable.

To see it in action, install Icarus Verilog, then do:

    cd tests
    make
    vvp sieve.vvp

This should display prime numbers up to 200.
