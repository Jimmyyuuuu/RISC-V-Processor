.section .text
.globl _start
_start:
    # Setup base addresses and data        # Reserve 32 bytes for testing
    # Setup base addresses and data
    la x5, base_address  # Assuming base_address is the starting point for our operations

    # Initialize registers with data, representative of core operations observed
    li x11, 0x60004374
    li x13, 0x00002424
    li x17, 0x6000444c
    li x16, 0x60004410
    li x29, 0x00000017
    li x31, 0x00000108

    # Perform memory operations
    # Storing words, halfwords, and bytes; loading them back to verify
    sw x13, 0(x5)       # Store word at base_address
    sh x13, 4(x5)       # Store halfword at base_address + 4
    sb x13, 6(x5)       # Store byte at base_address + 6

    lw x6, 0(x5)        # Load word from base_address into x6
    lh x7, 4(x5)        # Load halfword from base_address + 4 into x7
    lb x8, 6(x5)        # Load byte from base_address + 6 into x8

    # Branch operations to simulate control flow and modify execution based on data
    bne x7, x8, no_match # Branch if x7 is not equal to x8
    slti x0, x0, -256 

no_match:
    addi x13, x13, 1    # Increment x13, to modify and test write-back
    sw x13, 0(x5)       # Store back the modified word

    # More operations to cover branching and load/store combinations
    addi x17, x17, 1    # Another arithmetic operation to simulate changes
    sw x17, 8(x5)       # Store new data in a different memory location
    lw x9, 8(x5)        # Load the data back from this new location

    # Further conditional operations
    bne x9, x31, skip   # Branch if x9 is not equal to x31
    addi x9, x9, 1      # Modify x9 on condition
    sw x9, 8(x5)        # Store modified x9 back
    slti x0, x0, -256 

skip:
    slti x0, x0, -256 # this is the magic instruction to end the simulation
.section .data
.align 4
base_address:
.space 32           # Reserve 32 bytes for testing


