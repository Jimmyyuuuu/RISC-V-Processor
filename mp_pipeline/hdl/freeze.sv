module freeze
    import rv32i_types::*;
    import forward_amux::*;
    import forward_bmux::*;
    (
    input mem_wb_stage_reg_t mem_wb,
    input logic imem_resp,
    input logic dmem_resp,
    output logic freeze_stall

);

 //if one of it resp is 0, then stall the whole pipeline

always_comb begin
    if((~imem_resp) || ((~dmem_resp)&& mem_wb.opcode == op_load) 
    ||((~dmem_resp)&& mem_wb.opcode == op_store)) begin
        freeze_stall = 1'b1;
    end
    else 
        freeze_stall = 1'b0;
end

endmodule
    
    

