module cpu

    import rv32i_types::*; 
    import forward_amux::*;
    import forward_bmux::*;
     

    
    (
        input   logic           clk,
        input   logic           rst,
    
        output  logic   [31:0]  imem_addr,
        output  logic   [3:0]   imem_rmask,
        input   logic   [31:0]  imem_rdata,
        input   logic           imem_resp,
    
        output  logic   [31:0]  dmem_addr,
        output  logic   [3:0]   dmem_rmask,
        output  logic   [3:0]   dmem_wmask,
        input   logic   [31:0]  dmem_rdata,
        output  logic   [31:0]  dmem_wdata,
        input   logic           dmem_resp
    );
         //IF signals
        //logic [31:0] branch_pc;
        //logic PCSrc;
        logic [31:0] regfilemux_out ;
        logic [4:0] rd_s_back;
        logic regf_we_wb ; 
        forward_a_sel_t forward_a_sel;
        forward_b_sel_t forward_b_sel;
        logic       mem_wb_br_en_forward;
        logic [31:0] mem_wb_alu_out_forward;
        logic [31:0] mem_wb_u_imm_forward;
        logic br_en_out;
        logic [31:0] branch_pc;
        logic flushing_inst;
        logic stall_signal;
        logic freeze_stall;
        
    //claim pipeline register ,  and then send the each stage signal into each pipeline register 
    if_id_stage_reg_t if_id_reg_before, if_id_reg;
    id_ex_stage_reg_t id_ex_reg_before, id_ex_reg;
    ex_mem_stage_reg_t ex_mem_reg_before, ex_mem_reg ;
    mem_wb_stage_reg_t mem_wb_reg_before, mem_wb_reg;
 
  

    //pipeline
    always_ff@(posedge clk) begin
        if(freeze_stall) begin
            if_id_reg <= if_id_reg;
            id_ex_reg <= id_ex_reg ;
            ex_mem_reg <= ex_mem_reg ;
            mem_wb_reg <= mem_wb_reg ;
        end
        else if (stall_signal) begin
            if_id_reg <= if_id_reg;
            id_ex_reg <= '0;
            ex_mem_reg <=(rst ? '0 : ex_mem_reg_before);
            mem_wb_reg <=(rst ? '0 :mem_wb_reg_before);
        end 
        else begin 
            if_id_reg <= ( (rst || flushing_inst) ? '0 :if_id_reg_before);
            id_ex_reg <= (rst ? '0 :id_ex_reg_before);
            ex_mem_reg <=(rst ? '0 : ex_mem_reg_before);
            mem_wb_reg <=(rst ? '0 :mem_wb_reg_before);
        end
    end
    //***************fetch stage**********
    fetch fetch(
        .clk(clk),
        .rst(rst),
        .if_id_reg_before(if_id_reg_before),
        .imem_addr(imem_addr),
        .imem_rmask(imem_rmask),
        .br_en(br_en_out),
        .branch_pc(branch_pc),
        .stall_signal(stall_signal),
        //.imem_resp(imem_resp),
        .freeze_stall(freeze_stall)
    );

 

        

    // instruction start to transfer
    //imem_response is the signal to tell you that this instruction is valid
    //Should send it with imem_rdata at the same time
    //logic [31:0] imem_rdata_id;
    logic        imem_resp_id, imem_resp_ex, imem_resp_mem, imem_resp_wb;
    always_ff@(posedge clk) begin
        //imem_rdata_id <= imem_rdata;
        imem_resp_id  <= imem_resp;
        imem_resp_ex  <= imem_resp_id;
        imem_resp_mem <=imem_resp_ex;
        imem_resp_wb  <=imem_resp_mem;
    end
 
    decode decode(
        .clk(clk),
        .rst(rst),
        .imem_rdata_id(imem_rdata),
        .if_id(if_id_reg),
        .id_ex(id_ex_reg_before), 
        .rd_v(regfilemux_out),
        .rd_s_back(rd_s_back),
        .regf_we_back(regf_we_wb),
        .flushing_inst(flushing_inst),
        .freeze_stall(freeze_stall),
        .stall_signal(stall_signal)
    );

            

//*********************add forwarding
    execute execute(
        .id_ex (id_ex_reg),
        .ex_mem (ex_mem_reg_before),
        .forward_a_sel(forward_a_sel),
        .forward_b_sel(forward_b_sel),
        .regfilemux_out_forward(regfilemux_out),
        .ex_mem_br_en_forward(mem_wb_br_en_forward),
        .ex_mem_alu_out_forward(mem_wb_alu_out_forward),
        .ex_mem_u_imm_forward(mem_wb_u_imm_forward),
        .flushing_inst(flushing_inst)
        
    );

    memory memory (
        .ex_mem(ex_mem_reg),
        .mem_wb(mem_wb_reg_before),
        .mem_wb_now (mem_wb_reg),
        .dmem_addr(dmem_addr),
        .dmem_rmask(dmem_rmask),
        .dmem_wmask(dmem_wmask),
        .dmem_wdata(dmem_wdata),
        .mem_wb_br_en(mem_wb_br_en_forward),
        .mem_wb_alu_out(mem_wb_alu_out_forward),
        .mem_wb_u_imm(mem_wb_u_imm_forward),
        .br_en_out(br_en_out),
        .branch_new_address(branch_pc),
        .flushing_inst(flushing_inst),
        .freeze_stall(freeze_stall)
    );
    
    

    writeback writeback(
        .clk(clk),
        .rst(rst),
        .mem_wb(mem_wb_reg),
        .dmem_rdata(dmem_rdata),
        .dmem_resp(dmem_resp),
        .regfilemux_out(regfilemux_out),
        .rd_s_back(rd_s_back),
        .regf_we_back(regf_we_wb),
        .freeze_stall(freeze_stall)
        

    );

    forward forward(
        .id_ex(id_ex_reg),
        .ex_mem(ex_mem_reg),
        .mem_wb(mem_wb_reg),
        .forward_a_sel(forward_a_sel),
        .forward_b_sel(forward_b_sel)
    );

    stall stall(

        .id_ex(id_ex_reg_before),
        .ex_mem(ex_mem_reg_before),
        .stall_signal(stall_signal)
    );

    freeze freeze(
        .mem_wb(mem_wb_reg),
        .imem_resp(imem_resp),
        .dmem_resp(dmem_resp),
        .freeze_stall(freeze_stall)

    );

    
    
    

    
    
    


    
    
    
    
    endmodule : cpu