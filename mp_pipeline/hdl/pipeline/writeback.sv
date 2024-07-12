module writeback
    import rv32i_types::*;
    (   
    
        input logic clk,
        input logic rst,
        input mem_wb_stage_reg_t mem_wb,
        input   logic   [31:0]  dmem_rdata,
        input   logic           dmem_resp,
        input   logic           freeze_stall,
        output  logic [31:0]    regfilemux_out,
        output  logic [4:0]     rd_s_back,
        output logic regf_we_back
        
    );
    
    
    logic           commit;
    logic   [63:0]  order;
    //*****************read enable signal*****************************************
    /*always_comb begin
        unique case(mem_wb.dmem_read) 
            1'b0 :  dmem_rdata = 0 ;
            1'b1 :  dmem_rdata = mem_wb.alu_out;
            default : dmem_rdata = 0 ;
        
        endcase
    end*/
    
    
    
    
    always_comb begin
        if((~freeze_stall) && (mem_wb.valid) ) begin
            commit = 1'b1;
        end
        else 
            commit = 1'b0;
    end
    
     always_ff@(posedge clk) begin
        if(rst) begin
            order <= 64'd0;
        end
        else if(commit) begin
            order <= order +64'd1;
        end
        else
            order <= order ;
    end
    
        
    //*******************************send to json*********************
        
       
        logic          rvfi_valid ;
        logic [63:0]         rvfi_order;
        logic [31:0]     rvfi_inst;
        logic [4:0]  rvfi_rs1_addr;
        logic [4:0]  rvfi_rs2_addr;
        logic [31:0] rvfi_rs1_rdata;
        logic [31:0] rvfi_rs2_rdata;
        logic [4:0] rvfi_rd_addr;
        logic [31:0] rvfi_rd_wdata;
        logic [31:0] rvfi_pc_rdata;
        logic [31:0] rvfi_pc_wdata;
        logic [31:0]  rvfi_dmem_addr;
        logic [3:0]  rvfi_dmem_rmask;
        logic [3:0]  rvfi_dmem_wmask;
        logic [31:0] rvfi_dmem_rdata;
        logic [31:0] rvfi_dmem_wdata;
        
    
        //********************** Judge new address for jump/br ******************
        
        always_comb begin
            if((mem_wb.opcode == op_br) &&(mem_wb.br_en == 1'b1) ) begin
                rvfi_pc_wdata = mem_wb.pc + mem_wb.b_imm;
            end
            else if (mem_wb.opcode == op_jal) begin
                rvfi_pc_wdata = (mem_wb.pc + mem_wb.j_imm)& 32'hfffffffe;
            end
            else if (mem_wb.opcode == op_jalr) begin
                rvfi_pc_wdata = (mem_wb.rs1_v + mem_wb.i_imm) & 32'hfffffffe;
            end
            else begin
                rvfi_pc_wdata = mem_wb.pc + 32'd4;
            end
        end
    
    
        
    
        //********************lui rs2_shadow issue *************************
        logic [4:0] true_rs1_s;
        logic [4:0] true_rs2_s;
        logic [4:0] true_rd_s;
        logic [31:0] true_rs1_v;
        logic [31:0] true_rs2_v;
        
        assign true_rd_s = (mem_wb.opcode != op_store && mem_wb.opcode!= op_br) ? mem_wb.rd_s : 5'b0;
        assign true_rs1_s = (mem_wb.opcode inside {op_jalr, op_br, op_load, op_store, op_reg, op_imm}) ? mem_wb.rs1_s : 5'b0;
        assign true_rs2_s = (mem_wb.opcode inside {op_br, op_store, op_reg}) ? mem_wb.rs2_s : 5'b0;
        assign true_rs1_v = (mem_wb.opcode inside {op_jalr, op_br, op_load, op_store, op_reg, op_imm}) ? mem_wb.rs1_v : 5'b0;
        assign true_rs2_v = (mem_wb.opcode inside {op_br, op_store, op_reg}) ? mem_wb.rs2_v : 5'b0;
    
    
    
    
    
                
        
        assign rvfi_valid = commit;
        assign rvfi_order = order;
        assign rvfi_inst = mem_wb.inst;
        assign rvfi_rs1_addr = true_rs1_s;
        assign rvfi_rs2_addr = true_rs2_s;
        assign rvfi_rs1_rdata = true_rs1_v;
        assign rvfi_rs2_rdata = true_rs2_v;
        assign rvfi_rd_addr = true_rd_s;
        assign rvfi_rd_wdata = regfilemux_out;
        assign rvfi_pc_rdata = mem_wb.pc; // current pc
        assign rd_s_back = mem_wb.rd_s;
        assign rvfi_dmem_addr = mem_wb.dmem_addr;
        assign rvfi_dmem_rmask = mem_wb.dmem_rmask;
        assign rvfi_dmem_wmask = mem_wb.dmem_wmask;
        assign rvfi_dmem_rdata = dmem_rdata;
        assign rvfi_dmem_wdata = mem_wb.dmem_wdata;
    
       
    
    
        //registerfilemux
        
            
        /*lb : mem_wb.rd_v = {{24{dmem_rdata[7 +8 *mem_addr[1:0]]}}, dmem_rdata[8 *mem_wb.dmem_addr[1:0] +: 8 ]};
        lbu: mem_wb.rd_v = {{24{1'b0}}                          , dmem_rdata[8 *mem_wb.dmem_addr[1:0] +: 8 ]};
        lh : mem_wb.rd_v = {{16{dmem_rdata[15+16*mem_addr[1]  ]}}, dmem_rdata[16*mem_wb.dmem_addr[1]   +: 16]};
        lhu: mem_wb.rd_v = {{16{1'b0}}                          , dmem_rdata[16*mem_wb.dmem_addr[1]   +: 16]};
        lw : mem_wb.rd_v = dmem_rdata ;*/
    
    
    
        always_comb begin
            if(mem_wb.opcode == op_load ) begin
                regf_we_back = (dmem_resp ? 1'b1:1'b0);
            end
            else if (mem_wb.opcode inside {op_br, op_store}) begin
                regf_we_back = 1'b0;
            end
            else begin
                regf_we_back = mem_wb.regf_we;
            end
        end
    
                
    
    
    
        //mux for regfile data selection
        logic [31:0] rd_v;
        always_comb begin
            case(mem_wb.regfilemux_sel)
                //br_en
                4'b0001 : rd_v ={31'b0, mem_wb.br_en};
                //u_imm
                4'b0010: rd_v = mem_wb.u_imm;
                //alu_out
                4'b0000 : rd_v = mem_wb.alu_out;
                //pc_plus4
                4'b0100 : rd_v = mem_wb.pc + 32'd4;
                //lb
                4'b0101 : rd_v = {{24{dmem_rdata[7 +8 *mem_wb.dmem_addr[1:0]]}}, dmem_rdata[8 *mem_wb.dmem_addr[1:0] +: 8 ]};
                //lbu
                4'b0110 : rd_v = {{24{1'b0}}                          ,dmem_rdata[8 *mem_wb.dmem_addr[1:0] +: 8 ]};
                //lh
                4'b0111:  rd_v = {{16{dmem_rdata[15+16*mem_wb.dmem_addr[1]  ]}}, dmem_rdata[16*mem_wb.dmem_addr[1]   +: 16]};
                //lhu
                4'b1000: rd_v = {{16{1'b0}}                          , dmem_rdata[16*mem_wb.dmem_addr[1]   +: 16]};
                //lw
                4'b0011: rd_v = dmem_rdata ;
            default : rd_v = 32'd0;
            endcase
        end
        assign regfilemux_out = rd_v;
                
    
    
      
    
     
    
    
    
    endmodule