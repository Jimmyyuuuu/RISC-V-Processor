module memory
    import rv32i_types::*;
(
    input ex_mem_stage_reg_t ex_mem,

    input mem_wb_stage_reg_t mem_wb_now,
    input logic freeze_stall,
    output mem_wb_stage_reg_t mem_wb,

    output logic   [31:0]       dmem_addr,
    output logic   [3:0]       dmem_rmask,
    output logic   [3:0]       dmem_wmask,
    output logic   [31:0]      dmem_wdata,
    
    
    //****************branch instruction**********************
    output logic          br_en_out,
    output logic   [31:0] branch_new_address,
    output logic flushing_inst,
    //************forward*****************
    output logic   mem_wb_br_en,
    output logic   [31:0] mem_wb_alu_out,
    output logic   [31:0] mem_wb_u_imm

);


    assign mem_wb_alu_out = ex_mem.alu_out;
    assign mem_wb_br_en = ex_mem.br_en;
    assign mem_wb_u_imm = ex_mem.u_imm;
    

   
//*******************************load*******************************
    always_comb begin
        mem_wb.dmem_rmask = 4'b000;
        mem_wb.dmem_addr = 32'd0;
        mem_wb.dmem_wmask = 4'b000;
        mem_wb.dmem_wdata = 32'd0;
        if(ex_mem.opcode == op_load) begin
            mem_wb.dmem_addr = ex_mem.rs1_v + ex_mem.i_imm;
            mem_wb.dmem_wdata = 32'd0;
            unique case (ex_mem.funct3)
                lb, lbu: mem_wb.dmem_rmask = 4'b0001 << mem_wb.dmem_addr[1:0];
                lh, lhu: mem_wb.dmem_rmask = 4'b0011 << mem_wb.dmem_addr[1:0];
                lw:      mem_wb.dmem_rmask = 4'b1111;
                default: mem_wb.dmem_rmask = 4'b0000;
            endcase
        end
        else if(ex_mem.opcode == op_store) begin
            mem_wb.dmem_addr = ex_mem.rs1_v + ex_mem.s_imm;
            unique case (ex_mem.funct3)
                sb: mem_wb.dmem_wmask = 4'b0001 << mem_wb.dmem_addr[1:0];
                sh: mem_wb.dmem_wmask = 4'b0011 << mem_wb.dmem_addr[1:0];
                sw: mem_wb.dmem_wmask = 4'b1111;
                default: mem_wb.dmem_wmask = 4'b0000;
            endcase
            unique case (ex_mem.funct3)
                sb: mem_wb.dmem_wdata[8 *mem_wb.dmem_addr[1:0] +: 8 ] = ex_mem.rs2_v[7 :0];
                sh: mem_wb.dmem_wdata[16*mem_wb.dmem_addr[1]   +: 16] = ex_mem.rs2_v[15:0];
                sw: mem_wb.dmem_wdata = ex_mem.rs2_v;
                default: mem_wb.dmem_wdata = 4'b0000;
            endcase
        end
    end
    // output signal to data memory
     // store, load : you don't need to align memory address to set the signal for mask, but you have to align the address, if you want to store something in memory, 
    // or load something from memory


    always_comb begin
        if(freeze_stall) begin
            dmem_addr = mem_wb_now.dmem_addr& 32'hfffffffc;
            dmem_rmask = mem_wb_now.dmem_rmask;
            dmem_wmask = mem_wb_now.dmem_wmask;
            dmem_wdata = mem_wb_now.dmem_wdata;
        end
        else begin
            dmem_addr = mem_wb.dmem_addr & 32'hfffffffc;
            dmem_rmask = mem_wb.dmem_rmask;
            dmem_wmask = mem_wb.dmem_wmask;
            dmem_wdata = mem_wb.dmem_wdata;
        end
    end


    //assign dmem_addr = mem_wb.dmem_addr & 32'hfffffffc;
    //assign dmem_wdata = mem_wb.dmem_wdata;
    //assign dmem_rmask = mem_wb.dmem_rmask;
    //assign dmem_wmask = mem_wb.dmem_wmask;





//*********************br_en_out***********************************************
    // fetch PCmuxselect signal
    //if br_en == 1'b0, means the branch is not taken
    always_comb begin
        if(ex_mem.opcode inside {op_jal, op_jalr})
            br_en_out = 1'b1;
        else if ((ex_mem.opcode == op_br) && (ex_mem.br_en == 1'b1))
            br_en_out = 1'b1;
        else
            br_en_out = 1'b0;
      end
//***********************branch new target****************************
    always_comb begin
        if(ex_mem.opcode inside {op_jal, op_jalr})
            branch_new_address = ex_mem.alu_out & 32'hfffffffe;
        else if ((ex_mem.opcode == op_br) && (ex_mem.br_en == 1'b1))
            branch_new_address = ex_mem.alu_out;
        else
            branch_new_address = 32'd0;

    end

    always_comb begin
        if(ex_mem.opcode inside {op_jal, op_jalr})
            flushing_inst = 1'b1;
        else if ((ex_mem.opcode == op_br) && (ex_mem.br_en == 1'b1))
            flushing_inst = 1'b1;
        else
            flushing_inst = 1'b0;
    end

    always_comb begin
        if(ex_mem.opcode inside {op_br, op_store}) begin
            mem_wb.rd_s = 5'b0;
        end
        else
            mem_wb.rd_s = ex_mem.rd_s;
    end

//*********************send signal to write back**********************
    assign mem_wb.inst  =  ex_mem.inst;
    assign mem_wb.pc    =     ex_mem.pc;
    assign mem_wb.valid =  ex_mem.valid;
    
    
    // send these signal to write back
    //assign mem_wb.rd_s = ex_mem.rd_s;
    assign mem_wb.rs1_s = ex_mem.rs1_s;
    assign mem_wb.rs2_s = ex_mem.rs2_s;
    assign mem_wb.rs1_v = ex_mem.rs1_v;
    assign mem_wb.rs2_v = ex_mem.rs2_v;
    // control signal & for write back mux
    assign mem_wb.u_imm = ex_mem.u_imm;
    assign mem_wb.b_imm = ex_mem.b_imm;
    assign mem_wb.j_imm = ex_mem.j_imm;
    assign mem_wb.i_imm = ex_mem.i_imm;
    assign mem_wb.br_en = ex_mem.br_en;
    assign mem_wb.alu_out = ex_mem.alu_out;
    assign mem_wb.regf_we = ex_mem.regf_we;
    assign mem_wb.regfilemux_sel = ex_mem.regfilemux_sel;
    //assign mem_wb.dmem_write = ex_mem.dmem_write;
    //assign mem_wb.dmem_read = ex_mem.dmem_read;
            
    
    assign mem_wb.opcode = ex_mem.opcode;
        
        






endmodule 