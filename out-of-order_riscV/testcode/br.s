.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 4  # x1 <= 4 
    addi x2, x0, 4  # x2 <= 4
    addi x3, x0, 8  # x3 <= 8 0x00800193
    jal x7, subroutine # Jump to subroutine, link address in x7
    addi x8, x0, 100  # x8 <= 100
    beq x1, x2, label_equal    # Branch if x1 == x2, should branch
    beq x1, x3, label_not_equal # Branch if x1 == x3, should not branch
    slti x0, x0, -256 # this is the magic instruction to end the simulation

label_equal:
    # This code is executed if x1 == x2
    addi x7, x0, 207  # x7 <= 207
    slti x0, x0, -256 # this is the magic instruction to end the simulation

label_not_equal:
    # Continue execution here if x1 != x3
    addi x7, x0, 206  # x7 <= 206
    slti x0, x0, -256 # this is the magic instruction to end the simulation

subroutine:
    # Subroutine code here
    addi x9, x0, 90  # x9 <= 90
    jalr x15, x7, 0  # Return to the address in x7
