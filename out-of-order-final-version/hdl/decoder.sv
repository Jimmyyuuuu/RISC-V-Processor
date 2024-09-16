
module decoder 
    import rv32i_types::*;
    import inst_types::*;
    import ctrl_types::*;
    
    (
      input logic if_rd,
      input [31:0] pc,
      // input rst,
      input logic [31:0] instruction,
      output inst_types::inst_t id_inst,
      output logic [31:0] id_pc,
      output rvfi_data rvfi
    //   output logic valid
    );
    
    logic [31:0] data;
    
    
    // always_comb begin
    //     data = 32'b0;b1
    //     valid = '0;
    // if(if_rd) begin
    //    data = instruction;
    //    valid ='1;
    //   end
    // end
    always_comb begin
        if (if_rd) begin
            data = instruction;
        end 
        else begin
            data = 32'b0;
        end
    end

    assign id_inst.funct3 = data[14:12];
    assign id_inst.funct7 = data[31:25];
    assign id_inst.opcode = rv32i_opcode'(data[6:0]);
    assign id_inst.i_imm  = {{21{data[31]}}, data[30:20]};
    assign id_inst.s_imm  = {{21{data[31]}}, data[30:25], data[11:7]};
    assign id_inst.b_imm  = {{20{data[31]}}, data[7], data[30:25], data[11:8], 1'b0};
    assign id_inst.u_imm  = {data[31:12], 12'h000};
    assign id_inst.j_imm  = {{12{data[31]}}, data[19:12], data[20], data[30:21], 1'b0};
    assign id_inst.rs1  = data[19:15];
    assign id_inst.rs2  = (data[6:0] == 7'b0000011) ? 5'b0000: data[24:20];
    assign id_inst.rd = (data[6:0] inside {op_br, op_store}) ? 5'b00000 : data[11:7];


    assign id_pc = pc;

    assign rvfi.pc_rdata = pc; // if the if_rd = 0, we will freeze the pc register, so the pc here will repeat again
    assign rvfi.pc_wdata = pc+4;
    assign rvfi.inst =  instruction;
    assign rvfi.rs1_addr = data[19:15];
    assign rvfi.rs2_addr = (data[6:0] == 7'b0000011) ? 5'b0000: data[24:20];
    assign rvfi.rd_addr = (data[6:0] inside {op_br, op_store}) ? 5'b00000 : data[11:7];
    
    //tmp, will change in later stage
    assign rvfi.r1_rdata = '0;
    assign rvfi.r2_rdata = '0;
    assign rvfi.valid = '0;
    assign rvfi.rd_wdata = '0;
        
    endmodule
    
