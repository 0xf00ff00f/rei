import sys
import re

re_code = re.compile('^(\w+:)?\s*((\w+)\s+(\w+(\s*,\s*\w+)*))?\s*(#.*)?$')

MEMORY_SIZE = 256

INSN_RRR = 0
INSN_RRI = 1
INSN_J = 2

opcodes = {
    'add':   (0x00, INSN_RRR),
    'sub':   (0x01, INSN_RRR),
    'and':   (0x02, INSN_RRR),
    'or':    (0x03, INSN_RRR),
    'xor':   (0x04, INSN_RRR),
    'nand':  (0x05, INSN_RRR),
    'shl':   (0x06, INSN_RRR),
    'shr':   (0x07, INSN_RRR),
    'addi':  (0x08, INSN_RRI),
    'subi':  (0x09, INSN_RRI),
    'andi':  (0x0a, INSN_RRI),
    'ori':   (0x0b, INSN_RRI),
    'xori':  (0x0c, INSN_RRI),
    'nandi': (0x0d, INSN_RRI),
    'shli':  (0x0e, INSN_RRI),
    'shri':  (0x0f, INSN_RRI),
    'j':     (0x10, INSN_J),
}

class ParseError(Exception):
    pass

class Assembler:
    def __init__(self):
        self.labels = {}
        self.label_refs = []
        self.memory = []

    def assemble(self, infile):
        with open(infile) as f:
            for lineno, line in enumerate(f):
                m = re_code.match(line.strip())
                if not m:
                    raise ParseError('syntax error in line %d' % (lineno + 1))
                groups = m.groups()
                label, code = groups[0:2]
                if label is not None:
                    self.labels[label[:-1]] = len(self.memory)
                if code is not None:
                    insn = groups[2]
                    params = [x.strip() for x in groups[3].split(',')]
                    try:
                        self.memory.append(self.assemble_insn(insn, params))
                    except ParseError, e:
                        raise ParseError('in line %d: %s' % (lineno + 1, e.message))
        # fix label references
        for label, addr in self.label_refs:
            if label not in self.labels:
                raise ParseError("undefined label `%s'" % label)
            self.memory[addr] |= (self.labels[label] - (addr + 1)) & 0xffff

    def assemble_insn(self, insn, params):
        if insn not in opcodes:
            raise ParseError("unrecognized instruction `%s'" % insn)
        opcode, insn_type = opcodes[insn]
        if insn_type == INSN_RRR:
            if len(params) != 3:
                raise ParseError("invalid number of operands for %s" % insn)
            rd = self.parse_register(params[0])
            rs = self.parse_register(params[1])
            rt = self.parse_register(params[2])
            return (opcode << 26) | (rd << 21) | (rs << 16) | (rt << 11)
        elif insn_type == INSN_RRI:
            if len(params) != 3:
                raise ParseError("invalid number of operands for %s" % insn)
            rd = self.parse_register(params[0])
            rs = self.parse_register(params[1])
            imm = self.parse_immediate(params[2])
            return (opcode << 26) | (rd << 21) | (rs << 16) | (imm & 0xffff)
        elif insn_type == INSN_J:
            if len(params) != 1:
                raise ParseError("invalid number of operands for %s" % insn)
            self.label_refs.append((params[0], len(self.memory)))
            return opcode << 26

    def parse_register(self, reg):
        if reg[0] != 'r':
            raise ParseError('invalid register')
        try:
            return int(reg[1:])
        except ValueError:
            raise ParseError('invalid register')

    def parse_immediate(self, imm):
        try:
            if imm[-1] == 'h':
                return int(imm[:-1], 16)
            elif imm[-1] == 'b':
                return int(imm[:-1], 2)
            else:
                return int(imm)
        except ValueError:
            raise ParseError('invalid immediate')

def main(argv):
    if len(argv) != 3:
        print 'Usage: python assemble.py <asm file> <memory file>'
        return 1

    a = Assembler()

    try:
        a.assemble(argv[1])
    except ParseError, e:
        print 'Parse error: %s' % e.message
        return 1

    with open(argv[2], 'w') as f:
        for code in a.memory:
            f.write('%08x\n' % code)
        if len(a.memory) < MEMORY_SIZE:
            for i in range(MEMORY_SIZE - len(a.memory)):
                f.write('%08x\n' % 0)

    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
