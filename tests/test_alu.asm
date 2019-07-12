    ; test some basic ALU instructions

    ori r0,r0,18
    subi r0,r0,1        ; r0=17, cf=1

    nand r0,r0,r0       ; r0 = ~17, cf=0
    add r0,r0,r0        ; cf=1

    addc r1,r1,r1       ; r1=1

    xor r0,r0,r0
    ori r0,r0,deadh
    shli r0,r0,16
    ori r0,r0,beefh     ; r0 = deadbeefh

    xor r2,r2,r2
    ori r2,r2,13
    sw r0,-13(r2)       ; mem[0] = deadbeefh

    subi r2,r2,13
    lw r1,(r2)          ; r1 = deadbeefh
