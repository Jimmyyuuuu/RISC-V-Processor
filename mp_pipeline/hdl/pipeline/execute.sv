
module execute
  import forward_amux::*;
  import forward_bmux::*;
  import rv32i_types::*;
    (
        input id_ex_stage_reg_t id_ex,
        output ex_mem_stage_reg_t ex_mem,
      

        //forwarding inputs
        
        //from WB
        input logic [31:0]    regfilemux_out_forward,
        //from ex_mem
        input logic             ex_mem_br_en_forward,
        input logic [31:0]    ex_mem_alu_out_forward,
        input logic [31:0]              ex_mem_u_imm_forward,

        input forward_a_sel_t          forward_a_sel,
        input forward_b_sel_t          forward_b_sel,

        //*******Flushing signal***********
        input logic flushing_inst 
    );
  //*****************Flushing ****************************************
      
    
    assign ex_mem.pc = id_ex.pc;
    


    logic [31:0] forward_amux_out;
    logic [31:0] forward_bmux_out; 
  //*****************Forwarding Mux***************************
    always_comb begin 
      // forwarding rs1
      unique case (forward_a_sel) 
          forward_amux::rs1_v :   forward_amux_out = id_ex.rs1_v;
          forward_amux::br_en :   forward_amux_out = {31'b0,ex_mem_br_en_forward};
          // for lui
          //forward_amux::u_imm :   forward_amux_out = id_ex.u_imm;
          forward_amux::alu_out :         forward_amux_out = ex_mem_alu_out_forward;
          forward_amux::regfilemux_out :  forward_amux_out = regfilemux_out_forward;
          forward_amux::u_imm :           forward_amux_out = ex_mem_u_imm_forward;
          default : forward_amux_out = id_ex.rs1_v;
      endcase
      // forwarding rs2
      unique case (forward_b_sel) 
        forward_bmux::rs2_v :   forward_bmux_out = id_ex.rs2_v;
        forward_bmux::br_en :   forward_bmux_out = {31'b0, ex_mem_br_en_forward};
        // for lui
        //forward_bmux::u_imm :   forward_bmux_out = id_ex.u_imm;
        forward_bmux::alu_out : forward_bmux_out = ex_mem_alu_out_forward;
        forward_bmux::regfilemux_out : forward_bmux_out = regfilemux_out_forward;
        forward_bmux::u_imm :           forward_bmux_out = ex_mem_u_imm_forward;
        default : forward_bmux_out = id_ex.rs2_v;
    endcase
  end


        



    //alu signal
    logic  [31:0]  a, b;
    //logic  [31:0]  alu_out;
    // control signal
    //alu_mux_sel_1_t
    always_comb begin
        unique case(id_ex.alu_m1_sel) 
          1'b0 : a = forward_amux_out ;
          1'b1 : a = id_ex.pc;
          default : a = forward_amux_out;
        endcase
      end
    //alu_mux_sel_2_t
    always_comb begin
        unique case(id_ex.alu_m2_sel)
            1'b0 : b = forward_bmux_out;
            1'b1 : b = id_ex.imm_out;
            default: b = forward_bmux_out;
        endcase
      end

        
    alu alu(
      .a(a),
      .b (b),
      .f(ex_mem.alu_out),
      .aluop(id_ex.alu_op)
    );


    //cmpmux
     //cmp signal
    logic   [31:0]  cmp_a, cmp_b;
    //logic           br_en ;
    assign cmp_a = forward_amux_out;
    always_comb begin
      unique case(id_ex.cmp_sel)
        1'b0: cmp_b = forward_bmux_out;
        1'b1: cmp_b = id_ex.i_imm;
        default: cmp_b = 32'b0;
      endcase
    end
    

   
    //cmpop signal


    cmp cmp(
      .a(cmp_a),
      .b(cmp_b),
      .cmpop(id_ex.cmpop),
      .br_en(ex_mem.br_en)
    );

    

  //***************flushing*************************
    always_comb begin 
      if(flushing_inst) begin
          ex_mem.inst = 32'h00000013;
          ex_mem.valid = 0;
          ex_mem.funct7 = 7'd0;
          ex_mem.funct3 = 3'd0;
          ex_mem.opcode = 7'd0;
          ex_mem.rs1_s  = 5'd0;
          ex_mem.rs2_s  = 5'd0;
          ex_mem.rd_s   = 5'd0;
          ex_mem.imm_out = 32'd0;
          ex_mem.u_imm = 32'd0;
          ex_mem.j_imm = 32'd0;
          ex_mem.b_imm = 32'd0;
          ex_mem.i_imm = 32'd0;
          ex_mem.s_imm = 32'd0;
          ex_mem.rs1_v = 32'd0;
          ex_mem.rs2_v = 32'd0;

      end
      else begin
        ex_mem.inst = id_ex.inst;
        ex_mem.valid = id_ex.valid;
        ex_mem.funct7 = id_ex.funct7;
        ex_mem.funct3 = id_ex.funct3;
        ex_mem.opcode = id_ex.opcode;
        ex_mem.rs1_s  = id_ex.rs1_s;
        ex_mem.rs2_s  = id_ex.rs2_s;;
        ex_mem.rd_s   = id_ex.rd_s;
        ex_mem.imm_out = id_ex.imm_out;
        ex_mem.u_imm = id_ex.u_imm;
        ex_mem.j_imm = id_ex.j_imm;
        ex_mem.b_imm = id_ex.b_imm;
        ex_mem.i_imm = id_ex.i_imm;
        ex_mem.s_imm = id_ex.s_imm;
        ex_mem.rs1_v = forward_amux_out;
        ex_mem.rs2_v = forward_bmux_out;
        
      end
    end
    
        
    // ********transfer signal*******************
    
    //assign ex_mem.inst  =   id_ex.inst;

    //assign ex_mem.valid =  id_ex.valid;
   
    
    // send these signal to write back
    //assign ex_mem.rd_s = id_ex.rd_s;
    //assign ex_mem.rs1_v = forward_amux_out;
    //assign ex_mem.rs2_v = forward_bmux_out;
    //assign ex_mem.rs1_s = id_ex.rs1_s;
    //assign ex_mem.rs2_s = id_ex.rs2_s;
  
    // control signal & for write back mux
   
    //assign ex_mem.dmem_read = id_ex.dmem_read;
    //assign ex_mem.u_imm = id_ex.u_imm;
    assign ex_mem.regf_we = id_ex.regf_we;
    
    
    assign ex_mem.regfilemux_sel = id_ex.regfilemux_sel;
    /*
    assign ex_mem.funct7 = id_ex.funct7;
    assign ex_mem.funct3 = id_ex.funct3;
    assign ex_mem.opcode = id_ex.opcode;*/

   
    
    
   


    
    
    
    
    endmodule
    
    




