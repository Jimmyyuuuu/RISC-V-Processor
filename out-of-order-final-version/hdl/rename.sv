module rename 
    import rv32i_types::*;
    import  ctrl_types::*;
    (
        input   logic           clk,
        input   logic           rst,
        // input   logic   iq_re_in,
        //Rvfi signal
        input  rvfi_data rvfi_in,
        output rvfi_data rvfi_out1, 
        output rvfi_data rvfi_out2, 
        output rvfi_data rvfi_out3,
        output rvfi_data rvfi_out4,
        //from decode
        input  ctrl_types::rv32i_control_word   ctrl_in,

    
        // renaming input from REG_file, ROB, CDB
        //regfile   
        // if busy bit = 0, valid = 1, use val
        input   logic   [31:0]  reg_r1_v,
        input   logic   [31:0]  reg_r2_v,
        input   logic           reg_r1_valid,
        input   logic           reg_r2_valid,
        //dispatch send to regfile
        //update rob entry
        output  logic   [3:0]   dispatch_rob_entry ,      //from rob, then give regfile(for rd_s)
        output  logic   [4:0]   dispatch_rd_s,
        //renaming rs1/rs2
        output  logic   [4:0]   dispatch_rs1_s,
        output  logic   [4:0]   dispatch_rs2_s,
        
    
        // ROB
        //full signal
        input   logic           rob_full,
        //rds
        input   logic           rob_entry_valid,
        input   logic   [3:0]   rob_rds_entry,
        // rs1/rs2
        input   logic   [31:0]  rob_r1_v,
        input   logic   [31:0]  rob_r2_v,
        input   logic           rob_r1_valid,
        input   logic           rob_r2_valid,
        input   logic   [3:0]   rob_rs1_entry,
        input   logic   [3:0]   rob_rs2_entry,
        output  logic   [6:0]   rob_opcode,
        output  logic   [4:0]   rob_rds,
    
        //CDB
        input   cdb_t           cdb1,
        input   cdb_t           cdb2,
        input   cdb_t           cdb3,
        input   cdb_t           cdb4,
    
    
        //RS
        input   logic           rs_full1,
        input   logic           rs_full2,
        input   logic           rs_full3,
        input   logic           rs_full4,
    
    
        //output signals
        output  logic           freeze,    //stop iq deque/and hold reg stop 
        output  logic           dispatch1,
        output  logic           dispatch2,
        output  logic           dispatch3,
        output  logic           dispatch4,
        output  rs_t            rs1,
        output  rs_t            rs2,
        output  rs_t            rs3,
        output  rs_t            rs4
    
    
    
    
    );
        rs_t    tmp;
        logic   rs1_match_cdb, rs2_match_cdb, rs3_match_cdb;
        logic   dispath4_d;
        logic [31:0] pc_late;
        //logic   cdb_match3, cdb_match4;
    
    
        //TODO based on load_regfile to see if we need rds renaming (EX: store doesnt have rds)
        //update rds rob_entry
        // assign tmp.load_regfile = ctrl_in.load_regfile;
        // assign tmp.iq_re    = ctrl_in.iq_re;
        // assign tmp.rob_entry = rob_rds_entry;
        assign tmp.imm      = ctrl_in.imm;
        assign tmp.pc       = ctrl_in.pc;
        assign tmp.rob_entry = rob_entry_valid ? rob_rds_entry : 'x;
        assign tmp.rds      = ctrl_in.rd_s;
        assign tmp.taken    = 1'b0;
        assign tmp.funct3   = ctrl_in.funct3;
        //op update
        assign tmp.aluop   = ctrl_in.aluop;
        assign tmp.cmpop   = ctrl_in.cmpop;
        assign tmp.mulop   = ctrl_in.mulop;
        //opcode from decode
        assign tmp.opcode  = ctrl_in.opcode;
    
        //from rob
        assign tmp.rs1_rob = rob_rs1_entry;
        assign tmp.rs2_rob = rob_rs2_entry;
    
        //value found from cdb
        assign rs1_match_cdb  = (!reg_r1_valid) && (!rob_r1_valid) && ((cdb1.valid && (rob_rs1_entry == cdb1.tag)) || (cdb2.valid && (rob_rs1_entry == cdb2.tag)) || (cdb3.valid && (rob_rs1_entry == cdb3.tag)) || (cdb4.valid && (rob_rs1_entry == cdb4.tag)));
        assign rs2_match_cdb  = (!reg_r2_valid) && (!rob_r2_valid) && ((cdb1.valid && (rob_rs2_entry == cdb1.tag)) || (cdb2.valid && (rob_rs2_entry == cdb2.tag)) || (cdb3.valid && (rob_rs2_entry == cdb3.tag)) || (cdb4.valid && (rob_rs2_entry == cdb4.tag)));
    
        //set busy bit (if r1_v and r2_v is found in REG_file/ROB/CDB)
        assign tmp.busy_1  = ctrl_in.rs1_valid ? !(reg_r1_valid || rob_r1_valid || rs1_match_cdb) : 1'b0 ;
        assign tmp.busy_2  = ctrl_in.rs2_valid ? !(reg_r2_valid || rob_r2_valid || rs2_match_cdb) : 1'b0 ;

        always_comb begin 
    
            //update r1_v
            //edge case for lui
            if (ctrl_in.opcode == op_lui) begin
                tmp.r1_v = '0;
            end
            //edge case for jal/jalr
            else if (ctrl_in.opcode == op_jal) begin
                tmp.r1_v = ctrl_in.pc;
            end
            else if (ctrl_in.rs1_valid) begin
                if (reg_r1_valid)
                    tmp.r1_v = reg_r1_v;
                else if (rob_r1_valid) 
                    tmp.r1_v = rob_r1_v;
                else if (rs1_match_cdb) begin
                    // cdb1
                    if (cdb1.valid && (rob_rs1_entry == cdb1.tag))
                        tmp.r1_v = cdb1.value;
                    // cdb2
                    else if (cdb2.valid && (rob_rs1_entry == cdb2.tag))
                        tmp.r1_v = cdb2.value;
                    // cdb3
                    else if (cdb3.valid && (rob_rs1_entry == cdb3.tag))
                        tmp.r1_v = cdb3.value;
                    // cdb4
                    else if (cdb4.valid && (rob_rs1_entry == cdb4.tag))
                        tmp.r1_v = cdb4.value;
                    else
                    tmp.r1_v = cdb2.value;
                end
                else
                    tmp.r1_v = 'x;
            end
            else
                tmp.r1_v = ctrl_in.pc;
    
            
            //update r2_v
            //edge case for lui
            if (ctrl_in.opcode == op_lui) begin
                tmp.r2_v = ctrl_in.imm;
            end
            //edge case for jal/jalr
            else if (ctrl_in.opcode inside {op_jal, op_jalr}) begin
                tmp.r2_v = 4;
            end
            else if (ctrl_in.rs2_valid) begin
                if (reg_r2_valid)
                    tmp.r2_v = reg_r2_v;
                else if (rob_r2_valid) 
                    tmp.r2_v = rob_r2_v;
                else if(rs2_match_cdb) begin
                    // cdb1
                    if(cdb1.valid && (rob_rs2_entry == cdb1.tag))
                        tmp.r2_v = cdb1.value;
                    // cdb2
                    else if (cdb2.valid && (rob_rs2_entry == cdb2.tag))
                        tmp.r2_v = cdb2.value;
                    // cdb3
                    else if (cdb3.valid && (rob_rs2_entry == cdb3.tag))
                        tmp.r2_v = cdb3.value;
                    // cdb4
                    else if (cdb4.valid && (rob_rs2_entry == cdb4.tag))
                        tmp.r2_v = cdb4.value;
                    else
                        tmp.r2_v = cdb2.value;
                end
                else
                    tmp.r2_v = 'x;
            end
            else 
                tmp.r2_v = ctrl_in.imm;
    
        end
    
        ////////////////////////////////////////////////////////////////////////things going in ROB
        assign rob_opcode  =   ctrl_in.opcode;
        assign rob_rds     =   ctrl_in.rd_s;
    
        //////////////////////////////////////////////////////////////////////////things going in Reg_file
        assign dispatch_rob_entry  =   rob_entry_valid ? rob_rds_entry : 'x;
        assign dispatch_rd_s       =   ctrl_in.rd_s;
        assign dispatch_rs1_s      =   ctrl_in.rs1_s;
        assign dispatch_rs2_s      =   ctrl_in.rs2_s;
    
    
    
        //general output signals
        
        assign dispatch1  = (ctrl_in.alu_valid && ctrl_in.iq_re && !rs_full1) && (ctrl_in.pc != '0) && !rob_full;
        assign dispatch2  = (ctrl_in.mul_valid && ctrl_in.iq_re && !rs_full2) && (ctrl_in.pc != '0) && !rob_full;
        assign dispatch3  = (ctrl_in.cmp_valid && ctrl_in.iq_re && !rs_full3) && (ctrl_in.pc != '0) && !rob_full;
        assign dispatch4  = !(dispath4_d && (pc_late == ctrl_in.pc)) && (ctrl_in.load_valid || ctrl_in.store_valid) && (ctrl_in.iq_re && !rs_full4) && (ctrl_in.pc != '0) && !rob_full;
        assign rs1        = dispatch1 ?    tmp : '0;
        assign rs2        = dispatch2 ?    tmp : '0;
        assign rs3        = dispatch3 ?    tmp : '0;
        assign rs4        = dispatch4 ?    tmp : '0;
        // assign freeze     = (rob_full || !(dispatch1 || dispatch2 || dispatch3 || dispatch4)) && ctrl_in.iq_re;
        assign freeze     = (rob_full || ((ctrl_in.alu_valid &&rs_full1) || (ctrl_in.mul_valid && rs_full2) || (ctrl_in.cmp_valid && rs_full3) || ((ctrl_in.load_valid || ctrl_in.store_valid) &&rs_full4))) && ctrl_in.iq_re;
        assign rvfi_out1  = dispatch1 ?  rvfi_in : '0; 
        assign rvfi_out2  = dispatch2 ?  rvfi_in : '0; 
        assign rvfi_out3  = dispatch3 ?  rvfi_in : '0; 
        assign rvfi_out4  = dispatch4 ?  rvfi_in : '0; 

        always_ff @( posedge clk ) begin 
            if (rst) begin
                dispath4_d <= '0;    
            end
            else if (dispatch4)  begin
                dispath4_d <= '1;
            end
            else if (pc_late != ctrl_in.pc) begin
                dispath4_d <= '0;    
            end
            else begin
                dispath4_d <= dispath4_d;
            end
        end

        always_ff @( posedge clk ) begin 
            if (rst) pc_late <= '0;
            else pc_late <= ctrl_in.pc;
        end

    
    endmodule   :   rename