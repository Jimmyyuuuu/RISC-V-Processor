
module control_rom 
    import rv32i_types::*;
    import inst_types::*;
    import ctrl_types::*;
        (
        input logic [31:0] pc,
        input inst_types::inst_t instr,
        input rvfi_data rvfi_in,
        output rvfi_data rvfi_out,
        /* ... other inputs ... */
        output ctrl_types::rv32i_control_word ctrl
      );
    always_comb begin 
        rvfi_out = rvfi_in;
        rvfi_out.rs2_addr = ctrl.rs2_valid ? rvfi_in.rs2_addr : '0;
        rvfi_out.rs1_addr = ctrl.rs1_valid ? rvfi_in.rs1_addr : '0;
    end  
    
    // assign rvfi_out = rvfi_in;
    assign ctrl.rd_s = instr.rd; //7
    always_comb begin
        ctrl.load_regfile = 1'b0;   //1
        ctrl.aluop = rv32i_types::alu_add; //2
        ctrl.cmpop = rv32i_types::beq; // 3
        ctrl.mulop = rv32i_types::mul; // 4 
        ctrl.rs1_valid = 1'b1; //5 high = rs1, low = pc
        ctrl.rs2_valid = 1'b0; //6
        // ctrl.rd_s = instr.rd; //7
        ctrl.imm = instr.i_imm; //8
        ctrl.pc  = pc;//9
        ctrl.rs1_s = instr.rs1; //10 
        ctrl.rs2_s = instr.rs2; // 11
        ctrl.opcode = instr.opcode; //12
        ctrl.mul_valid = '0; //13
        ctrl.alu_valid = '1; //14
        ctrl.cmp_valid = '0;//15
        ctrl.load_valid = '0; //16
        ctrl.store_valid = '0; // 17
        ctrl.funct3 = instr.funct3; //18
    
        case(instr.opcode)
             // use alu invalid or modify in rs?????????????????
            op_lui: begin
                ctrl.load_regfile = 1'b1;
                //ctrl.regfilemux_sel = regfilemux::u_imm; 
                ctrl.imm = instr.u_imm;
                ctrl.rs1_valid = 1'b0;//?????
            end
    
            op_auipc: begin
                ctrl.load_regfile = 1'b1;
                ctrl.rs1_valid = 1'b0; // use pc
                //ctrl.alumux1_sel = alumux::pc_out;//有问题11111111111111111111111111111111111
                //ctrl.alumux2_sel = alumux::u_imm;
                ctrl.imm = instr.u_imm;
            end
    
            op_jal: begin
                ctrl.cmp_valid =1'b1;
                ctrl.alu_valid =1'b0;
                ctrl.load_regfile = 1'b1;
                //ctrl.regfilemux_sel = regfilemux::pc_plus4; ///////////
                //ctrl.alumux1_sel = alumux::pc_out;
                ctrl.rs1_valid = 1'b0;
                //ctrl.alumux2_sel = alumux::j_imm;
                ctrl.imm = instr.j_imm;
            end
    
            op_jalr: begin
                ctrl.load_regfile = 1'b1;
                ctrl.cmp_valid =1'b1;
                ctrl.alu_valid =1'b0;
                ctrl.imm = instr.i_imm;
                //ctrl.regfilemux_sel = regfilemux::pc_plus4; //////////
                //ctrl.alumux1_sel = alumux::rs1_out;
                //ctrl.alumux2_sel = alumux::i_imm;              
            end
           
            // use rs1 and rs2 to compare 
            op_br: begin //全都要选11111111111111111111111111111111111111111111111111111111111111111111111111
                //ctrl.alumux1_sel = alumux::pc_out;
               // ctrl.rs1_valid =1'b0;
                //ctrl.alumux2_sel = alumux::b_imm;
                ctrl.imm = instr.b_imm;
                ctrl.aluop = rv32i_types::alu_add; //一个在选
                ctrl.cmp_valid =1'b1;
                ctrl.alu_valid =1'b0;
                ctrl.cmpop = branch_funct3_t'(instr.funct3); //一个根据实际情况在赋值
                ctrl.rs2_valid = 1'b1;//nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn难点
            end
            
            op_load: begin
                ctrl.alu_valid = 1'b0;
                ctrl.load_valid =1'b1;
                ctrl.load_regfile = 1'b1;
                // ctrl.dmem_read = 1'b1;
            // ctrl.regfilemux_sel = regfilemux::rdata;
            end
            
            op_store: begin
    
            //    ctrl.dmem_write = 1'b1;
               //ctrl.alumux2_sel = alumux::s_imm;
               ctrl.alu_valid = 1'b0;
               ctrl.imm = instr.s_imm;
               ctrl.rs2_valid = 1'b1;
               ctrl.store_valid =1'b1;
            end
    
            op_imm: begin
            
            if (instr.funct3 == rv32i_types::slt) begin
                ctrl.load_regfile = 1'b1;
               // ctrl.regfilemux_sel = regfilemux::br_en;
               // ctrl.cmpmux_sel = cmpmux::i_imm;//重点1111111111111111111111111111111111111111111111111111111
                ctrl.cmpop = rv32i_types::blt;
                ctrl.cmp_valid = 1'b1; 
                ctrl.alu_valid =1'b0;
            end 
            else if (instr.funct3 == rv32i_types::sltu) begin
                ctrl.load_regfile = 1'b1;
               // ctrl.regfilemux_sel = regfilemux::br_en;
               // ctrl.cmpmux_sel = cmpmux::i_imm;
                ctrl.cmpop = rv32i_types::bltu;
                ctrl.cmp_valid = 1'b1;
                ctrl.alu_valid =1'b0;
            end
            else if (instr.funct3 == rv32i_types::sr ) begin
                ctrl.load_regfile = 1'b1;
                if (instr.funct7[5]) 
                 ctrl.aluop = rv32i_types::alu_sra;
                else 
                 ctrl.aluop = rv32i_types::alu_srl;
            end
            else begin 
                ctrl.load_regfile = 1'b1;
                ctrl.aluop = alu_ops'(instr.funct3);
            end
            end
    
            op_reg: begin
                ctrl.load_regfile = 1'b1;
                //ctrl.alumux2_sel = alumux::rs2_out;
                ctrl.rs2_valid =1'b1; 
             if (instr.funct7[0] == 1'b1) begin 
                ctrl.mul_valid =1'b1;
                ctrl.alu_valid =1'b0;
                if (instr.funct3 == 3'b001)
                ctrl.mulop = rv32i_types::mulh;
                else if (instr.funct3 == 3'b010) 
                ctrl.mulop = rv32i_types::mulhsu;
                else if (instr.funct3 == 3'b011)
                ctrl.mulop = rv32i_types::mulhu;
                else 
                ctrl.mulop = rv32i_types::mul;
             end 
             
             else  begin 
             if (instr.funct3 == rv32i_types::slt) begin
               // ctrl.regfilemux_sel = regfilemux::br_en;
                ctrl.cmpop = rv32i_types::blt;
                ctrl.cmp_valid =1'b1;
                ctrl.alu_valid =1'b0;
             end
            else if (instr.funct3 == rv32i_types::sltu) begin
               // ctrl.regfilemux_sel = regfilemux::br_en;
                ctrl.cmpop = rv32i_types::bltu;
                ctrl.cmp_valid = 1'b1;
                ctrl.alu_valid =1'b0;
            end
            else if (instr.funct3 == rv32i_types::sr) begin
                 if(instr.funct7[5])
                  ctrl.aluop = rv32i_types::alu_sra;
                 else
                  ctrl.aluop = rv32i_types::alu_srl;
            end
            else if (instr.funct3 == rv32i_types::add) begin
                 if(instr.funct7[5])
                 ctrl.aluop = rv32i_types::alu_sub;
                 else 
                 ctrl.aluop = rv32i_types::alu_add;
            end
            else begin
                ctrl.aluop = alu_ops'(instr.funct3);
            end
        end
    end 
            endcase
    end
    endmodule