import sys
import re

re_code = re.compile(r'''
    ^
    (\w+:)?                     # optional label
    \s*
    (
     (\w+)                      # instruction
     \s+
     (\w+                       # register arg or label
      (\s*,\s*
       (
        (\w+(\s*,\s*\w+)*)|     # comma-separated args
        ([\d-]*\s*\(\s*\w+\s*\))   # indexed addr arg (for lw/sw)
       )
      )?
     )
    )?
    \s*
    (;.*)?                      # comment
    $
    ''', re.X)

re_indexed_addr = re.compile(r'([\d-]*)\s*\(\s*(\w+)\s*\)')

MEMORY_SIZE = 256

INSN_RRR    = 0
INSN_RR     = 1
INSN_RRI    = 2
INSN_RI     = 3
INSN_J      = 4
INSN_MEM    = 5
INSN_TRAP   = 6

opcodes = {
    'add':   (0x00, INSN_RRR),
    'addc':  (0x01, INSN_RRR),
    'sub':   (0x02, INSN_RRR),
    'subc':  (0x03, INSN_RRR),
    'and':   (0x04, INSN_RRR),
    'or':    (0x05, INSN_RRR),
    'xor':   (0x06, INSN_RRR),
    'nand':  (0x07, INSN_RRR),
    'shl':   (0x08, INSN_RRR),
    'shr':   (0x09, INSN_RRR),
    'cmp':   (0x0f, INSN_RR),

    'addi':  (0x10, INSN_RRI),
    'addic': (0x11, INSN_RRI),
    'subi':  (0x12, INSN_RRI),
    'subic': (0x13, INSN_RRI),
    'andi':  (0x14, INSN_RRI),
    'ori':   (0x15, INSN_RRI),
    'xori':  (0x16, INSN_RRI),
    'nandi': (0x17, INSN_RRI),
    'shli':  (0x18, INSN_RRI),
    'shri':  (0x19, INSN_RRI),
    'cmpi':  (0x1f, INSN_RI),

    'b':     (0x20, INSN_J),
    'bz':    (0x21, INSN_J),
    'bnz':   (0x22, INSN_J),
    'bc':    (0x23, INSN_J),
    'bnc':   (0x24, INSN_J),

    'lw':    (0x30, INSN_MEM),
    'sw':    (0x31, INSN_MEM),
    
    'trap':  (0xf0, INSN_TRAP),
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
            return (opcode << 24) | (rd << 20) | (rs << 16) | (rt << 12)
        elif insn_type == INSN_RR:
            if len(params) != 2:
                raise ParseError("invalid number of operands for %s" % insn)
            rs = self.parse_register(params[0])
            rt = self.parse_register(params[1])
            return (opcode << 24) | (rs << 16) | (rt << 12)
        elif insn_type == INSN_RRI:
            if len(params) != 3:
                raise ParseError("invalid number of operands for %s" % insn)
            rd = self.parse_register(params[0])
            rs = self.parse_register(params[1])
            imm = self.parse_immediate(params[2])
            return (opcode << 24) | (rd << 20) | (rs << 16) | (imm & 0xffff)
        elif insn_type == INSN_RRI:
            if len(params) != 2:
                raise ParseError("invalid number of operands for %s" % insn)
            rs = self.parse_register(params[0])
            imm = self.parse_immediate(params[1])
            return (opcode << 24) | (rs << 16) | (imm & 0xffff)
        elif insn_type == INSN_RI:
            if len(params) != 2:
                raise ParseError("invalid number of operands for %s" % insn)
            rs = self.parse_register(params[0])
            imm = self.parse_immediate(params[1])
            return (opcode << 24) | (rs << 16) | (imm & 0xffff)
        elif insn_type == INSN_J:
            if len(params) != 1:
                raise ParseError("invalid number of operands for %s" % insn)
            self.label_refs.append((params[0], len(self.memory)))
            return opcode << 24
        elif insn_type == INSN_MEM:
            if len(params) != 2:
                raise ParseError("invalid number of operands for %s" % insn)
            rd = self.parse_register(params[0])
            addr = self.parse_indexed_addr(params[1])
            return (opcode << 24) | (rd << 20) | (addr[1] << 16) | (addr[0] & 0xffff)
        elif insn_type == INSN_TRAP:
            if len(params) != 1:
                raise ParseError("invalid number of operands for %s" % insn)
            imm = self.parse_immediate(params[0])
            return (opcode << 24) | (imm & 0xffff)

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

    def parse_indexed_addr(self, addr):
        m = re_indexed_addr.match(addr)
        if not m:
            raise ParseError('expected indexed address')
        groups = m.groups()
        return (self.parse_immediate(groups[0]) if len(groups[0]) else 0, self.parse_register(groups[1]))

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
