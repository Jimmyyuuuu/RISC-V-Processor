.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 4  # x1 <= 4
    nop
    nop
    nop             # nops in between to prevent hazard
    nop
    nop
    addi x3, x1, 8  # x3 <= x1 + 8
    

    # Add your own test cases here!
    nop
    nop
    nop
    nop
    nop
    lui  x2, 2       # X2 <= 2

    nop
    nop
    nop
    nop
    nop
    auipc x7, 8         # X7 <= PC + 8

    nop
    nop
    nop
    nop
    nop
    slti x4, x1, 15     # Set x4 to 1 if x1 < 15, otherwise 0 (x2 = 1)

    nop
    nop
    nop
    nop
    nop
    sltiu x4, x1, 1


    nop
    nop
    nop
    nop
    nop
    addi x1, x0, 0x55  # x1 <= 4
    nop
    nop
    nop
    nop
    nop
    xori x4, x1, 0xAA

    
    nop
    nop
    nop
    nop
    nop
    ori x2, x1, 0xAA
    
    nop
    nop
    nop
    nop
    nop
    andi x2, x1, 0xAA

    nop
    nop
    nop
    nop
    nop
    slli x2, x1, 2

    nop
    nop
    nop
    nop
    nop
    srli x2, x1, 2

    nop
    nop
    nop
    nop
    nop
    addi x1, x0, -4  # x1 <= 4
    nop
    nop
    nop
    nop
    nop
    srai x2, x1, 2

    nop
    nop
    nop
    nop
    nop
    addi x1, x0, 2
    nop
    nop
    nop
    nop
    nop
    addi x2, x0, 7

    nop
    nop
    nop
    nop
    nop
    add x3, x1, x2

    nop
    nop
    nop
    nop
    nop
    sub x3, x1, x2

    nop
    nop
    nop
    nop
    nop
    sll x3, x2, x1

    nop
    nop
    nop
    nop
    nop
    slt x3, x2, x1

    nop
    nop
    nop
    nop
    nop
    addi x1, x0, -1
    nop
    nop
    nop
    nop
    nop
    sltu x3, x2, x1

    nop
    nop
    nop
    nop
    nop
    addi x1, x0, 0x55
    nop
    nop
    nop
    nop
    nop
    addi x2, x0, 0xAA
    nop
    nop
    nop
    nop
    nop
    xor x3, x1, x2

    nop
    nop
    nop
    nop
    nop
    and x3, x1, x2

    nop
    nop
    nop
    nop
    nop
    or x3, x1, x2

    nop
    nop
    nop
    nop
    nop
    addi x1, x0, 0x04
    nop
    nop
    nop
    nop
    nop
    addi x2, x0, 2
    nop
    nop
    nop
    nop
    nop
    srl x3, x1, x2

    nop
    nop
    nop
    nop
    nop
    addi x1, x0, -32
    nop
    nop
    nop
    nop
    nop
    sra x3, x1, x2

    



    slti x0, x0, -256 # this is the magic instruction to end the simulation