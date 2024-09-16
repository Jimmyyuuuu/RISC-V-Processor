.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    # addi x1, x0, 4  # x1 <= 4
    # addi x3, x1, 8  # x3 <= x1 + 8




    # Add your own test cases here!
    addi x1, x0, 4  # x1 <= 4                               0x00400093
  
    addi x3, x1, 8  # x3 <= c                                0x00808193

    # Add your own test cases here!
    
    auipc x15, 0        #x15 <= 6000_0008                  #0x00000797
    # test store

    sw x3, 0(x15)    # mem[6000_0008] <= c                 0x0037a023 

    sh x3, 4(x15)     #mem[6000_000c] <= c                  0x00379223                              #0x00379223

    sb x3, 0(x15)           #mem[6000_000c] <= 0x000c0000            wmask=4   0x00378323
    
    sub  x2, x1, x3         #x2 = x1 - x3                   0x40308133        

    lw x9, 0(x15)          #x9 <= c  (mem[x15+6])               0x00678483
    addi x1, x0, 4  # x1 <= 4                               0x00400093
    addi x1, x0, 4  # x1 <= 4                               0x00400093
    addi x1, x0, 4  # x1 <= 4                               0x00400093
    lb x9, 6(x15)          #x9 <= c  (mem[x15+6])               0x00678483
    lh x9, 6(x15)           #0x00679483
    lw x9, 4(x15)           #0x0067a483
    lbu x9, 6(x15)          #0x0067c483
    lhu x9, 6(x15)          #0x0067d483

    and  x12, x9, x5                    #0x00517633        x12 = x2 and x5


    slti x0, x0, -256 # this is the magic instruction to end the simulation