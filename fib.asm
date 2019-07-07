    xor r1,r1,r1    # r1 = 0
    ori r2,r0, 1    # r2 = 1
loop:
    add r3,r1,r2    # r3 = r1 + r2
    and r1,r2,r2    # r1 = r2
    or r2,r3,r3     # r2 = r3
    j loop
