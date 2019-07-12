    ; sieve of eratosthenes

    ; sieve is a bit vector of 32 words (1024 bits)
    ; an unset bit means prime

    ; initialize sieve with zeroes

    xor r0,r0,r0
    xor r1,r1,r1
zero_mem:
    sw r1,(r0)
    addi r0,r0,1
    cmpi r0,32
    bnz zero_mem

    ; sieve loop

    xor r0,r0,r0
    ori r0,r0,2     ; r0 = 2

outer_loop:
    ; check if bit corresponding to r0 is not set

    shri r3,r0,5    ; r3 = r0/32
    lw r2,(r3)      ; r2 = sieve[r0/32]
    andi r3,r0,1fh  ; r3 = r0%32
    xor r4,r4,r4
    ori r4,r4,1
    shl r4,r4,r3    ; r4 = 1 << (r0%32)
    and r5,r2,r4    ; r5 = r2 & r4
    cmpi r5,0
    bnz not_prime

    ; r0 is prime!

    trap 0

    ; mark bits for multiples of r0

    or r1,r0,r0
inner_loop:
    shri r3,r1,5
    lw r2,(r3)
    andi r5,r1,1fh
    xor r4,r4,r4
    ori r4,r4,1
    shl r4,r4,r5
    or r2,r2,r4
    sw r2,(r3)
    add r1,r1,r0
    cmpi r1,200
    bnc inner_loop

not_prime:
    addi r0,r0,1
    cmpi r0,200
    bnc outer_loop

halt:
    b halt
