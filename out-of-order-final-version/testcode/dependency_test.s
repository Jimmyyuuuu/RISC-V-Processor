dependency_test.s:
.align 4
.section .text
.globl _start
    # This program consists of small snippets
    # containing RAW, WAW, and WAR hazards

    # This test is NOT exhaustive
_start:

# initialize
li x1,  1           #
li x2,  2
li x3,  3
li x4,  4
li x5,  5
li x6,  6
li x7,  7
li x8,  8
li x9,  9
li x10, 5
li x11, 8
li x12, 4
li x13, 2           #0x00200693



nop
nop
nop
nop
nop

# RAW
mul x3, x1, x2      #0x022081b3     rds rob_entry 2
# add x5, x3, x4      #0x004182b3     busy 1 should be 1

# WAW
mul x6, x7, x8      #0x02838333
add x9, x6, x10     #0x00a48333     56 + 5 = e -> x6
add x5, x3, x4      #0x004182b3     2 + 4 = 6
# WAR
mul x11, x12, x13
add x13, x1, x11
add x12, x1, x11
# add x12, x1, x2
# slti x0,x0,-256

halt:
    slti x0, x0, -256
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
    # nop
                       