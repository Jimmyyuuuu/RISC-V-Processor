module decode
    import rv32i_types::*;
    (   
        input logic clk,
        input logic rst,
        //from Instruction memory
        input logic [31:0]  imem_rdata_id,
        input logic stall_signal,
    
        //the value come from write back
        input logic [31:0] rd_v,
        input logic [4:0] rd_s_back,
        input logic regf_we_back,
        input logic freeze_stall,
        // pipeline registers
        input  if_id_stage_reg_t if_id,
        //all the imemory data signal pass to next stage using struct id_ex_stage_reg_t
        output id_ex_stage_reg_t id_ex,
        input logic flushing_inst

    );



    
    //control signal

    // alumux1_sel_t   alu_m1_sel;
    // alumux2_sel_t  alu_m2_sel;
    // alu_ops            alu_op;
    // cmpmux_sel_t      cmp_sel;
    // branch_funct3_t     cmpop;
    // register file write enable signal, need to send back to WB and then come back
    
    // ****************Combinational transfer to id/ex stage****************************
     // pc, valid, 

    assign id_ex.valid = (flushing_inst ? 1'b0:if_id.valid);


    //**********If the flushing_inst is one, then we need to flush the instr******
    logic [31:0] imem_rdata_id_delay ;
    always_ff@(posedge clk) begin
        if(rst) begin
            imem_rdata_id_delay <= 32'd0;
        end
        else if (freeze_stall | stall_signal)
            imem_rdata_id_delay <= imem_rdata_id_delay;
        else
            imem_rdata_id_delay <= imem_rdata_id;
    end
            
    assign id_ex.inst = (flushing_inst)|| (if_id.pc == 32'd0)? 32'h00000013: imem_rdata_id_delay;
    



    //from ir ,decode the instruction to multiple types , but consider the flushing 

    logic   [31:0]  data;
    always_comb begin
        data = id_ex.inst  ;
        
        if(flushing_inst) begin
            id_ex.funct3 = 3'd0;
            id_ex.funct7 = 7'd0;
            id_ex.opcode = 7'd0;
            id_ex.i_imm  = 32'd0;
            id_ex.s_imm  = 32'd0;
            id_ex.b_imm  = 32'd0;
            id_ex.u_imm  = 32'd0;
            id_ex.j_imm  = 32'd0;
            id_ex.rs1_s  = 5'd0;
            id_ex.rs2_s  = 5'd0;
            id_ex.rd_s   = 5'd0;
            
            
        end
        else begin
                id_ex.funct3 = data[14:12];
                id_ex.funct7 = data[31:25];
                id_ex.opcode = data[6:0];
                id_ex.i_imm  = {{21{data[31]}}, data[30:20]};
                id_ex.s_imm  = {{21{data[31]}}, data[30:25], data[11:7]};
                id_ex.b_imm  = {{20{data[31]}}, data[7], data[30:25], data[11:8], 1'b0};
                id_ex.u_imm  = {data[31:12], 12'h000};
                id_ex.j_imm  = {{12{data[31]}}, data[19:12], data[20], data[30:21], 1'b0};
                id_ex.rs1_s  = data[19:15];
                id_ex.rs2_s  = (id_ex.opcode == op_load) ? 5'b0 :data[24:20];
                id_ex.rd_s   = data[11:7];
        end
    end

assign  id_ex.pc = if_id.pc;


//***************register file**************************
regfile regfile(
        .clk(clk),
        .rst(rst),
        .rs1_s(id_ex.rs1_s),
        .rs2_s(id_ex.rs2_s),
        .rd_s(rd_s_back),//this is what you wanna write back, so we should use write back rd_s
        .rd_v(rd_v),//this is what you wanna write back value, from write back stage
        .rs1_v(id_ex.rs1_v),
        .rs2_v(id_ex.rs2_v),
        .regf_we(regf_we_back)//write enable 
    );
//***********************set control signal*************************


    // ****************alu_m1_sel************
    /*unique case(id_ex.alu_m1_sel) 
          1'b0 : a = forward_amux_out ;
          1'b1 : a = id_ex.pc;*/
    //skip load, store first
    always_comb begin
        unique case (id_ex.opcode) 
            op_auipc : id_ex.alu_m1_sel = 1'b1;
            op_imm   : id_ex.alu_m1_sel= 1'b0;
            op_reg   : id_ex.alu_m1_sel = 1'b0;
            op_lui   : id_ex.alu_m1_sel = 'x;
    // Branch, compare rs1_v and rs2_v and then if the branch is taken, then pc will add b_imm;
            op_br    : id_ex.alu_m1_sel = 1'b1;
    //Jump : offset is sign-extended and added to the pc to form the jump target address
            op_jal   : id_ex.alu_m1_sel = 1'b1;
            op_jalr  : id_ex.alu_m1_sel = 1'b0;
            op_load  : id_ex.alu_m1_sel = 'x;
            op_store : id_ex.alu_m1_sel = 'x;
            default : id_ex.alu_m1_sel = 1'b0;
        endcase
    end

    //*******************alu_m2_sel****************
    // set different operations to specific immediate value
    // but op_reg it don't need any immediate value

    always_comb begin
        unique case(id_ex.opcode) 
            op_lui : id_ex.imm_out = id_ex.u_imm;
            op_auipc : id_ex.imm_out = id_ex.u_imm;
            op_jal : id_ex.imm_out = id_ex.j_imm;
            op_jalr : id_ex.imm_out = id_ex.i_imm;
            op_br : id_ex.imm_out = id_ex.b_imm;
            op_load : id_ex.imm_out = id_ex.i_imm;
            op_store : id_ex.imm_out = id_ex.s_imm;
            op_imm : id_ex.imm_out = id_ex.i_imm;
            default : id_ex.imm_out = 32'd0;
        endcase
    end
        
    // alu_m2_sel = 0 will be rs2_out
    //alu_m2_sel = 1 will be imm_out
    //need to fix here
    always_comb begin
        //load : should send the address (rs1_v+i_imm) to data memory
        // store : should send the address (rs1_v + s_imm) to data memory
        if(id_ex.opcode inside {op_lui, op_auipc, op_jal, op_jalr, op_br, op_load, op_store}) begin
            id_ex.alu_m2_sel = 1;
        end
        else if ((id_ex.opcode == op_imm)&&(id_ex.funct3 inside {add, slt, sltu, axor, aor, aand, sll})) 
        begin
            id_ex.alu_m2_sel = 1;
        end
        else if ((id_ex.opcode == op_imm)&&(id_ex.alu_op inside{alu_srl, alu_sra}))
        begin
            id_ex.alu_m2_sel = 1;
        end
        else if ((id_ex.opcode == op_reg)&&(id_ex.alu_op inside{alu_srl, alu_sra}))
        begin
            id_ex.alu_m2_sel = 0;
        end
        else 
        // store and branch also use rs2
        // store : store (32/16/8) bits values from the low bits of register rs2 to memory
        /*branch :The 12-bit B-immeditae encodes signed offsets in multiple of 2 and is added to 
        the current PC to give the target address, take values from rs1 and rs2*/
        begin
            id_ex.alu_m2_sel = 0;
        end
    end



    //***************branch_funct3_t********
    always_comb begin
        if((id_ex.opcode inside{op_imm, op_reg})&& (id_ex.funct3 == slt )) begin
            id_ex.cmpop = blt ;
        end
        else if ((id_ex.opcode inside{op_imm, op_reg})&&(id_ex.funct3 == sltu)) begin
            id_ex.cmpop = bltu;
        end
        else if (id_ex.opcode == op_br) begin
            id_ex.cmpop = id_ex.funct3;
        end
        else
            id_ex.cmpop = 0;
    end
    //********************cmpmux****************
    always_comb begin
        if(id_ex.opcode == op_br) begin
            id_ex.cmp_sel = 1'b0;
        end
        else if((id_ex.opcode == op_imm) &&(id_ex.funct3 inside {slt, sltu}) )begin
            id_ex.cmp_sel = 1'b1;
        end
        else if ((id_ex.opcode == op_reg) && (id_ex.funct3 inside {slt, sltu}) )begin
            id_ex.cmp_sel = 1'b0;
        end
        else
            id_ex.cmp_sel = 1'b0;
    end


    //**********************aluop***********************************

    //lui places the U-immediate value in the top 20bits of the destination register rd, just use u_imm write back
    //********************** Judge new address for jump/br ******************
    always_comb begin
       if(id_ex.opcode inside{op_auipc, op_br, op_jal, op_jalr}) id_ex.alu_op = alu_add;
       else if (id_ex.opcode == op_imm) begin
            if(id_ex.funct3 == sr) id_ex.alu_op = (id_ex.funct7[5] ? alu_sra : alu_srl);
            else id_ex.alu_op = alu_ops'(id_ex.funct3);
       end
       else if (id_ex.opcode == op_reg) begin
            if(id_ex.funct3 == sr) id_ex.alu_op = (id_ex.funct7[5] ? alu_sra : alu_srl);
            else if (id_ex.funct3 == add) id_ex.alu_op = (id_ex.funct7[5] ? alu_sub : alu_add);
            else id_ex.alu_op = alu_ops'(id_ex.funct3);
       end
       else id_ex.alu_op = alu_ops'(id_ex.funct3);
    end
//**************************register file write enable*****************************
    always_comb begin
        if(id_ex.opcode inside {op_br, op_store}) begin
            id_ex.regf_we = 1'b0;
        end
        else
            id_ex.regf_we = 1'b1;
    end

//**************************register file mux signal******************************
    
    // br_en = {{31{1'b0}}, 1'b1}
    always_comb begin
        if(id_ex.opcode == op_br) begin
            id_ex.regfilemux_sel = 'x;
        end

        //jump
        else if(id_ex.opcode inside {op_jal, op_jalr}) begin
            id_ex.regfilemux_sel = 4'b0100;
        end
//**********************slt,sltu***********************************
        else if(id_ex.opcode == op_reg) begin
            if(id_ex.funct3 inside {slt, sltu}) begin
                id_ex.regfilemux_sel = 4'b0001;
            end
            else begin
                id_ex.regfilemux_sel = 4'b0000;
            end
        end

        else if(id_ex.opcode == op_imm) begin
            if(id_ex.funct3 inside {slt, sltu}) begin
                id_ex.regfilemux_sel = 4'b0001;
            end
            else begin
                id_ex.regfilemux_sel = 4'b0000;
            end
        end
//************************auipc, lui********************
        else if (id_ex.opcode == op_auipc) begin
            id_ex.regfilemux_sel = 4'b0000;
        end
        else if (id_ex.opcode == op_lui) begin
            id_ex.regfilemux_sel = 4'b0010;
        end
//*********************load***********************************
        else if (id_ex.opcode == op_load) begin
            if(id_ex.funct3 == lb) begin
                id_ex.regfilemux_sel = 4'b0101;
            end
            else if (id_ex.funct3 == lbu) begin
                id_ex.regfilemux_sel = 4'b0110;
            end
            else if (id_ex.funct3 == lh) begin
                id_ex.regfilemux_sel = 4'b0111;
            end
            else if (id_ex.funct3 == lhu) begin
                id_ex.regfilemux_sel = 4'b1000;
            end
            else id_ex.regfilemux_sel = 4'b0011;
        end
        else 
            id_ex.regfilemux_sel = 4'b0000;
    end

  



    endmodule 