module cpu
    import ctrl_types::*;
    import inst_types::*;
    import rv32i_types::*;
    (
        input   logic           clk,
        input   logic           rst,
        // Single memory port connection when caches are integrated into design (CP3 and after)
        // Because our cpu.sv module now include all the cache, arbiter, adaptor ! not only the cpu
        output logic   [31:0]      bmem_addr,
        output logic               bmem_read,
        output logic               bmem_write,
        output logic   [63:0]      bmem_wdata,
        input logic               bmem_ready,

        input logic   [31:0]      bmem_raddr,
        input logic   [63:0]      bmem_rdata,
        input logic               bmem_rvalid
        
    );
    logic trash;
    logic [31:0]trash2;
    assign trash = bmem_ready;
    assign trash2 = bmem_raddr;
    //send to I-cache
    logic   [31:0]  imem_addr;
    logic   [3:0]   imem_rmask;
    logic   [31:0]  imem_rdata;
    logic   [31:0]  imem_rdata_late;
    logic           imem_resp;
    //I-cache resp
    logic           ufp_resp_late;
    //send to D-cache (from load_store queue)
    logic   [31:0]  dmem_addr;
    logic   [3:0]   dmem_rmask;
    logic   [3:0]   dmem_wmask;
    logic   [31:0]  dmem_rdata;
    logic   [31:0]  dmem_wdata, dmem_wdata_tmp2;
    logic   [31:0]  dmem_addr_tmp;
    logic   [3:0]   dmem_rmask_tmp;
    logic   [3:0]   dmem_wmask_tmp;
    logic   [31:0]  dmem_rdata_tmp;
    logic   [31:0]  dmem_wdata_tmp;

    logic           dmem_resp;
    //*********adaptor send back to arbiter*******
    logic           adap_resp;
    logic  [255:0]  adap_rdata;


    //arbiter 
    logic           arbit_read;
    logic           arbit_write;
    // data for I-cache or D-cache
    logic  [255:0]  arbit_rdata_I;
    logic  [255:0]  arbit_rdata_D;

    logic           arbit_resp_I;
    logic           arbit_resp_D;   
    logic  [255:0]  arbit_wdata_D;
    logic  [31:0]   arbit_addr_fin;


    //DFP
    logic [31:0] dfp_addr_I, dfp_addr_D;
    logic        dfp_read_I, dfp_read_D;
    logic                   dfp_write_D;
    logic [255:0]           dfp_wdata_D;
    //L2_cache send to arbiter
    logic L2_cache_resp;
    logic [255:0] L2_cache_rdata;
    //arbiter send to L2_cache
    logic [255:0] L2_cache_wdata_;
    logic [31:0] L2_cache_address;
    logic L2_cache_read;
    logic L2_cache_write;
    //L2_cache send to adaptor
    logic [31:0] adaptor_address;
    logic [255:0] adaptor_wdata;
    logic         adaptor_read;
    logic         adaptor_write;


    // logic zero;
    // assign zero = 1'b0;
    /////////////////////////////
    logic   flush, mem_flush;
    //*****************fetch*****************************
    logic   freeze; 
    logic   [31:0]  fetch_br_addr;
    logic     fetch_br_en;
    logic     imem_stall;
    
    //*****************instruction queue*****************
    logic   iq_we, iq_re;           //inst queue write/read enable (queue/deque)
    logic   iq_full, iq_empty;      //inst queue full/empty
    logic [31:0] pc,pc_late;
    iq_t    iq_out; //output struct from instruction queue
    
    //*****************decode ***************************
    inst_t id_inst;
    // logic id_valid;
    logic [31:0] id_pc;

    //****************control****************************
    rv32i_control_word ctrl;
    //****************instruction hold register**********
    rv32i_control_word ctrl_out;
    logic ctrl_valid;
    

    //*****************dispatch & rename******************
    logic [6:0] dis_opcode; // send to ROB
    logic [4:0] dis_rds, dis_rds1;    //send to ROB & regfile
    logic [4:0] dis_r1s;
    logic [4:0] dis_r2s;
    logic [3:0] dis_tag;
    logic       dispatch;   //send to ROB, for Wr_en
    logic [31:0] dis_r1v, dis_r2v; //for alu rs
    logic [31:0] dis_r1v_1, dis_r2v_1; //for mul rs
    logic dispatch_1, dispatch_2, dispatch_3,dispatch_4;

    logic dis_freeze; // If ROB full or RS full, this signal will set to high
    rs_t rs1,rs2, rs3, rs4;

    //*****************Reservation station*****************
    rs_t rs_out1, rs_out2, rs_out3;
    logic output_valid1, output_valid2, output_valid3;
    logic full_rs1, empty_rs1;
    logic full_rs2, empty_rs2;
    logic full_rs3, empty_rs3;
    logic full_rs4, empty_rs4;
    


    //*****************Function Unit**********************
    //Mul
    logic   done, work;
    logic   [63:0] mul_value;
    logic   [31:0] mulout;
    logic   [3:0] mul_tag;
    



    //**************ROB********************
    //send to dispatch
    logic rs1_valid;
    logic rs2_valid;
    logic [31:0] rs1_val;
    logic [31:0] rs2_val;
    logic   [3:0]   rs1_rob, rs2_rob;
    //check if the returned rob entry for rds renaming is valid
    logic        entry_valid;      
    logic  [3:0]   ROB_entry; 
    logic dispatch_;
    
    assign dispatch_ = dispatch_1 || dispatch_2 || dispatch_3|| dispatch_4;
    //for commiting in regfile
    rob_t ROB_Reg;
    logic        ready;
    logic   [3:0]    ROB_commit_tag;
    //FIFO stuff
    logic   full_rob;
    logic   empty_rob;

    //Load Store queue signals
    logic   lsq_store_commit;
    logic   dmem_work;
    logic   dmem_valid;
    lsq_t   dmem_out;
    cdb_t   forward_cdb_out;
    cdb_t   forward_cdb_out_lsq, forward_cdb_out_lsq_tmp;
    lsq_t   forward_out, forward_out_tmp;
    logic   forward_valid, forward_valid_tmp;  
    rvfi_data   mem_rvfi, forward_mem_rvfi;   
    

    //************************CDB**********************
    //output from FU : alu_out, mul_out, cmp_out, load_out 
    //output from CDB : alu_cdb, mul_cdb, cmp_cdb, load_cdb
    cdb_t alu_cdb, alu_out;
    cdb_t mul_cdb, mul_out_;
    cdb_t cmp_cdb, cmp_out; 
    cdb_t load_cdb, load_out;



    //*****************regfile********_tmp***************
    //send to ROB
    logic       tag1_valid;
    logic       tag2_valid;
    logic [3:0] tag_out1;
    logic [3:0] tag_out2;
    //send to dispatch
    reg_d rs_out;
    // send to bp
    logic   [6:0]   opcode;
   
    //*************commit***************
    logic  [63:0]    order;
    
    
    //control
    rvfi_data rvfi_ctrl;
    rvfi_data rvfi_1_1, rvfi_1_2, rvfi_2_1, rvfi_2_2, rvfi_2_3, rvfi_2_4;
    //rvfi output of RS
    rvfi_data rvfi_3_1, rvfi_3_2, rvfi_3_3, rvfi_3_4, rvfi_3_5, rvfi_3_5_tmp;
    //rvfi output of FU
    rvfi_data rvfi_alu, rvfi_mul, rvfi_cmp;
    //rvfi output of CDB
    rvfi_data rvfi_alucdb, rvfi_mulcdb, rvfi_mulval, rvfi_cmpcdb, rvfi_memcdb;
    //ROB to monitor
    rvfi_data rvfi_rob;
    rvfi_data rvfi_monitor;
    logic     valid;
    
    logic   edge_flag;
    logic imem_resp_1;


    // for decoderfor_predictor
    logic [31:0] pc_target_addr;
    logic  valid_predict;

    //for bp
    logic taken;
    logic mispredict;
    logic [31:0] recover_pc;
    logic bp_ready;
    logic jump_valid1, jump_valid2;
    logic  edge_done;
    logic  bp_full, bp_empty;

    //sends the correct pc to instruction cache/mem
    fetch   fetch_(
        // .imem_resp(ufp_resp_late),
        .bp_full(bp_full),
        .imem_resp(imem_resp),
        // .br_en(fetch_br_en),
        // .br(fetch_br_addr),
        .bp_taken(taken),
        .bp_target_addr(pc_target_addr),
        .mispredict(mispredict),
        .recover_addr(recover_pc),
        .imem_addr(imem_addr),
        .imem_rmask(imem_rmask),
        .freeze(freeze),
        .imem_stall(imem_stall),
        .*
    );  
    assign imem_resp = imem_resp_1 && !freeze;
      always_ff@(posedge clk) begin
        if(rst) begin
            ufp_resp_late <= 1'b0;
        end
        else
            ufp_resp_late <= imem_resp;
    end
    // assign imem_stall = !ufp_resp_late && !rst; 
    assign imem_stall = !imem_resp && !rst; 
    
    // Avoid the pc keep reset, 6000000->6000004 and again6000000->600004
      //*********************I-cache******************
    I_cache I_cache_(
        .clk(clk),
        .rst(rst),
        // cpu side signals, ufp -> upward facing port
        //input
        .ufp_addr(imem_addr),
        .ufp_rmask(imem_rmask),
        .ufp_wmask('0),
        .ufp_wdata('0),
        //output
        .ufp_rdata(imem_rdata),
        .ufp_resp(imem_resp_1), //delay one cycle to fetch -> ufp_resp late

        // memory side signals, dfp -> downward facing port
        //input
        .dfp_rdata(arbit_rdata_I),
        .dfp_resp(arbit_resp_I),
        //output 
        .dfp_addr(dfp_addr_I),
        .dfp_read(dfp_read_I)
    );
   
  
    //******************D-cache************************
    D_cache D_cache_(
        .clk(clk),
        .rst(rst),
        // cpu side signals, ufp -> upward facing port
        //input
        .ufp_addr(dmem_addr_tmp),
        .ufp_rmask(dmem_rmask_tmp),
        .ufp_wmask(dmem_wmask_tmp),
        .ufp_wdata(dmem_wdata_tmp),
        //output
        .ufp_rdata(dmem_rdata),
        .ufp_resp(dmem_resp),
        //memory side signals, dfp -> downward facing port
        //input
        .dfp_rdata(arbit_rdata_D),
        .dfp_resp(arbit_resp_D),
        //output
        .dfp_addr(dfp_addr_D),
        .dfp_read(dfp_read_D),
        .dfp_write(dfp_write_D),
        .dfp_wdata(dfp_wdata_D)
    );
    //******************arbiter*************************
    arbiter arbiter(
        .clk(clk),
        .rst(rst),
        //******from cache**************//
        //input
        .i_cache_read(dfp_read_I),
        .i_cache_address(dfp_addr_I),
        .d_cache_wdata(dfp_wdata_D),
        .d_cache_read(dfp_read_D),
        .d_cache_write(dfp_write_D),
        .d_cache_address(dfp_addr_D),
        //output
        .i_cache_resp(arbit_resp_I),
        .d_cache_resp(arbit_resp_D),
        .i_cache_rdata(arbit_rdata_I),
        .d_cache_rdata(arbit_rdata_D),
        //********* signals to/from adaptor ***************//
        //input
        .L2_cache_resp(L2_cache_resp),
        .L2_cache_rdata(L2_cache_rdata),
        //output
        .L2_cache_wdata(L2_cache_wdata_),
        .L2_cache_address(L2_cache_address),
        .L2_cache_read(L2_cache_read),
        .L2_cache_write(L2_cache_write)
    );
    l2_cache L2_cache_(
        .clk(clk),
        .rst(rst),
        //arbiter <-> L2 Cache
        //input
        .arbiter_address(L2_cache_address),
        .arbiter_write(L2_cache_write),
        .arbiter_read(L2_cache_read),
        .arbiter_wdata(L2_cache_wdata_),
        //output
        .arbiter_resp(L2_cache_resp),
        .arbiter_rdata(L2_cache_rdata),
        //L2 Cache <-> adaptor
        //input
        .adaptor_rdata(adap_rdata),
        .adaptor_dfp_resp(adap_resp),
        //output
        .adaptor_address(adaptor_address),
        .adaptor_wdata(adaptor_wdata),
        .adaptor_read(adaptor_read),
        .adaptor_write(adaptor_write)
    );
    //************adaptor*******************************
    adaptor adaptor_(
        //port to cache
        //input
        .line_in(adaptor_wdata),
        .address_in(adaptor_address),
        .dfp_read(adaptor_read),
        .dfp_write(adaptor_write),
        //output 
        .line_out(adap_rdata),
        .adaptor_dfp_resp(adap_resp),

        //port to memory
        //input
        .burst_in(bmem_rdata),
        .bmem_rvalid(bmem_rvalid),
        //output
        .burst_out(bmem_wdata),
        .address_out(bmem_addr),
        .bmem_read(bmem_read),
        .bmem_write(bmem_write),
        .*
    ); 


    bp_decoder decoder_for_predictor (
        .instruction(imem_rdata),
        .pc_late(pc),
        
        //goes to bp
        .valid(valid_predict),

        //goes to fetch
        .pc_target_addr(pc_target_addr),
        .jump_valid1(jump_valid1),
        .jump_valid2(jump_valid2),


        .mispredict(mispredict),
        .imem_resp(imem_resp),
        .*

    );

    bp bp (
        .jump_valid1(jump_valid1),
        .jump_valid2(jump_valid2),
        .imem_resp(imem_resp),
        // .ufp_resp_late(ufp_resp_late),
        .bp_ready(bp_ready),
        .clk(clk),
        .rst(rst),
        .flush(flush),
        .pc(pc),
        .valid(valid_predict),

        //from  reg_file
        .commit_br_pc(fetch_br_addr),
        .commit_br_en(fetch_br_en),
        .commit_opcode(opcode),

        //goes to fetch for prediction
        .taken(taken),

        //goes to fetch for recovering pc mispredict
        .mispredict(mispredict),
        .recover_pc(recover_pc),
        .full(bp_full),
        .empty(bp_empty),
        .*
    );

    assign mem_flush = mispredict;

    always_ff @( posedge clk ) begin 
        if (rst) flush <= '0;
        else flush <= mem_flush;
    end







    logic   f1,f2,f3;
    always_comb begin 
        // set default valueimem_resp
        iq_we = 1'b0;           
        freeze = 1'b0;
        f1 = '0;
        f2 = '0;
        f3 = '0;
    
        // if not full
        if ((pc_late != pc) && !iq_full && ufp_resp_late && (pc_late!=0) && imem_rdata_late[6:0] inside {op_lui, op_auipc, op_jal, op_jalr, op_br, op_load, op_store, op_imm, op_reg}) begin //ufp_resp late
            iq_we = 1'b1;
            freeze = 1'b0;
            f1 = '1;
        end

        // else if (edge_flag && imem_resp && !iq_full) begin
        //     iq_we = 1'b1;
        //     freeze = 1'b0;
        //     f2 = '1;
        // end
        else if ( edge_flag && !iq_full && (pc_late!=0) && imem_rdata_late[6:0] inside {op_lui, op_auipc, op_jal, op_jalr, op_br, op_load, op_store, op_imm, op_reg}) begin
            iq_we = 1'b1;
            freeze = 1'b0;
            f2 = '1;
        end
    
        // if full
        else if (iq_full) begin
            iq_we = 1'b0;
            freeze = 1'b1;
            f3 = '1;
        end
    end

    always_ff @( posedge clk ) begin 
        if (rst) edge_done <= '0;
        else if (f2) edge_done <= '1;
        else if ((pc_late != pc)) edge_done <= '0;
        else edge_done <= edge_done;
    end


    always_ff @(posedge clk) begin
        if (rst)    edge_flag <= '0;
        else if(iq_full && ufp_resp_late) edge_flag <= '1;
        else if (iq_we) edge_flag <= '0;
        else edge_flag <= edge_flag;
    end

    //FUTURE : have to consider if ROB or RS is full
    assign iq_re = !iq_empty && !dis_freeze;
    // assign iq_re = 1'b0;
    

    always_ff@(posedge clk) begin
        if(rst) begin
            pc <= imem_addr;
        end
        else if(imem_resp&& !iq_full) begin
            pc <= imem_addr;
        end
        else begin
            pc <= pc;
        end
    end

    always_ff @( posedge clk ) begin
        if (rst) pc_late <= '0;
        else if (imem_resp && !iq_full) pc_late <= pc;
        else pc_late <= pc_late;
    end

    always_ff@(posedge clk) begin
        if(rst) begin
            imem_rdata_late <= '0;
        end
        else if(imem_resp && !iq_full) begin
            imem_rdata_late <= imem_rdata;
        end
        else begin
            imem_rdata_late <= imem_rdata_late;
        end
    end


      
    // sends the fetched instruction and store in instruction queue
    FIFO    i_queue(
        .imem_resp(ufp_resp_late),
        .flush(flush),
        .pc_if(pc_late),
        .writeEn(iq_we),
        .writeData(imem_rdata_late), // ufp_rdata need to 
        .readEn(iq_re),
        .iq_out(iq_out),
        .full(iq_full),
        .empty(iq_empty),
        .*
    );
    
        

    decoder decode(
        .if_rd(iq_re),
        .instruction(iq_out.data),
        .pc(iq_out.pc),
        //output 
        // .valid(id_valid),
        .id_inst(id_inst),// this is struct
        .id_pc(id_pc),
        .rvfi(rvfi_1_1)
    );

    control_rom ctrlrom(
        .pc(id_pc),
        .instr(id_inst),
        .ctrl(ctrl),
        .rvfi_in (rvfi_1_1),
        .rvfi_out (rvfi_ctrl)
    );



    instruction_holdreg inst_reg(
        .flush(flush),
        .iq_re(iq_re),
        .dis_freeze(dis_freeze),
        .ctrl_in(ctrl),
        .ctrl_out(ctrl_out), 
        .rvfi_in (rvfi_ctrl),
        .rvfi_out (rvfi_1_2),
        .*
    );
    //**************** Rename & Dispatch Signal***********************
    rename rename_dispatch(
    //*******************input*********************
        //from decode
        
        .ctrl_in(ctrl_out),
        //ROB
        //full signal
        .rob_full(full_rob),
        //rds
        .rob_entry_valid(entry_valid),
        .rob_rds_entry(ROB_entry),
        //rs1/rs2
        .rob_r1_v(rs1_val),
        .rob_r2_v(rs2_val),
        .rob_r1_valid(rs1_valid),
        .rob_r2_valid(rs2_valid),
        .rob_rs1_entry(rs1_rob),
        .rob_rs2_entry(rs2_rob),
         // renaming input from REG_file, ROB, CDB
        //regfile, if busy bit = 0, valid = 1, use val
        .reg_r1_v(rs_out.r1_v),
        .reg_r2_v(rs_out.r2_v),
        .reg_r1_valid(rs_out.r1_valid),
        .reg_r2_valid(rs_out.r2_valid),
        //CDB
        .cdb1(alu_cdb),
        .cdb2(mul_cdb),
        .cdb3(cmp_cdb),
        .cdb4(load_cdb),
        //RS
        .rs_full1(full_rs1),
        .rs_full2(full_rs2),
        .rs_full3(full_rs3),
        .rs_full4(full_rs4), 
    //******************output********************
        //dispatch send to regfile
        //update rob entry
        .dispatch_rob_entry(dis_tag),
        .dispatch_rd_s(dis_rds),
        .dispatch_rs1_s(dis_r1s),
        .dispatch_rs2_s(dis_r2s),
        //rob
        .rob_opcode(dis_opcode),
        .rob_rds(dis_rds1),
        //other output signals
        .freeze(dis_freeze),
        .dispatch1(dispatch_1),
        .dispatch2(dispatch_2),
        .dispatch3(dispatch_3),
        .dispatch4(dispatch_4),
        .rs1(rs1),
        .rs2(rs2),
        .rs3(rs3),
        .rs4(rs4),
        .rvfi_in(rvfi_1_2),
        .rvfi_out1(rvfi_2_1),
        .rvfi_out2(rvfi_2_2),
        .rvfi_out3(rvfi_2_3),
        .rvfi_out4(rvfi_2_4), 
        .*
    );

    always_ff @(posedge clk) begin
        if (rst || flush)    dmem_work <= '0;
        else if (dmem_valid) dmem_work <= '1;
        else if (dmem_resp)  dmem_work <=  '0;
        else                 dmem_work <= dmem_work;
    end

    
   //***************** ROB signal ****************
    ROB    rob(
        .dmem_work(dmem_work),
        .lsq_store_commit(lsq_store_commit),
        .lsq_store_rvfi(mem_rvfi),
        .flush(flush),
        //input
        .rvfi_1(rvfi_alucdb),
        .rvfi_2(rvfi_mulcdb),
        .rvfi_3(rvfi_cmpcdb),
        .rvfi_4(rvfi_memcdb),
        //from dispatch
        .opcode(dis_opcode),
        .rds(dis_rds1),
        .dispatch(dispatch_),
        //from cdb
        .ROB_val1(alu_cdb.value), //ALU CDB
        .ROB_val2(mul_cdb.value), //MUL CDB
        .ROB_val3(cmp_cdb.value), //Br  CDB
        .ROB_val4(load_cdb.value), //Ld  CDB
        .br_en1(alu_cdb.br_en),
        .br_en2(mul_cdb.br_en),
        .br_en3(cmp_cdb.br_en),
        .br_en4(load_cdb.br_en),
        .br_target1(alu_cdb.br_target),
        .br_target2(mul_cdb.br_target),
        .br_target3(cmp_cdb.br_target),
        .br_target4(load_cdb.br_target),
        // .ROB_val4(load_cdb.value), //Ld  CDB
        .CDB_valid1(alu_cdb.valid),
        .CDB_valid2(mul_cdb.valid),
        .CDB_valid3(cmp_cdb.valid),
        .CDB_valid4(load_cdb.valid),
        .CDB_ROB1(alu_cdb.tag),
        .CDB_ROB2(mul_cdb.tag),
        .CDB_ROB3(cmp_cdb.tag),
        .CDB_ROB4(load_cdb.tag),
        // .CDB_ROB4(load_cdb.tag),
        // from reg file
        .rs1_renaming_rob(tag_out1),
        .rs2_renaming_rob(tag_out2),
        .tag1_valid(tag1_valid),
        .tag2_valid(tag2_valid),
        //output
        //send to dispatch
        .rs1_valid(rs1_valid),
        .rs2_valid(rs2_valid),
        .rs1_val(rs1_val),
        .rs2_val(rs2_val),
        .rs1_rob(rs1_rob),
        .rs2_rob(rs2_rob),
        //for rds renaming
        .entry_valid(entry_valid),
        .ROB_entry(ROB_entry),
        //for commit to regfile
        .commit_output(ROB_Reg), //This is struct
        .ready_(ready),
        .ROB_commit_tag(ROB_commit_tag),
        //if full, then freeze dispatch
        .full(full_rob),
        .empty(empty_rob),
        .rvfi_out(rvfi_rob),
        .*
    );

    always_ff @(posedge clk) begin 
        if(rst) begin
            order <= '0;
        end
        else if (ready ) begin
            order <= order + 'd1;
        end
        else begin
            order <= order;
        end
    end

    always_comb begin 
        if(rst || !ready) begin
            valid = 1'b0;
        end
        else if (ready ) begin
            valid = 1'b1;
        end
        else begin
            valid = rvfi_rob.valid;
        end
    end
    //*****************Regfile Signal*******************
    regfile  regfile(
        .flush(flush),
        //input, send from ROB
        .rdest(ROB_Reg), //this is struct
        .ROB_commit_tag(ROB_commit_tag),
        .ready(ready),
        //input, send from dispatch
        .dispatch(dispatch_),
        .rob_entry(dis_tag),
        .rs1_s(dis_r1s),
        .rs2_s(dis_r2s),
        .rd_s(dis_rds),
        //output to dispatch
        .rs_out(rs_out),
        //output to ROB
        .tag1_valid(tag1_valid),
        .tag2_valid(tag2_valid),
        .tag_out1(tag_out1),
        .tag_out2(tag_out2),
        //these three should be same cycle
        .br_addr(fetch_br_addr),
        .br_en(fetch_br_en),
        .commit_opcode(opcode),
        .bp_ready(bp_ready),
        .*
    );
    


    //********************Reservation station Signal********************
    //alu Reservation station
    rs        reservation1(
        .flush(flush),
        //input
        .rvfi_in (rvfi_2_1),
        .work(1'b0),
        .dispatch(dispatch_1),
        .aluop(rs1.aluop),
        .mulop(rs1.mulop),
        .cmpop(rs1.cmpop),
        .opcode(rs1.opcode),
        .rd_s(dis_rds),
        .rs1_rob(rs1.rs1_rob),
        .rs2_rob(rs1.rs2_rob),
        .rob_entry(rs1.rob_entry),
        .busy_1(rs1.busy_1),
        .busy_2(rs1.busy_2),
        .r1_v(rs1.r1_v),
        .r2_v(rs1.r2_v),
        .pc(rs1.pc),
        .imm(rs1.imm),
        .CDB_1(alu_cdb.value),
        .CDB_2(mul_cdb.value),
        .CDB_3(cmp_cdb.value),
        .CDB_4(load_cdb.value),
        .CDB1_valid(alu_cdb.valid),
        .CDB2_valid(mul_cdb.valid),
        .CDB3_valid(cmp_cdb.valid),
        .CDB4_valid(load_cdb.valid),
        .CDB1_rob(alu_cdb.tag),
        .CDB2_rob(mul_cdb.tag),
        .CDB3_rob(cmp_cdb.tag),
        .CDB4_rob(load_cdb.tag),
        //output
        .full(full_rs1),
        .empty(empty_rs1),
        .output_valid(output_valid1),
        .rs_out(rs_out1), // rs_out1 is for rs ! We have same struct with regfile rs_out
        .rvfi_out(rvfi_3_1),
        .*
    );
    //Mul Reservation Station
    rs        reservation2(
        .flush(flush),
        //input
        .rvfi_in (rvfi_2_2),
        .work(work),
        .dispatch(dispatch_2),
        .aluop(rs2.aluop),
        .mulop(rs2.mulop),
        .cmpop(rs2.cmpop),
        .opcode(rs2.opcode),
        .rd_s(dis_rds),
        .rs1_rob(rs2.rs1_rob),
        .rs2_rob(rs2.rs2_rob),
        .rob_entry(rs2.rob_entry),
        .busy_1(rs2.busy_1),
        .busy_2(rs2.busy_2),
        .r1_v(rs2.r1_v),
        .r2_v(rs2.r2_v),
        .pc(rs2.pc),
        .imm(rs2.imm),
        .CDB_1(alu_cdb.value),
        .CDB_2(mul_cdb.value),
        .CDB_3(cmp_cdb.value),
        .CDB_4(load_cdb.value),
        .CDB1_valid(alu_cdb.valid),
        .CDB2_valid(mul_cdb.valid),
        .CDB3_valid(cmp_cdb.valid),
        .CDB4_valid(load_cdb.valid),
        .CDB1_rob(alu_cdb.tag),
        .CDB2_rob(mul_cdb.tag),
        .CDB3_rob(cmp_cdb.tag),
        .CDB4_rob(load_cdb.tag),
        //output
        .full(full_rs2),
        .empty(empty_rs2),
        .output_valid(output_valid2),
        .rs_out(rs_out2),
        .rvfi_out(rvfi_3_2),
        .*
    );
    rs        reservation3(
        .flush(flush),
        //input
        .rvfi_in (rvfi_2_3),
        .work(1'b0),
        .dispatch(dispatch_3),
        .aluop(rs3.aluop),
        .mulop(rs3.mulop),
        .cmpop(rs3.cmpop),
        .opcode(rs3.opcode),
        .rd_s(dis_rds),
        .rs1_rob(rs3.rs1_rob),
        .rs2_rob(rs3.rs2_rob),
        .rob_entry(rs3.rob_entry),
        .busy_1(rs3.busy_1),
        .busy_2(rs3.busy_2),
        .r1_v(rs3.r1_v),
        .r2_v(rs3.r2_v),
        .pc(rs3.pc),
        .imm(rs3.imm),
        .CDB_1(alu_cdb.value),
        .CDB_2(mul_cdb.value),
        .CDB_3(cmp_cdb.value),
        .CDB_4(load_cdb.value),
        .CDB1_valid(alu_cdb.valid),
        .CDB2_valid(mul_cdb.valid),
        .CDB3_valid(cmp_cdb.valid),
        .CDB4_valid(load_cdb.valid),
        .CDB1_rob(alu_cdb.tag),
        .CDB2_rob(mul_cdb.tag),
        .CDB3_rob(cmp_cdb.tag),
        .CDB4_rob(load_cdb.tag),
        //output
        .full(full_rs3),
        .empty(empty_rs3),
        .output_valid(output_valid3),
        .rs_out(rs_out3), // rs_out1 is for rs ! We have same struct with regfile rs_out
        .rvfi_out(rvfi_3_3),
        .*
    );
    
    // always_ff @(posedge clk) begin
    //     if (rst)    dmem_work <= '0;
    //     else if (dmem_valid) dmem_work <= '1;
    //     else if (dmem_resp)  dmem_work <=  '0;
    //     else                 dmem_work <= dmem_work;
    // end
    //******************Load Store queue****************
    lsq lsq_(
        //input
        .flush(flush),
        .clk(clk),
        .rst(rst),
        //from dispatch
        .dispatch(dispatch_4),
        .disptach_pack(rs4),
        //from cdb
        .alu_cdb(alu_cdb),
        .mul_cdb(mul_cdb),
        .cmp_cdb(cmp_cdb),
        .mem_cdb(load_cdb),  
        //from rob for store execution
        //input
        .rob_opcode(ROB_Reg.opcode),
        .rob_rds(ROB_Reg.rds),
        //output
        .store_commit(lsq_store_commit),
        //memory unit
        //input
        .dmem_work(dmem_work),
        //ouput
        .dmem_valid(dmem_valid),
        .dmem_out(dmem_out),
        //forwarding
        //output
        .forward_cdb(forward_cdb_out_lsq),
        .forward_out(forward_out),
        .forward_valid(forward_valid),
        //full empty
        .full(full_rs4),
        .empty(empty_rs4),
        //rvfi_signal
        .rvfi_in(rvfi_2_4),
        .rvfi_out_dmem(rvfi_3_4),
        .rvfi_out_forward(rvfi_3_5)
        ); 

        //deque
        data_mem data_mem_deque(
            //input
            .flush(mem_flush), //from regfile
            .dmem_in(dmem_out), 
            .dmem_valid(dmem_valid),
            //output to D-cache
            .dmem_addr(dmem_addr),
            .dmem_rmask(dmem_rmask),
            .dmem_wmask(dmem_wmask),
            .dmem_wdata(dmem_wdata),
            //rvfi signal 
            .rvfi_in(rvfi_3_4),
            .rvfi_out(mem_rvfi)
            );

        always_ff @( posedge clk ) begin 
            if (rst || flush) begin
                dmem_addr_tmp       <= '0;
                dmem_rmask_tmp      <= '0;
                dmem_wmask_tmp      <= '0;
                dmem_wdata_tmp      <= '0;
            end
            else if (dmem_valid) begin
                dmem_addr_tmp       <= dmem_addr;
                dmem_rmask_tmp      <= dmem_rmask;
                dmem_wmask_tmp      <= dmem_wmask;
                dmem_wdata_tmp      <= dmem_wdata;
            end
            else if (dmem_resp) begin
                dmem_addr_tmp       <= '0;
                dmem_rmask_tmp      <= '0;
                dmem_wmask_tmp      <= '0;
                dmem_wdata_tmp      <= '0;
            end
            else begin
                dmem_addr_tmp       <= dmem_addr_tmp;
                dmem_rmask_tmp      <= dmem_rmask_tmp;
                dmem_wmask_tmp      <= dmem_wmask_tmp;
                dmem_wdata_tmp      <= dmem_wdata_tmp;
            end

        end

        always_ff @( posedge clk ) begin 
            if (rst || flush) begin
                rvfi_3_5_tmp <= '0;
                forward_cdb_out_lsq_tmp <= '0;
                forward_out_tmp <= '0;
                forward_valid_tmp <= '0;
                dmem_wdata_tmp2 <= '0;
            end
            else begin
                rvfi_3_5_tmp <= rvfi_3_5;
                forward_cdb_out_lsq_tmp <= forward_cdb_out_lsq;
                forward_out_tmp <= forward_out;
                forward_valid_tmp <= forward_valid;
                dmem_wdata_tmp2 <= dmem_wdata;
            end
        end
        // data_mem_forward data_mem_forward_(
        //     //input
        //     .rvfi_in(rvfi_3_5),
        //     .forward_cdb_in(forward_cdb_out_lsq),
        //     .dmem_in(forward_out),
        //     .dmem_valid(forward_valid),
        //     .dmem_wdata(dmem_wdata),
        //     //output
        //     .forward_cdb(forward_cdb_out),
        //     //rvfi_signal
            
        //     .rvfi_out(forward_mem_rvfi)
        // );
        data_mem_forward data_mem_forward_(
            //input
            .rvfi_in(rvfi_3_5_tmp),
            .forward_cdb_in(forward_cdb_out_lsq_tmp),
            .dmem_in(forward_out_tmp),
            .dmem_valid(forward_valid_tmp),
            .dmem_wdata(dmem_wdata_tmp2),
            //output
            .forward_cdb(forward_cdb_out),
            //rvfi_signal
            
            .rvfi_out(forward_mem_rvfi)
        );
    logic   [31:0] cdb_load_value;
    logic	[3:0]  cdb_load_tag;
    logic   cdb_load_valid;
    rvfi_data   cdb_load_rvfi;

    // logic   [31:0] tmp_load_value;
    logic	[3:0]  tmp_load_tag;
    rvfi_data   tmp_load_rvfi;
    logic   [6:0]   tmp_opcode;
    logic   [2:0]   tmp_funct3;
    logic   [31:0]  tmp_addr;

    // assign  cdb_load_valid = forward_valid || dmem_resp;

    always_ff @( posedge clk ) begin
        if (rst || flush) begin
            tmp_load_tag    <=  '0;
            tmp_load_rvfi   <=  '0;
            tmp_opcode      <=  '0;
            tmp_funct3      <=  '0;
            tmp_addr        <=  '0;
        end
        if (dmem_valid) begin
            tmp_load_tag    <=  dmem_out.rob_entry;
            tmp_load_rvfi   <=  mem_rvfi;
            tmp_opcode      <=  dmem_out.opcode;
            tmp_funct3      <=  dmem_out.funct3;
            tmp_addr        <=  dmem_out.dmem_addr;
        end
        else begin
            tmp_load_tag    <=  tmp_load_tag;
            tmp_load_rvfi   <=  tmp_load_rvfi;
            tmp_opcode      <=  tmp_opcode;
            tmp_funct3      <=  tmp_funct3;
            tmp_addr        <=  tmp_addr;
        end
    end

        always_comb begin
        
        if (forward_valid_tmp) begin
            cdb_load_tag    = forward_cdb_out.tag;
            cdb_load_value  = forward_cdb_out.value;
            cdb_load_valid  = 1'b0;
            cdb_load_rvfi   = forward_mem_rvfi;
        end
        else if (dmem_resp && (tmp_opcode == op_load))  begin
            cdb_load_tag    = tmp_load_tag;
            cdb_load_value  = dmem_rdata;
            cdb_load_valid  = 1'b1;
            cdb_load_rvfi   = tmp_load_rvfi;
        end
        else begin
            cdb_load_tag    = '0;
            cdb_load_value  = '0;
            cdb_load_valid  = '0;
            cdb_load_rvfi   = '0;
        end
    end


    cdb_load cdb_load(
        .tmp_funct3(tmp_funct3),
        .tmp_addr(tmp_addr),
        .forward_valid(forward_valid_tmp),
        .cdb_load_valid(cdb_load_valid),
        .tag_load(cdb_load_tag),
        .value_load(cdb_load_value),
        .load_out(load_cdb),
        .rvfi_in(cdb_load_rvfi),
        .rvfi_out(rvfi_memcdb),         
        .*
    );


    // always_comb begin
        
    //     if (forward_valid) begin
    //         cdb_load_tag    = forward_cdb_out.tag;
    //         cdb_load_value  = forward_cdb_out.value;
    //         cdb_load_valid  = 1'b0;
    //         cdb_load_rvfi   = forward_mem_rvfi;
    //     end
    //     else if (dmem_resp && (tmp_opcode == op_load))  begin
    //         cdb_load_tag    = tmp_load_tag;
    //         cdb_load_value  = dmem_rdata;
    //         cdb_load_valid  = 1'b1;
    //         cdb_load_rvfi   = tmp_load_rvfi;
    //     end
    //     else begin
    //         cdb_load_tag    = '0;
    //         cdb_load_value  = '0;
    //         cdb_load_valid  = '0;
    //         cdb_load_rvfi   = '0;
    //     end
    // end


    // cdb_load cdb_load(
    //     .tmp_funct3(tmp_funct3),
    //     .tmp_addr(tmp_addr),
    //     .forward_valid(forward_valid),
    //     .cdb_load_valid(cdb_load_valid),
    //     .tag_load(cdb_load_tag),
    //     .value_load(cdb_load_value),
    //     .load_out(load_cdb),
    //     .rvfi_in(cdb_load_rvfi),
    //     .rvfi_out(rvfi_memcdb),         
    //     .*
    // );


    
    //CDB 4 modules
    alu alu(
        .rvfi_in(rvfi_3_1),
        .ready(output_valid1),
        .alu_opcode(rs_out1.aluop),
        .a(rs_out1.r1_v),
        .b(rs_out1.r2_v),
        .tag_rs(rs_out1.rob_entry),
        .rvfi_out(rvfi_alu),
        .out(alu_out) // this is struct
    );
    cdb_alu cdbalu(
        .rvfi_in(rvfi_alu),
        .valid_alu(alu_out.valid),
        .tag_alu(alu_out.tag),
        .value_alu(alu_out.value),
        .rvfi_out(rvfi_alucdb),
        .alu_out(alu_cdb) // this is struct
    );
    bit m ;
    logic [1:0] mul_typeop, mul_typeop_buffer;
    logic start_buffer;
    logic [31:0] mul_a, mul_b;
    always_ff@(posedge clk) begin
        if(output_valid2) begin
            m<=1'b1;
        end
        else if(done) begin
            m<=1'b0;
        end
    end
    always_ff@(posedge clk) begin
        if(m) mul_typeop_buffer <= mul_typeop_buffer;
        else
            mul_typeop_buffer <= rs_out2.mulop;
    end

    always_comb begin
        if (m) mul_typeop = mul_typeop_buffer;
        else mul_typeop = rs_out2.mulop;
    end
    

 
    shift_add_multiplier shift_add_multiplier(
        //input
        .start(output_valid2),
        .mul_type(mul_typeop),
        .a(rs_out2.r1_v),
        .b(rs_out2.r2_v),
        //output
        .p(mul_value),
        .done(done),
        .work(work),
        .*
    );  
    
    rvfi_data rvfi_mul_0;
    
    //tag is wrong, output tag uses the next mul's tag (its combinational)
    logic [3:0] cdb_mul_tag;

    always_ff @(posedge clk) begin
        if (rst) begin
            rvfi_mul_0 <= '0;
            cdb_mul_tag <= '0;
            rvfi_mul_0.r1_rdata <= '0;
            rvfi_mul_0.r2_rdata <= '0;
        end
        else if (work) begin
        cdb_mul_tag <= cdb_mul_tag;
        rvfi_mul_0 <= rvfi_mul_0;
        rvfi_mul_0.r1_rdata <= rvfi_mul_0.r1_rdata ;
        rvfi_mul_0.r2_rdata <= rvfi_mul_0.r2_rdata;
        end
        else if (output_valid2) begin
        cdb_mul_tag <= rs_out2.rob_entry;
        rvfi_mul_0 <= rvfi_3_2;
        rvfi_mul_0.r1_rdata <= rs_out2.r1_v;
        rvfi_mul_0.r2_rdata <= rs_out2.r2_v;
        end
        else begin 
        cdb_mul_tag <= 'x;
        rvfi_mul_0 <= '0;
        rvfi_mul_0.r1_rdata <= '0;
        rvfi_mul_0.r2_rdata <= '0;
        end
        end
    
 
    mul mul_1(
        .rvfi_in(rvfi_mul_0),
        .done(done),
        .mulop(mul_typeop),
        .p(mul_value),
        //output 32bits MUL operation value
        .mulout(mulout),
        .rvfi_out(rvfi_mulval)
    );

    cdb_mul cdbmul(
        .rvfi_in(rvfi_mulval),
        .valid_mul(done),
        //.tag_mul(mul_tag),
        .tag_mul(cdb_mul_tag),
        .value_mul(mulout),
        .rvfi_out(rvfi_mulcdb),
        .mul_out(mul_cdb) // this is struct
    );

   

    cmp cmp_1(
        .cmp_opcode(rs_out3.cmpop),
        .op_code(rs_out3.opcode),
        .a(rs_out3.r1_v),
        .b(rs_out3.r2_v),
        .rvfi_in(rvfi_3_3),
        .pc(rs_out3.pc),
        .imm_out(rs_out3.imm),
        .tag_rs(rs_out3.rob_entry),
        .ready(output_valid3),
        .rvfi_out(rvfi_cmp),
        .out(cmp_out)
    );

    cdb_cmp cdbcmp(
        .rvfi_in(rvfi_cmp),
        .valid_cmp(cmp_out.valid),
        .br_value(cmp_out.value),
        .br_en(cmp_out.br_en),
        .br_target(cmp_out.br_target),
        .tag_cmp(cmp_out.tag),
        .rvfi_out(rvfi_cmpcdb),
        .cmp_out(cmp_cdb) // this is struct
    );




    
    
    endmodule : cpu