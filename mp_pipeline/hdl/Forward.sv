
module forward 
    import rv32i_types ::*;
    import forward_amux::*;
    import forward_bmux::*;
    (
    input id_ex_stage_reg_t id_ex,
    input ex_mem_stage_reg_t ex_mem,
    input mem_wb_stage_reg_t mem_wb,

    //input logic flushing_inst,

    output forward_a_sel_t forward_a_sel,
    output forward_b_sel_t forward_b_sel

    //output logic stall_signal,
    //output logic stall_signal_pass
    
    
);
//*********************Hazard detect*******************************
/*always_comb begin
    if(ex_mem.opcode == op_load && id_ex.rs1_s != 5'b0 && ~stall_signal_pass && ~ flushing_inst 
        &&((id_ex.opcode inside {op_imm, op_reg, op_br, op_load, op_store}&& id_ex.rs1_s == ex_mem.rd_s) 
        || (id_ex.opcode inside {op_imm, op_reg, op_br, op_load, op_store}&& id_ex.rs2_s == ex_mem.rd_s)))

    begin
        stall_signal = 1'b1;
    end

    else
        stall_signal = 1'b0;
end

//***************************Avoid combinational loop*********************************************

always_ff@(posedge clk ) begin 
    if(rst) begin
        stall_signal_pass <= 1'b0;
    end
    // let stall_signal maintain only one cycle
    else if (stall_signal_pass) begin
        stall_signal_pass <= 1'b0;
    end
    else if (ex_mem.opcode == op_load && id_ex.rs1_s != 5'b0 && ~stall_signal_pass && ~ flushing_inst 
        &&((id_ex.opcode inside {op_imm, op_reg, op_br, op_load, op_store}&& id_ex.rs1_s == ex_mem.rd_s) 
        || (id_ex.opcode inside {op_imm, op_reg, op_br, op_load, op_store}&& id_ex.rs2_s == ex_mem.rd_s)))
    begin
        stall_signal_pass <= 1'b1;    
    end
    else
        stall_signal_pass <= 1'b0;
        
    end */

        
    


//*****************Forwarding logic *******************************
always_comb begin

    //**********rs1 forwarding logic
    if(id_ex.rs1_s == ex_mem.rd_s && id_ex.rs1_s != 5'b0 && ex_mem.regf_we == 1'b1 ) begin
         //u_imm(lui), auipc use the value from pc, so we don't need forwarding
        /*if(ex_mem.opcode == op_lui) 
            forward_a_sel = forward_amux::u_imm;*/

        // br_en (slt, sltu, slti, sltiu)
        if((ex_mem.opcode == op_reg || ex_mem.opcode == op_imm)&&
        (ex_mem.funct3 == slt || ex_mem.funct3 == sltu))
            forward_a_sel = forward_amux::br_en;
        else if ((ex_mem.opcode == op_lui)) 
            forward_a_sel = forward_amux::u_imm;
        
        //alu_out
        else 
            forward_a_sel = forward_amux::alu_out;
    end
//*****************id/ex and mem/wb compare
    else if (id_ex.rs1_s == mem_wb.rd_s && id_ex.rs1_s !=5'b0 && mem_wb.regf_we ==1'b1) 
        forward_a_sel = forward_amux::regfilemux_out;
    
    else 
        forward_a_sel = forward_amux::rs1_v;


    //*************rs2 forwarding logic
    
    if(id_ex.rs2_s == ex_mem.rd_s && id_ex.rs2_s != 5'b0 && ex_mem.regf_we == 1'b1 ) begin
        // u_imm (lui) auipc use the value from pc, so we don't need forwarding
        /*if (ex_mem.opcode == rv32i_types::op_lui)
            forward_b_sel = forward_bmux::u_imm;*/
        // br_en (slt, sltu, slti, sltiu)

        if((ex_mem.opcode == op_reg || ex_mem.opcode == op_imm)&&
        (ex_mem.funct3 == slt || ex_mem.funct3 == sltu)) begin
      
            forward_b_sel = forward_bmux::br_en;
        
        //alu_out
        end
        else if ((ex_mem.opcode == op_lui)) 
            forward_b_sel = forward_bmux::u_imm;
        else begin
            forward_b_sel = forward_bmux::alu_out;
        end
    end
    //*****************id/ex and mem/wb compare
    else if(id_ex.rs2_s == mem_wb.rd_s && id_ex.rs2_s != 5'b0 && mem_wb.regf_we == 1'b1) 
        forward_b_sel = forward_bmux::regfilemux_out;
    
    else 
        forward_b_sel = forward_bmux::rs2_v;
end
//*****************************************************************
endmodule




            
            