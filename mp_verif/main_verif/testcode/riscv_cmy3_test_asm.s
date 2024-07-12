riscv_basic_asm.s:
.align 4
.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    lw  x1, threshold 
    lui  x2, 2       # X2 <= 2
    lui  x3, 8     # X3 <= 8
    srli x2, x2, 12
    srli x3, x3, 12
    addi x4, x3, 4
    srai x5, x1, 2 #shift right arithmetic immediate (with sign)
    add x6, x2, x3
    sub x7, x3, x2

loop1:
    slli x3, x3, 1    # X3 <= X3 << 1
    xori x8, x2, 127  # X8 <= XOR (X2, 7b'1111111)
    addi x8, x8, 1    # X8 <= X8 + 1
    addi x7, x7, 4    # X7 <= X7 + 4
    bleu x7, x1, loop1   # Branch if last result was zero or positive.
    andi x6, x3, 64   # X6 <= X3 * 64
    or x9, x2, x3       # X9 <= X2 OR X3
    and x10, x2, x3     # X10 <= X2 AND X3
    sll x11, x2, x3     # X11 <= X2 << X3
    slt x12, x2, x3     # X12 <= 1 if X2 < X3，else == 0
    sltu x13, x2, x3    # X13 <= 1 if X2 < X3，else == 0 (for unsign)
    srl x14, x2, x3     # X14 <= X2 >> X3
    sra x15, x2, x3 

    slti x16, x2, 10    # X16 <= 1 if X2 < 10，else == 0 (sign)
    sltiu x17, x2, 10   # X17 <= 1 if X2 < 10，else == 0 (unsign)


#---------------------------for load store---------------------------------------
    auipc x19, 8         # X19 <= PC + 8
    lbu x20, good         # X20 <= 0x600d600d
    la x22, result      # X22 <= Addr[result]
    sb x20, 0(x22)       # [Result] <= 0x600d600d
    lbu x21, result       # X21 <= [Result]
    bne x20, x21, deadend # PC <= bad if x20 != x21
#-------------------------------Jump----------------------------------------

    # when you are writing your own testcase, include these 4 lines and the halt.
    li  t0, 1
    la  t1, tohost
    sw  t0, 0(t1)
    sw  x0, 4(t1)
halt:                 # Infinite loop to keep the processor
    beq x0, x0, halt  # from trying to execute the data below.
                      # Your own programs should also make use
                      # of an infinite loop at the end.

deadend:
    lw x8, bad     # X8 <= 0xdeadbeef
deadloop:
    beq x8, x8, deadloop

.section .rodata

bad:        .word 0xdeadbeef
threshold:  .word 0x00000040
result:     .word 0x00000000
good:       .word 0x600d600d

.section ".tohost"
.globl tohost
tohost: .dword 0
.section ".fromhost"
.globl fromhost
fromhost: .dword 0