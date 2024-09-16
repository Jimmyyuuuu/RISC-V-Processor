
package rv32i_types;

    typedef enum logic [6:0] {
        op_lui   = 7'b0110111, // U load upper immediate 
        op_auipc = 7'b0010111, // U add upper immediate PC 
        op_jal   = 7'b1101111, // J jump and link 
        op_jalr  = 7'b1100111, // I jump and link register 
        op_br    = 7'b1100011, // B branch 
        op_load  = 7'b0000011, // I load 
        op_store = 7'b0100011, // S store 
        op_imm   = 7'b0010011, // I arith ops with register/immediate operands 
        op_reg   = 7'b0110011 // R arith ops with register operands 
        // op_csr   = 7'b1110011  // I control and status register 
    } rv32i_opcode;
   

    typedef enum bit [2:0] {
        alu_add = 3'b000,
        alu_sll = 3'b001,
        alu_sra = 3'b010,
        alu_sub = 3'b011,
        alu_xor = 3'b100,
        alu_srl = 3'b101,
        alu_or  = 3'b110,
        alu_and = 3'b111
    } alu_ops;

    typedef enum bit [2:0] {
        beq  = 3'b000,
        bne  = 3'b001,
        blt  = 3'b100,
        bge  = 3'b101,
        bltu = 3'b110,
        bgeu = 3'b111
    } branch_funct3_t;

    typedef enum bit [2:0] {
        lb  = 3'b000,
        lh  = 3'b001,
        lw  = 3'b010,
        lbu = 3'b100,
        lhu = 3'b101
    } load_funct3_t;
    
    typedef enum bit [2:0] {
        sb = 3'b000,
        sh = 3'b001,
        sw = 3'b010
    } store_funct3_t;

    typedef enum bit [2:0] {
        add  = 3'b000, //check bit30 for sub if op_reg opcode
        sll  = 3'b001,
        slt  = 3'b010,
        sltu = 3'b011,
        axor = 3'b100,
        sr   = 3'b101, //check bit30 for logical/arithmetic
        aor  = 3'b110,
        aand = 3'b111
    } arith_funct3_t;

    typedef enum logic [1:0] {
        mul = 2'b00,
        mulh= 2'b01,
        mulhsu = 2'b10,
        mulhu =  2'b11
    } mul_ops;

//******************* Our struct for RS, ROB..etc
    // Add more things here . . .
    typedef struct packed{
        logic [31:0] pc;
        logic [31:0] data;
    } iq_t;

    typedef struct packed{
	logic 	[3:0] 	tag;
    logic   [6:0]   opcode;
    logic [4:0] rds;
	logic 	[31:0] 	ROB_val;
    logic           commit;
    logic           br_en;
    logic    [31:0] br_target;
    } rob_t;

    typedef struct packed {
        logic	[31:0]	value;
	    logic	[3:0]	tag;
	    logic	busy;
    } reg_t;

    typedef struct packed {
    logic [6:0] opcode;
	//rs1 and rs2 are renamed to rob entry (i think)
    logic   [3:0]   rs1_rob;
    logic   [3:0]   rs2_rob;
	logic 			busy_1; // 1 if the r1 value is a tag, 0 if a constant value
	logic 			busy_2; // 1 if the r2 value is a tag, 0 if a constant value
	logic [31:0] 	r1_v; //rs1 or pc
	logic [31:0] 	r2_v; //rs2 or imm
    logic           taken;
    logic  [2:0]    aluop;
    logic  [2:0]    cmpop;
    logic  [1:0]    mulop;
    logic  [4:0]    rds;
    logic  [3:0]    rob_entry;
    logic  [31:0]   pc;
    logic  [31:0]   imm;
    logic  [2:0]    funct3;//18
    // logic           iq_re;
    } rs_t;
//output struct for regfile
    typedef struct packed {
        logic           r1_valid; //use by regfile
        logic           r2_valid; //use by regfile
        logic [31:0] 	r1_v; //rs1 or pc
	logic [31:0] 	r2_v; //rs2 or imm
    } reg_d;

    typedef struct packed{
        logic br_en; // for fetch stage
        logic [31:0] br_target;
        logic [31:0] value;
        logic	[3:0]	tag;
	    logic	valid;
    } cdb_t;
     typedef struct packed {
        logic valid;
        // logic order;
        logic [31:0]        inst; // Take from decode
        logic [4:0]     rs1_addr;
        logic [4:0]     rs2_addr;
        logic [31:0] 	r1_rdata; 
	    logic [31:0] 	r2_rdata;
        logic [4:0]      rd_addr;
        logic [31:0] 	rd_wdata;
        logic [31:0]    pc_rdata; //Take from decode
        logic [31:0]    pc_wdata; //Take from decode, TODO : now is pc_rdata +4
        logic [31:0]    dmem_addr; //data memory address
        logic [3:0]     dmem_rmask; //data memory rmask
        logic [3:0]     dmem_wmask; //data memory wmask
        logic [31:0]    dmem_rdata;
        logic [31:0]    dmem_wdata;    
    } rvfi_data;


 //new//////////////////////////////////////
    typedef struct packed {
        logic   [6:0]   opcode;
        logic   [3:0]   rs1_rob;
        logic   [3:0]   rs2_rob;
        logic 			busy_1; // 1 if the r1 value is a tag, 0 if a constant value
        logic 			busy_2; // 1 if the r2 value is a tag, 0 if a constant value
        logic   [31:0] 	r1_v; //rs1 or pc
        logic   [31:0] 	r2_v; //rs2 or imm
        logic           taken;
        logic   [4:0]   rds;
        logic   [3:0]   rob_entry;
        logic   [31:0]  dmem_addr;
        logic           dmem_value_valid;     // ~busy1 && ~busy2 && taken 
        logic   [31:0]  dmem_rdata; 
        logic   [31:0]  dmem_wdata; 
        logic           dmem_wdata_valid;    
        logic   [2:0]    funct3;//18
        logic   [31:0]   imm;
        
        logic [3:0]     dmem_rmask; //data memory rmask
        logic           dmem_rmask_valid;
        logic [3:0]     dmem_wmask; //data memory wmask
        logic           dmem_wmask_valid;
    } lsq_t;

    typedef struct packed {
        logic   [31:0]  pc;
        logic           taken;
        logic   [4:0]   gshare;
        
    } bp_t;
endpackage


//********************For Decoder & Decoder_reg**********************
package inst_types ;
    import rv32i_types::*;
    typedef struct packed {
        rv32i_types::rv32i_opcode opcode;
        logic [4:0] rs1;
        logic [4:0] rs2;
        logic [4:0] rd;
        logic [2:0] funct3;
        logic [6:0] funct7;
        logic [31:0] i_imm;
        logic [31:0] u_imm;
        logic [31:0] b_imm;
        logic [31:0] s_imm;
        logic [31:0] j_imm;
    } inst_t;
    
endpackage : inst_types

package ctrl_types;
    import rv32i_types::*;
    typedef struct packed {
        logic load_regfile;  //1
        rv32i_types::alu_ops aluop;  // 2
        rv32i_types::branch_funct3_t cmpop; //3
        rv32i_types::mul_ops mulop; //4
        logic rs1_valid; //5
        logic rs2_valid; //6
        logic [4:0] rd_s; // 7
        logic [31:0] imm; // 8
        logic [31:0] pc; // 9
        logic [4:0] rs1_s;// 10
        logic [4:0] rs2_s; // 11
        logic  [6:0]  opcode;//12
        logic mul_valid;//13
        logic alu_valid;//14
        logic cmp_valid;//15
        logic load_valid;//16
        logic store_valid; //17
        logic [2:0] funct3;//18
        logic iq_re;
    } rv32i_control_word;
endpackage : ctrl_types 

package cache_pkg;

typedef enum bit {
   wayhit =1'b0,
   waylru =1'b1
} way_mux_t;


typedef enum bit {
    cpu_data = 1'b0,
    mem_data = 1'b1
} data_mux_t;

typedef enum bit {
    write_miss = 1'b0, //addr_tag
    dirty_replace = 1'b1 //tag
} write_mux_t;

endpackage: cache_pkg

