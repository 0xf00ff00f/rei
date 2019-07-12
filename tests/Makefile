ROOT=..

all: test_alu.vvp test_alu.hex sieve.vvp sieve.hex

%.vvp: %.v
	iverilog -I$(ROOT) $< -o$@

%.hex: %.asm
	python $(ROOT)/assembler.py $< $@

clean:
	rm -f *.vvp *.hex
