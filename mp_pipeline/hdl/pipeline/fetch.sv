module fetch 
    import rv32i_types::*;

(
    input logic clk,
    input logic rst,
    //**********For branch and jump*************
    input logic br_en,
    input logic [31:0] branch_pc,
    output logic [31:0] imem_addr,
    output logic [3:0] imem_rmask,
    input logic stall_signal,
    //input logic imem_resp,
    input logic freeze_stall,
    output if_id_stage_reg_t  if_id_reg_before

);
    logic [31:0] pc;
    //read signal always 1
    assign imem_rmask = 4'b1111;
    always_ff@(posedge clk) begin
        if(rst) begin
            pc <= 32'h60000000;
        end
        else begin
             if(freeze_stall || stall_signal) begin
                pc <= pc;
             end
             else begin
                if(br_en) begin
                    pc <= branch_pc;
                end
                else
                    pc <= pc + 32'd4;
            end
        end
    end
//***************fixing the imem_resp and imem_address***********

    always_comb begin
        if(br_en) begin
            imem_addr = branch_pc;
        end
        else begin
            if(stall_signal || freeze_stall) begin
                imem_addr = pc;
            end
            else
                imem_addr = pc + 4;
        end
    end

//***********************send signal to next stage*******************
    assign if_id_reg_before.pc = pc;
    assign if_id_reg_before.valid = 1'b1;

   


endmodule

