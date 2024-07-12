.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 4  # x1 <= 4
    addi x3, x1, 8  # x3 <= x1 + 8

    auipc x15, 0
    # test store

    sw x3, 0(x15)    # using x5 for access 0x60000000

    sh x3, 4(x15)

    sb x3, 6(x15)
    # Load values

    lw x14, 0(x15)

    lh x8, 4(x15)

    lb x9, 6(x15)

    lhu x12, 4(x15)

    lbu x13, 6(x15)


    slti x0, x0, -256 # this is the magic instruction to end the simulation
