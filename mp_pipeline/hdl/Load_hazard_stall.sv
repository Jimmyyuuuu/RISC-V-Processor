module stall 
    import rv32i_types ::*;
    (
    input id_ex_stage_reg_t id_ex,   //id_ex_before

    input ex_mem_stage_reg_t ex_mem, // ex_mem_before
    output logic stall_signal
    );


    
    always_comb begin
    
        if((ex_mem.opcode == op_load) && (ex_mem.rd_s != 0) && (id_ex.rs1_s != 0)
        &&(id_ex.opcode == op_load || id_ex.opcode == op_store|| id_ex.opcode == op_imm || id_ex.opcode ==op_reg||id_ex.opcode ==op_br || id_ex.opcode ==op_auipc|| id_ex.opcode == op_jal || id_ex.opcode == op_jalr) 
        && (ex_mem.rd_s == id_ex.rs1_s)) 
        begin
            stall_signal = 1'b1;
        end
        else if ((ex_mem.opcode == op_load) && (ex_mem.rd_s != 0) && (id_ex.rs2_s != 0)
        &&(id_ex.opcode == op_load || id_ex.opcode == op_store|| id_ex.opcode == op_imm || id_ex.opcode ==op_reg||id_ex.opcode ==op_br||id_ex.opcode ==op_auipc||id_ex.opcode == op_jal || id_ex.opcode == op_jalr) 
        && (ex_mem.rd_s == id_ex.rs2_s)) 
        begin
            stall_signal = 1'b1;
        end

        else begin
            stall_signal = 1'b0;
        end
    end

endmodule 






























