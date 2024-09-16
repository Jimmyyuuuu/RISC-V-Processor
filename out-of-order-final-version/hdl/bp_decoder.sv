module bp_decoder

    import inst_types::*;
    import rv32i_types::*;
(
    input logic clk,
    input logic rst,
input logic [31:0] instruction,
input logic [31:0] pc_late,
input logic mispredict,
input logic imem_resp,
output logic [31:0] pc_target_addr,
output logic valid,
output logic jump_valid1,
output logic jump_valid2
);

//  inst_types::inst_t data;
logic   [31:0]  tmp_pc;
logic flag_yu;

always_ff @(posedge clk) begin

    if (rst)
    flag_yu <= '0;
    else if (mispredict)
    flag_yu <= '1;
    else if (imem_resp)
    flag_yu <= '0;
    else 
    flag_yu <= flag_yu;
end

 logic [31:0] j_imm;
 logic [31:0] b_imm, u_imm, i_imm;
 rv32i_types::rv32i_opcode  opcode;

 assign opcode = rv32i_opcode'(instruction[6:0]);
 assign b_imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
 assign j_imm  = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
 assign u_imm =  {instruction[31:12], 12'h000};
 assign i_imm =  {{21{instruction[31]}}, instruction[30:20]};

always_ff @( posedge clk ) begin 
    if (rst) tmp_pc <= '0;
    else if (opcode == op_auipc) tmp_pc <=   pc_late + u_imm;
    else tmp_pc <= tmp_pc;
end


always_comb begin

pc_target_addr = '0;
valid = '0;
jump_valid1 = '0;
jump_valid2 = '0;
case (opcode)
    op_jal:begin
    pc_target_addr = pc_late + j_imm;
    valid= !flag_yu ? '1 : '0;
    jump_valid1 =!flag_yu ? '1 : '0;
    end


    op_jalr:begin
    pc_target_addr = (tmp_pc + i_imm) & 32'hfffffffe;;
    valid= !flag_yu ? '1 : '0;
    jump_valid2 = !flag_yu ? '1 : '0;
    end


    op_br:begin
    pc_target_addr = pc_late + b_imm;
    valid= !flag_yu ? '1 : '0;
    end 

    default: begin 
    pc_target_addr = '0;
    valid = '0;
    jump_valid1 = '0;
    end 
endcase
end 



endmodule 
