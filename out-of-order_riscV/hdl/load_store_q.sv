module lsq import rv32i_types::*;
    #(
        parameter    size_     = 8,
        localparam   ptr_      = $clog2(size_) 
    )(
        input   logic           flush,
        input   logic           clk,
        input   logic           rst,

        //from dispatch
        input   logic           dispatch,           //enque signal
        input   rs_t            disptach_pack,

        //snoop from cdb
        input   cdb_t           alu_cdb,
        input   cdb_t           mul_cdb,
        input   cdb_t           cmp_cdb,
        input   cdb_t           mem_cdb,

        //from rob for store execution
        input   logic   [6:0]   rob_opcode,         //check if the top of rob is a store, if yes fire store from lsq
        input   logic   [4:0]   rob_rds,
        output  logic           store_commit,       //this sets the commit signal in rob to 1
        
        //memory unit
        input   logic           dmem_work,
        output  logic           dmem_valid,         //dmem_value_valid && dmem_wdata_valid
        output  lsq_t           dmem_out,            

        //forwarding
        output  cdb_t           forward_cdb,
        output  lsq_t           forward_out,
        output  logic           forward_valid,         

        output logic          full,
        output logic          empty,

        //rvfi signal
        input rvfi_data rvfi_in,
        output rvfi_data rvfi_out_dmem,
        output rvfi_data rvfi_out_forward
    );
    /////////////////////////////////////////////
    logic               load_ready, store_ready;
    logic               deque_sig, enque_sig;
    logic               forward_sel;
    // logic   [ptr_-1:0]  forward_idx;
    int                 forward_idx;
    /////////////////////////////////////////////


    rvfi_data rvfi[size_];
    lsq_t mem[size_];
    logic [ptr_-1:0] wrPtr, wrPtrNext;              //head

    //empty = mem[0] not taken && wrptr at top
    assign empty = (!mem[0].taken && (wrPtr == 3'b000));
    //full = mem[last]
    assign full  = (mem[7].taken && (wrPtr == 3'b111));

    //determine if my first store is ready (if frist is store)
    assign store_ready = (mem[0].opcode == op_store) && mem[0].dmem_value_valid && mem[0].dmem_wdata_valid && (rob_opcode == op_store) && (mem[0].rds == rob_rds);
    //determine if my first load  is ready (if frist is load )
    assign load_ready  = (mem[0].opcode == op_load)  && mem[0].dmem_value_valid ;


    //update write pointer////////////////////////////////////////////////
    always_comb begin 
        
        //default keep same
        wrPtrNext = wrPtr;
        forward_sel = '0;
        forward_idx = '0;
        deque_sig   = '0;
        enque_sig   = '0;

        

        //case 1 : if only dispatch (enque)
        if (disptach_pack.opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
            if (!full && dispatch && !flush) begin
                if (wrPtr == 3'b111) wrPtrNext = wrPtr;
                else                    wrPtrNext = wrPtr + 1'b1;
                enque_sig = '1;
            end
        end

        //case 2 : if only deque first store/load
        if (!dmem_work && !empty) begin
            if (load_ready || store_ready) begin
                deque_sig = '1;
                if(full) wrPtrNext = wrPtr;
                else     wrPtrNext = wrPtr - 1'b1;
            end
        end

        //case 3 : if deque and dispatch at the same time
        if (enque_sig && deque_sig) wrPtrNext = wrPtr;

        //case 4 : if store deque + forwarding (forwarding only happens when first st deques)
        if (store_ready && deque_sig) begin
            for (int i=1; i<size_; i++) begin
                //if find empty entry, means you reached end -> break for loop
                if(!mem[i].taken || (mem[i].opcode == op_store)) break;

                else if (mem[i].opcode == op_load) begin
                    
                    //check if addr_match
                    if((mem[i].dmem_addr == mem[0].dmem_addr) && mem[i].dmem_value_valid) begin
                        forward_sel = 1'b1;
                        forward_idx = i;
                        if (full)   wrPtrNext = wrPtr - 3'h1;           //wrptr - 1
                        else        wrPtrNext = wrPtr - 3'h2;           //wrptr - 2
                        break;
                    end
                end
            end
        end

        //case 5 : if deque and forward and dispatch
        if (enque_sig && deque_sig && forward_sel) begin
            if (full)   wrPtrNext = wrPtr;
            else        wrPtrNext = wrPtr - 1'b1;
        end

        if (flush) wrPtrNext = '0;
        
    end
    ////////////////////////////////////////////////////////////////////////////////////
    

    logic f1, f2, f3, f4;
    //update values/////////////////////////////////////////////////////////////////////
    always_ff @( posedge clk ) begin 
        //default
        mem[wrPtr] <= mem[wrPtr];
        rvfi[wrPtr] <=  rvfi[wrPtr];
        f1 <= '0;
        f2 <= '0;
        f3 <= '0;
        f4 <= '0;



        if (rst || flush) begin
          for(int i = 0; i<size_; i++) begin
            mem[i] <= '0;
            rvfi[i] <= '0;
          end
        end
        
        //perform collapse
        //if both deque and forward
        if(deque_sig && forward_sel) begin
            for(int i = 0; i<(size_-1); i++) begin
                //before you hit forward index
                if(i < (forward_idx- 1)) begin
                    mem[i] <= mem[i+1];
                    rvfi[i] <= rvfi[i+1];
                end
                //after you reach forward index
                else begin
                    if (i+2 <= size_-1) begin
                        mem[i] <= mem[i+2];
                        rvfi[i] <= rvfi[i+2];
                    end
                    else    break;
                end
            end
        end

        //only deque, no forwarding
        else if (deque_sig) begin
            for(int i = 0; i<(size_-1); i++) begin
                mem[i] <= mem[i+1];
                rvfi[i] <= rvfi[i+1];
            end
        end

        //clear unneeded row
        if (deque_sig && forward_sel)   begin
            mem[wrPtrNext]      <= '0;
            mem[wrPtrNext +1]   <= '0;
            rvfi[wrPtrNext]      <= '0;
            rvfi[wrPtrNext +1]   <= '0;
        end
        else if (deque_sig) begin
            mem[wrPtrNext]      <= '0;
            rvfi[wrPtrNext]      <= '0;
        end

        // write new values if deque
        if (disptach_pack.opcode inside {op_load, op_store}) begin
            if (enque_sig && deque_sig && forward_sel && !flush) begin
                mem[wrPtr -2].opcode        <= disptach_pack.opcode;
                mem[wrPtr -2].rs1_rob       <= disptach_pack.rs1_rob;
                mem[wrPtr -2].rs2_rob       <= disptach_pack.rs2_rob;
                mem[wrPtr -2].busy_1        <= disptach_pack.busy_1;    
                mem[wrPtr -2].busy_2        <= disptach_pack.busy_2;
                mem[wrPtr -2].r1_v          <= disptach_pack.r1_v;
                mem[wrPtr -2].r2_v          <= disptach_pack.r2_v;
                mem[wrPtr -2].taken         <= 1'b1;
                mem[wrPtr -2].rds           <= disptach_pack.rds;
                mem[wrPtr -2].rob_entry     <= disptach_pack.rob_entry;
                mem[wrPtr -2].dmem_addr     <= (!disptach_pack.busy_1) ? (disptach_pack.r1_v + disptach_pack.imm) : 0;
                mem[wrPtr -2].dmem_value_valid    <= (!disptach_pack.busy_1);
                mem[wrPtr -2].funct3        <= disptach_pack.funct3;
                mem[wrPtr -2].imm           <= disptach_pack.imm;
                // if (disptach_pack.opcode == op_load) begin
                //     mem[wrPtr -2].dmem_rdata        <= disptach_pack.;                                          //not sure
                // end
                if (disptach_pack.opcode == op_store) begin
                    mem[wrPtr -2].dmem_wdata        <= (!disptach_pack.busy_2) ? (disptach_pack.r2_v) : 0;
                    mem[wrPtr -2].dmem_wdata_valid        <= (!disptach_pack.busy_2);
                end
                
                rvfi[wrPtr -2]  <= rvfi_in;
            end
            else if (enque_sig && deque_sig && !flush) begin
                mem[wrPtr -1].opcode        <= disptach_pack.opcode;
                mem[wrPtr -1].rs1_rob       <= disptach_pack.rs1_rob;
                mem[wrPtr -1].rs2_rob       <= disptach_pack.rs2_rob;
                mem[wrPtr -1].busy_1        <= disptach_pack.busy_1;    
                mem[wrPtr -1].busy_2        <= disptach_pack.busy_2;
                mem[wrPtr -1].r1_v          <= disptach_pack.r1_v;
                mem[wrPtr -1].r2_v          <= disptach_pack.r2_v;
                mem[wrPtr -1].taken         <= 1'b1;
                mem[wrPtr -1].rds           <= disptach_pack.rds;
                mem[wrPtr -1].rob_entry     <= disptach_pack.rob_entry;
                mem[wrPtr -1].dmem_addr     <= (!disptach_pack.busy_1 ) ? (disptach_pack.r1_v + disptach_pack.imm) : 0;
                mem[wrPtr -1].dmem_value_valid    <= (!disptach_pack.busy_1);
                mem[wrPtr -1].funct3        <= disptach_pack.funct3;
                mem[wrPtr -1].imm           <= disptach_pack.imm;
                // if (disptach_pack.opcode == op_load) begin
                //     mem[wrPtr -1].dmem_rdata        <= disptach_pack.;                                          //not sure
                // end
                if (disptach_pack.opcode == op_store) begin
                    mem[wrPtr -1].dmem_wdata        <= (!disptach_pack.busy_2) ? (disptach_pack.r2_v) : 0;
                    mem[wrPtr -1].dmem_wdata_valid        <= (!disptach_pack.busy_2);
                end

                rvfi[wrPtr -1]  <= rvfi_in;

            end
            else if (enque_sig) begin
                mem[wrPtr ].opcode        <= disptach_pack.opcode;
                mem[wrPtr ].rs1_rob       <= disptach_pack.rs1_rob;
                mem[wrPtr ].rs2_rob       <= disptach_pack.rs2_rob;
                // mem[wrPtr ].busy_1        <= disptach_pack.busy_1;    
                // mem[wrPtr ].busy_2        <= disptach_pack.busy_2;
                // mem[wrPtr ].r1_v          <= disptach_pack.r1_v;
                // mem[wrPtr ].r2_v          <= disptach_pack.r2_v;
                mem[wrPtr ].taken         <= 1'b1;
                mem[wrPtr ].rds           <= disptach_pack.rds;
                mem[wrPtr ].rob_entry     <= disptach_pack.rob_entry;
                mem[wrPtr ].dmem_addr     <= (!disptach_pack.busy_1) ? (disptach_pack.r1_v + disptach_pack.imm) : 0;
                mem[wrPtr ].dmem_value_valid    <= (!disptach_pack.busy_1);
                mem[wrPtr ].funct3        <= disptach_pack.funct3;
                mem[wrPtr ].imm           <= disptach_pack.imm;
                // if (disptach_pack.opcode == op_load) begin
                //     mem[wrPtr ].dmem_rdata        <= disptach_pack.;                                          //not sure
                // end
                if (disptach_pack.opcode == op_store) begin
                    mem[wrPtr ].dmem_wdata        <= (!disptach_pack.busy_2) ? (disptach_pack.r2_v) : 0;
                    mem[wrPtr ].dmem_wdata_valid        <= (!disptach_pack.busy_2);
                end


                // r1_v
                if (!disptach_pack.busy_1) begin
                mem[wrPtr ].busy_1       <= disptach_pack.busy_1;
                mem[wrPtr ].r1_v         <= disptach_pack.r1_v;
                end
                else if (disptach_pack.busy_1 && alu_cdb.valid && !flush && disptach_pack.rs1_rob == alu_cdb.tag) begin
                mem[wrPtr ].busy_1       <= 1'b0;
                mem[wrPtr ].r1_v         <= alu_cdb.value;
                end
                else if (disptach_pack.busy_1 && mul_cdb.valid && !flush && disptach_pack.rs1_rob == mul_cdb.tag) begin
                mem[wrPtr ].busy_1       <= 1'b0;
                mem[wrPtr ].r1_v         <= mul_cdb.value;
                end
                else if (disptach_pack.busy_1 && cmp_cdb.valid && !flush && disptach_pack.rs1_rob == cmp_cdb.tag) begin
                mem[wrPtr ].busy_1       <= 1'b0;
                mem[wrPtr ].r1_v         <= cmp_cdb.value;
                end
                else if (disptach_pack.busy_1 && mem_cdb.valid && !flush && disptach_pack.rs1_rob == mem_cdb.tag) begin
                mem[wrPtr ].busy_1       <= 1'b0;
                mem[wrPtr ].r1_v         <= mem_cdb.value;
                end
                else begin
                mem[wrPtr ].busy_1       <= disptach_pack.busy_1;
                mem[wrPtr ].r1_v         <= disptach_pack.r1_v;
                end

                // r2v
                if (!disptach_pack.busy_2) begin
                mem[wrPtr ].busy_2       <= disptach_pack.busy_2;
                mem[wrPtr ].r2_v         <= disptach_pack.r2_v;
                end
                else if (disptach_pack.busy_2 && alu_cdb.valid && !flush && disptach_pack.rs2_rob == alu_cdb.tag) begin
                mem[wrPtr ].busy_2       <= 1'b0;
                mem[wrPtr ].r2_v         <= alu_cdb.value;
                end
                else if (disptach_pack.busy_2 && mul_cdb.valid && !flush && disptach_pack.rs2_rob == mul_cdb.tag) begin
                mem[wrPtr ].busy_2       <= 1'b0;
                mem[wrPtr ].r2_v         <= mul_cdb.value;
                end
                else if (disptach_pack.busy_2 && cmp_cdb.valid && !flush && disptach_pack.rs2_rob == cmp_cdb.tag) begin
                mem[wrPtr ].busy_2       <= 1'b0;
                mem[wrPtr ].r2_v         <= cmp_cdb.value;
                end
                else if (disptach_pack.busy_2 && mem_cdb.valid && !flush && disptach_pack.rs2_rob == mem_cdb.tag) begin
                mem[wrPtr ].busy_2       <= 1'b0;
                mem[wrPtr ].r2_v         <= mem_cdb.value;
                end
                else begin
                mem[wrPtr ].busy_2       <= disptach_pack.busy_2;
                mem[wrPtr ].r2_v         <= disptach_pack.r2_v;
                end



                rvfi[wrPtr ]  <= rvfi_in;
            end
        end


        //update dmem_addr and dmem_value_valid
        /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //CDB1/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        if(alu_cdb.valid && !flush) begin
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == alu_cdb.tag)) begin
                    f1 <= '1;
                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r1_v   <=   alu_cdb.value;
                        mem[i-1].busy_1 <=   1'b0;


                        mem[i-1].dmem_addr    <=  alu_cdb.value + mem[i].imm;
                        mem[i-1].dmem_value_valid   <=  1'b1;
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r1_v   <=   alu_cdb.value;
                            mem[i-2].busy_1 <=   1'b0;


                            mem[i-2].dmem_addr    <=  alu_cdb.value + mem[i].imm;
                            mem[i-2].dmem_value_valid   <=  1'b1;
                        end
                    
                        else if (i >= 1)begin
                            mem[i -1].r1_v   <=   alu_cdb.value;
                            mem[i -1].busy_1 <=   1'b0;


                            mem[i -1].dmem_addr    <=  alu_cdb.value + mem[i].imm;
                            mem[i -1].dmem_value_valid   <=  1'b1;
                        end
                    end

                    else begin
                        mem[i].r1_v   <=   alu_cdb.value;
                        mem[i].busy_1 <=   1'b0;


                        mem[i].dmem_addr    <=  alu_cdb.value + mem[i].imm;
                        mem[i].dmem_value_valid   <=  1'b1;
                    end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == alu_cdb.tag)) begin
                    f2 <= '1;

                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r2_v   <=   alu_cdb.value;
                        mem[i-1].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i-1].dmem_wdata    <=  alu_cdb.value;
                            mem[i-1].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r2_v   <=   alu_cdb.value;
                            mem[i-2].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-2].dmem_wdata    <=  alu_cdb.value;
                                mem[i-2].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                        else if (i >= 1)begin
                            mem[i-1].r2_v   <=   alu_cdb.value;
                            mem[i-1].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-1].dmem_wdata    <=  alu_cdb.value;
                                mem[i-1].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                    end

                    else begin
                        mem[i].r2_v   <=   alu_cdb.value;
                        mem[i].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i].dmem_wdata    <=  alu_cdb.value;
                            mem[i].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                end
            end
        end   


        ///////////////////////////////////////////////////////////////////////////////////////////////////////////
        //CDB2/////////////////////////////////////////////////////////////////////////////////////////////////////
        if(mul_cdb.valid && !flush) begin
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == mul_cdb.tag)) begin
                    // f1 <= '1;
                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r1_v   <=   mul_cdb.value;
                        mem[i-1].busy_1 <=   1'b0;


                        mem[i-1].dmem_addr    <=  mul_cdb.value + mem[i].imm;
                        mem[i-1].dmem_value_valid   <=  1'b1;
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r1_v   <=   mul_cdb.value;
                            mem[i-2].busy_1 <=   1'b0;


                            mem[i-2].dmem_addr    <=  mul_cdb.value + mem[i].imm;
                            mem[i-2].dmem_value_valid   <=  1'b1;
                        end
                    
                        else if (i >= 1) begin
                            mem[i -1].r1_v   <=   mul_cdb.value;
                            mem[i -1].busy_1 <=   1'b0;


                            mem[i -1].dmem_addr    <=  mul_cdb.value + mem[i].imm;
                            mem[i -1].dmem_value_valid   <=  1'b1;
                        end
                    end

                    else begin
                        mem[i].r1_v   <=   mul_cdb.value;
                        mem[i].busy_1 <=   1'b0;


                        mem[i].dmem_addr    <=  mul_cdb.value + mem[i].imm;
                        mem[i].dmem_value_valid   <=  1'b1;
                    end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == mul_cdb.tag)) begin
                    // f2 <= '1;
                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r2_v   <=   mul_cdb.value;
                        mem[i-1].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i-1].dmem_wdata    <=  mul_cdb.value;
                            mem[i-1].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r2_v   <=   mul_cdb.value;
                            mem[i-2].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-2].dmem_wdata    <=  mul_cdb.value;
                                mem[i-2].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                        else if (i >= 1)begin
                            mem[i-1].r2_v   <=   mul_cdb.value;
                            mem[i-1].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-1].dmem_wdata    <=  mul_cdb.value;
                                mem[i-1].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                    end

                    else begin
                        mem[i].r2_v   <=   mul_cdb.value;
                        mem[i].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i].dmem_wdata    <=  mul_cdb.value;
                            mem[i].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                end
            end
        end  


        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //CDB3//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        if(cmp_cdb.valid && !flush) begin
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == cmp_cdb.tag)) begin
                    f1 <= '1;
                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r1_v   <=   cmp_cdb.value;
                        mem[i-1].busy_1 <=   1'b0;


                        mem[i-1].dmem_addr    <=  cmp_cdb.value + mem[i].imm;
                        mem[i-1].dmem_value_valid   <=  1'b1;
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r1_v   <=   cmp_cdb.value;
                            mem[i-2].busy_1 <=   1'b0;


                            mem[i-2].dmem_addr    <=  cmp_cdb.value + mem[i].imm;
                            mem[i-2].dmem_value_valid   <=  1'b1;
                        end
                    
                        else if (i >= 1)begin
                            mem[i -1].r1_v   <=   cmp_cdb.value;
                            mem[i -1].busy_1 <=   1'b0;


                            mem[i -1].dmem_addr    <=  cmp_cdb.value + mem[i].imm;
                            mem[i -1].dmem_value_valid   <=  1'b1;
                        end
                    end

                    else begin
                        mem[i].r1_v   <=   cmp_cdb.value;
                        mem[i].busy_1 <=   1'b0;


                        mem[i].dmem_addr    <=  cmp_cdb.value + mem[i].imm;
                        mem[i].dmem_value_valid   <=  1'b1;
                    end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == cmp_cdb.tag)) begin
                    f2 <= '1;

                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r2_v   <=   cmp_cdb.value;
                        mem[i-1].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i-1].dmem_wdata    <=  cmp_cdb.value;
                            mem[i-1].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r2_v   <=   cmp_cdb.value;
                            mem[i-2].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-2].dmem_wdata    <=  cmp_cdb.value;
                                mem[i-2].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                        else if (i >= 1)begin
                            mem[i-1].r2_v   <=   cmp_cdb.value;
                            mem[i-1].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-1].dmem_wdata    <=  cmp_cdb.value;
                                mem[i-1].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                    end

                    else begin
                        mem[i].r2_v   <=   cmp_cdb.value;
                        mem[i].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i].dmem_wdata    <=  cmp_cdb.value;
                            mem[i].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                end
            end
        end   



        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //CDB4////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        if(mem_cdb.valid && !flush) begin
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == mem_cdb.tag)) begin
                    f1 <= '1;
                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r1_v   <=   mem_cdb.value;
                        mem[i-1].busy_1 <=   1'b0;


                        mem[i-1].dmem_addr    <=  mem_cdb.value + mem[i].imm;
                        mem[i-1].dmem_value_valid   <=  1'b1;
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r1_v   <=   mem_cdb.value;
                            mem[i-2].busy_1 <=   1'b0;


                            mem[i-2].dmem_addr    <=  mem_cdb.value + mem[i].imm;
                            mem[i-2].dmem_value_valid   <=  1'b1;
                        end
                    
                        else if (i >= 1)begin
                            mem[i -1].r1_v   <=   mem_cdb.value;
                            mem[i -1].busy_1 <=   1'b0;


                            mem[i -1].dmem_addr    <=  mem_cdb.value + mem[i].imm;
                            mem[i -1].dmem_value_valid   <=  1'b1;
                        end
                    end

                    else begin
                        mem[i].r1_v   <=   mem_cdb.value;
                        mem[i].busy_1 <=   1'b0;


                        mem[i].dmem_addr    <=  mem_cdb.value + mem[i].imm;
                        mem[i].dmem_value_valid   <=  1'b1;
                    end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == mem_cdb.tag)) begin
                    f2 <= '1;

                    if (deque_sig && !forward_sel && (i >= 1)) begin
                        mem[i-1].r2_v   <=   mem_cdb.value;
                        mem[i-1].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i-1].dmem_wdata    <=  mem_cdb.value;
                            mem[i-1].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                    else if (deque_sig && forward_sel) begin
                        if ((forward_idx > i) && (i >= 2)) begin
                            mem[i-2].r2_v   <=   mem_cdb.value;
                            mem[i-2].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-2].dmem_wdata    <=  mem_cdb.value;
                                mem[i-2].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                        else if (i >= 1)begin
                            mem[i-1].r2_v   <=   mem_cdb.value;
                            mem[i-1].busy_2 <=   1'b0;

                            if(mem[i].opcode ==op_store)begin
                                mem[i-1].dmem_wdata    <=  mem_cdb.value;
                                mem[i-1].dmem_wdata_valid   <=  1'b1;
                            end
                        end
                    end

                    else begin
                        mem[i].r2_v   <=   mem_cdb.value;
                        mem[i].busy_2 <=   1'b0;

                        if(mem[i].opcode ==op_store)begin
                            mem[i].dmem_wdata    <=  mem_cdb.value;
                            mem[i].dmem_wdata_valid   <=  1'b1;
                        end
                    end
                end
            end
        end   


        
    end

    //TODO
    //forwarding
    //done with updating mem and ptr, set output signals (forward/store/load)
    assign dmem_valid   =  deque_sig && !dmem_work && mem[0].taken && !flush;
    assign dmem_out     =  mem[0];
    //rvfi deque
    always_comb begin 
        rvfi_out_dmem = rvfi[0];
        rvfi_out_dmem.r1_rdata = mem[0].r1_v;
        rvfi_out_dmem.r2_rdata = mem[0].r2_v;
    end
    // assign rvfi_out_dmem = rvfi[0];

    assign store_commit =  dmem_valid && store_ready;

    //forward cdb
    assign forward_cdb.value    =   mem[0].dmem_wdata;
    assign forward_cdb.tag      =   mem[forward_idx].rob_entry;
    assign forward_cdb.valid    =   forward_sel && dmem_valid;
    assign forward_cdb.br_target    = '0;
    assign forward_cdb.br_en        = '0;

    //forward lsq_t
    assign forward_out          =   mem[forward_idx];
    //forward valid
    assign forward_valid        =   forward_sel && dmem_valid;

    //rvfi forward out
    always_comb begin 
        rvfi_out_forward = rvfi[forward_idx];;
        rvfi_out_forward.r1_rdata = mem[forward_idx].r1_v;
        rvfi_out_forward.r2_rdata = mem[forward_idx].r2_v;
    end
    // assign rvfi_out_forward     =   rvfi[forward_idx];


    always_ff @(posedge clk) begin
        if (rst || flush) begin
          wrPtr <= '0;
        end else begin
          wrPtr <= wrPtrNext;
        end
    end

endmodule



// module lsq import rv32i_types::*;
//     #(
//         parameter    size_     = 8,
//         localparam   ptr_      = $clog2(size_) 
//     )(
//         input   logic           flush,
//         input   logic           clk,
//         input   logic           rst,

//         //from dispatch
//         input   logic           dispatch,           //enque signal
//         input   rs_t            dispatch_pack,

//         //snoop from cdb
//         input   cdb_t           alu_cdb,
//         input   cdb_t           mul_cdb,
//         input   cdb_t           cmp_cdb,
//         input   cdb_t           mem_cdb,

//         //from rob for store execution
//         input   logic   [6:0]   rob_opcode,         //check if the top of rob is a store, if yes fire store from lsq
//         input   logic   [4:0]   rob_rds,
//         output  logic           store_commit,       //this sets the commit signal in rob to 1
        
//         //memory unit
//         input   logic           dmem_work,
//         output  logic           dmem_valid,         //dmem_value_valid && dmem_wdata_valid
//         output  lsq_t           dmem_out,            

//         //forwarding
//         output  cdb_t           forward_cdb,
//         output  lsq_t           forward_out,
//         output  logic           forward_valid,         

//         output logic          full,
//         output logic          empty,

//         //rvfi signal
//         input rvfi_data rvfi_in,
//         output rvfi_data rvfi_out_dmem,
//         output rvfi_data rvfi_out_forward
//     );
//     /////////////////////////////////////////////
//     logic               load_ready, store_ready;
//     logic               deque_sig, enque_sig;
//     logic               forward_sel;
//     // logic   [ptr_-1:0]  forward_idx;
//     int                 forward_idx;
//     /////////////////////////////////////////////


//     rvfi_data rvfi[size_];
//     lsq_t mem[size_];
//     logic [ptr_-1:0] wrPtr, wrPtrNext;              //head

//     //empty = mem[0] not taken && wrptr at top
//     assign empty = (!mem[0].taken && (wrPtr == 3'b000));
//     //full = mem[last]
//     assign full  = (mem[7].taken && (wrPtr == 3'b111));

//     //determine if my first store is ready (if frist is store)
//     assign store_ready = (mem[0].opcode == op_store) && mem[0].dmem_value_valid && mem[0].dmem_wdata_valid && (rob_opcode == op_store) && (mem[0].rds == rob_rds);
//     //determine if my first load  is ready (if frist is load )
//     assign load_ready  = (mem[0].opcode == op_load)  && mem[0].dmem_value_valid ;


//     //update write pointer////////////////////////////////////////////////
//     always_comb begin 
        
//         //default keep same
//         wrPtrNext = wrPtr;
//         forward_sel = '0;
//         forward_idx = '0;
//         deque_sig   = '0;
//         enque_sig   = '0;

        

//         //case 1 : if only dispatch (enque)
//         if (dispatch_pack.opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
//             if (!full && dispatch && !flush) begin
//                 if (wrPtr == 3'b111) wrPtrNext = wrPtr;
//                 else                    wrPtrNext = wrPtr + 1'b1;
//                 enque_sig = '1;
//             end
//         end

//         //case 2 : if only deque first store/load
//         if (!dmem_work && !empty) begin
//             if (load_ready || store_ready) begin
//                 deque_sig = '1;
//                 if(full) wrPtrNext = wrPtr;
//                 else     wrPtrNext = wrPtr - 1'b1;
//             end
//         end

//         //case 3 : if deque and dispatch at the same time
//         if (enque_sig && deque_sig) wrPtrNext = wrPtr;

//         //case 4 : if store deque + forwarding (forwarding only happens when first st deques)
//         if (store_ready && deque_sig) begin
//             for (int i=1; i<size_; i++) begin
//                 //if find empty entry, means you reached end -> break for loop
//                 if(!mem[i].taken || (mem[i].opcode == op_store)) break;

//                 else if (mem[i].opcode == op_load) begin
                    
//                     //check if addr_match
//                     if((mem[i].dmem_addr == mem[0].dmem_addr) && mem[i].dmem_value_valid) begin
//                         forward_sel = 1'b1;
//                         forward_idx = i;
//                         if (full)   wrPtrNext = wrPtr - 3'h1;           //wrptr - 1
//                         else        wrPtrNext = wrPtr - 3'h2;           //wrptr - 2
//                         break;
//                     end
//                 end
//             end
//         end

//         //case 5 : if deque and forward and dispatch
//         if (enque_sig && deque_sig && forward_sel) begin
//             if (full)   wrPtrNext = wrPtr;
//             else        wrPtrNext = wrPtr - 1'b1;
//         end

//         if (flush) wrPtrNext = '0;
        
//     end
//     ////////////////////////////////////////////////////////////////////////////////////
    

//     // logic f1, f2, f3, f4;
//     //update values/////////////////////////////////////////////////////////////////////
//     always_ff @( posedge clk ) begin 
//         //default
//         mem[wrPtr] <= mem[wrPtr];
//         rvfi[wrPtr] <=  rvfi[wrPtr];
    

//         if (rst || flush) begin
//           for(int i = 0; i<size_; i++) begin
//             mem[i] <= '0;
//             rvfi[i] <= '0;
//           end
//         end
        
//         //perform collapse
//         //if both deque and forward
//         if(deque_sig && forward_sel) begin
//             for(int i = 0; i<(size_-1); i++) begin
//                 //before you hit forward index
//                 if(i < (forward_idx- 1)) begin
//                     mem[i] <= mem[i+1];
//                     rvfi[i] <= rvfi[i+1];
//                 end
//                 //after you reach forward index
//                 else begin
//                     if (i+2 <= size_-1) begin
//                         mem[i] <= mem[i+2];
//                         rvfi[i] <= rvfi[i+2];
//                     end
//                     else    break;
//                 end
//             end
//         end

//         //only deque, no forwarding
//         else if (deque_sig) begin
//             for(int i = 0; i<(size_-1); i++) begin
//                 mem[i] <= mem[i+1];
//                 rvfi[i] <= rvfi[i+1];
//             end
//         end

//         //clear unneeded row
//         if (deque_sig && forward_sel)   begin
//             mem[wrPtrNext]      <= '0;
//             mem[wrPtrNext +1]   <= '0;
//             rvfi[wrPtrNext]      <= '0;
//             rvfi[wrPtrNext +1]   <= '0;
//         end
//         else if (deque_sig) begin
//             mem[wrPtrNext]      <= '0;
//             rvfi[wrPtrNext]      <= '0;
//         end

//         // write new values if deque
//         if (dispatch_pack.opcode inside {op_load, op_store}) begin
//             if (enque_sig && deque_sig && forward_sel && !flush) begin
//                 mem[wrPtr -2].opcode        <= dispatch_pack.opcode;
//                 mem[wrPtr -2].rs1_rob       <= dispatch_pack.rs1_rob;
//                 mem[wrPtr -2].rs2_rob       <= dispatch_pack.rs2_rob;
//                 mem[wrPtr -2].busy_1        <= dispatch_pack.busy_1;    
//                 mem[wrPtr -2].busy_2        <= dispatch_pack.busy_2;
//                 mem[wrPtr -2].r1_v          <= dispatch_pack.r1_v;
//                 mem[wrPtr -2].r2_v          <= dispatch_pack.r2_v;
//                 mem[wrPtr -2].taken         <= 1'b1;
//                 mem[wrPtr -2].rds           <= dispatch_pack.rds;
//                 mem[wrPtr -2].rob_entry     <= dispatch_pack.rob_entry;
//                 mem[wrPtr -2].dmem_addr     <= (!dispatch_pack.busy_1) ? (dispatch_pack.r1_v + dispatch_pack.imm) : 0;
//                 mem[wrPtr -2].dmem_value_valid    <= (!dispatch_pack.busy_1);
//                 mem[wrPtr -2].funct3        <= dispatch_pack.funct3;
//                 mem[wrPtr -2].imm           <= dispatch_pack.imm;
//                 // if (dispatch_pack.opcode == op_load) begin
//                 //     mem[wrPtr -2].dmem_rdata        <= dispatch_pack.;                                          //not sure
//                 // end
//                 if (dispatch_pack.opcode == op_store) begin
//                     mem[wrPtr -2].dmem_wdata        <= (!dispatch_pack.busy_2) ? (dispatch_pack.r2_v) : 0;
//                     mem[wrPtr -2].dmem_wdata_valid        <= (!dispatch_pack.busy_2);
//                 end
                
//                 rvfi[wrPtr -2]  <= rvfi_in;
//             end
//             else if (enque_sig && deque_sig && !flush) begin
//                 mem[wrPtr -1].opcode        <= dispatch_pack.opcode;
//                 mem[wrPtr -1].rs1_rob       <= dispatch_pack.rs1_rob;
//                 mem[wrPtr -1].rs2_rob       <= dispatch_pack.rs2_rob;
//                 mem[wrPtr -1].busy_1        <= dispatch_pack.busy_1;    
//                 mem[wrPtr -1].busy_2        <= dispatch_pack.busy_2;
//                 mem[wrPtr -1].r1_v          <= dispatch_pack.r1_v;
//                 mem[wrPtr -1].r2_v          <= dispatch_pack.r2_v;
//                 mem[wrPtr -1].taken         <= 1'b1;
//                 mem[wrPtr -1].rds           <= dispatch_pack.rds;
//                 mem[wrPtr -1].rob_entry     <= dispatch_pack.rob_entry;
//                 mem[wrPtr -1].dmem_addr     <= (!dispatch_pack.busy_1 ) ? (dispatch_pack.r1_v + dispatch_pack.imm) : 0;
//                 mem[wrPtr -1].dmem_value_valid    <= (!dispatch_pack.busy_1);
//                 mem[wrPtr -1].funct3        <= dispatch_pack.funct3;
//                 mem[wrPtr -1].imm           <= dispatch_pack.imm;
//                 // if (dispatch_pack.opcode == op_load) begin
//                 //     mem[wrPtr -1].dmem_rdata        <= dispatch_pack.;                                          //not sure
//                 // end
//                 if (dispatch_pack.opcode == op_store) begin
//                     mem[wrPtr -1].dmem_wdata        <= (!dispatch_pack.busy_2) ? (dispatch_pack.r2_v) : 0;
//                     mem[wrPtr -1].dmem_wdata_valid        <= (!dispatch_pack.busy_2);
//                 end

//                 rvfi[wrPtr -1]  <= rvfi_in;

//             end
//             else if (enque_sig) begin
//                 mem[wrPtr ].opcode        <= dispatch_pack.opcode;
//                 mem[wrPtr ].rs1_rob       <= dispatch_pack.rs1_rob;
//                 mem[wrPtr ].rs2_rob       <= dispatch_pack.rs2_rob;
//                 mem[wrPtr ].busy_1        <= dispatch_pack.busy_1;    
//                 mem[wrPtr ].busy_2        <= dispatch_pack.busy_2;
//                 mem[wrPtr ].r1_v          <= dispatch_pack.r1_v;
//                 mem[wrPtr ].r2_v          <= dispatch_pack.r2_v;
//                 mem[wrPtr ].taken         <= 1'b1;
//                 mem[wrPtr ].rds           <= dispatch_pack.rds;
//                 mem[wrPtr ].rob_entry     <= dispatch_pack.rob_entry;
//                 mem[wrPtr ].dmem_addr     <= (!dispatch_pack.busy_1) ? (dispatch_pack.r1_v + dispatch_pack.imm) : 0;
//                 mem[wrPtr ].dmem_value_valid    <= (!dispatch_pack.busy_1);
//                 mem[wrPtr ].funct3        <= dispatch_pack.funct3;
//                 mem[wrPtr ].imm           <= dispatch_pack.imm;
//                 // if (dispatch_pack.opcode == op_load) begin
//                 //     mem[wrPtr ].dmem_rdata        <= dispatch_pack.;                                          //not sure
//                 // end
//                 if (dispatch_pack.opcode == op_store) begin
//                     mem[wrPtr ].dmem_wdata        <= (!dispatch_pack.busy_2) ? (dispatch_pack.r2_v) : 0;
//                     mem[wrPtr ].dmem_wdata_valid        <= (!dispatch_pack.busy_2);
//                 end

//                 rvfi[wrPtr ]  <= rvfi_in;
//             end
//         end


//         //update dmem_addr and dmem_value_valid
//         //CDB1
//         if(alu_cdb.valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == alu_cdb.tag)) begin
//                     // f1 <= '1;
//                     mem[i].r1_v   <=   alu_cdb.value;
//                     mem[i].busy_1 <=   1'b0;


//                     mem[i].dmem_addr    <=  alu_cdb.value + mem[i].imm;
//                     mem[i].dmem_value_valid   <=  1'b1;
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == alu_cdb.tag)) begin
//                     // f2 <= '1;
//                     mem[i].r2_v   <=   alu_cdb.value;
//                     mem[i].busy_2 <=   1'b0;

//                     if(mem[i].opcode ==op_store)begin
//                         mem[i].dmem_wdata    <=  alu_cdb.value;
//                         mem[i].dmem_wdata_valid   <=  1'b1;
//                     end
//                 end
//             end
//         end   

//         //CDB2
//         if(mul_cdb.valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == mul_cdb.tag)) begin
//                     // f1 <= '1;
//                     mem[i].r1_v   <=   mul_cdb.value;
//                     mem[i].busy_1 <=   1'b0;

//                     mem[i].dmem_addr    <=  mul_cdb.value + mem[i].imm;
//                     mem[i].dmem_value_valid   <=  1'b1;
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == mul_cdb.tag)) begin
//                     // f2 <= '1;
//                     mem[i].r2_v   <=   mul_cdb.value;
//                     mem[i].busy_2 <=   1'b0;

//                     if(mem[i].opcode ==op_store)begin
//                         mem[i].dmem_wdata    <=  mul_cdb.value;
//                         mem[i].dmem_wdata_valid   <=  1'b1;
//                     end
//                 end
//             end
//         end  

//         //CDB3
//         if(cmp_cdb.valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == cmp_cdb.tag)) begin
//                     // f1 <= '1;
//                     mem[i].r1_v   <=   cmp_cdb.value;
//                     mem[i].busy_1 <=   1'b0;

//                     mem[i].dmem_addr    <=  cmp_cdb.value + mem[i].imm;
//                     mem[i].dmem_value_valid   <=  1'b1;
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == cmp_cdb.tag)) begin
//                     // f2 <= '1;
//                     mem[i].r2_v   <=   cmp_cdb.value;
//                     mem[i].busy_2 <=   1'b0;

//                     if(mem[i].opcode ==op_store)begin
//                         mem[i].dmem_wdata    <=  cmp_cdb.value;
//                         mem[i].dmem_wdata_valid   <=  1'b1;
//                     end
//                 end
//             end
//         end  

//         //CDB4
//         if(mem_cdb.valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == mem_cdb.tag)) begin
//                     // f1 <= '1;
//                     mem[i].r1_v   <=   mem_cdb.value;
//                     mem[i].busy_1 <=   1'b0;

//                     mem[i].dmem_addr    <=  mem_cdb.value + mem[i].imm;
//                     mem[i].dmem_value_valid   <=  1'b1;
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == mem_cdb.tag)) begin
//                     // f2 <= '1;
//                     mem[i].r2_v   <=   mem_cdb.value;
//                     mem[i].busy_2 <=   1'b0;

//                     if(mem[i].opcode ==op_store)begin
//                         mem[i].dmem_wdata    <=  mem_cdb.value;
//                         mem[i].dmem_wdata_valid   <=  1'b1;
//                     end
//                 end
//             end
//         end 
        
//     end

//     //TODO
//     //forwarding
//     //done with updating mem and ptr, set output signals (forward/store/load)
//     assign dmem_valid   =  deque_sig && !dmem_work && mem[0].taken && !flush;
//     assign dmem_out     =  mem[0];
//     //rvfi deque
//     always_comb begin 
//         rvfi_out_dmem = rvfi[0];
//         rvfi_out_dmem.r1_rdata = mem[0].r1_v;
//         rvfi_out_dmem.r2_rdata = mem[0].r2_v;
//     end
//     // assign rvfi_out_dmem = rvfi[0];

//     assign store_commit =  dmem_valid && store_ready;

//     //forward cdb
//     assign forward_cdb.value    =   mem[0].dmem_wdata;
//     assign forward_cdb.tag      =   mem[forward_idx].rob_entry;
//     assign forward_cdb.valid    =   forward_sel && dmem_valid;

//     //forward lsq_t
//     assign forward_out          =   mem[forward_idx];
//     //forward valid
//     assign forward_valid        =   forward_sel && dmem_valid;

//     //rvfi forward out
//     always_comb begin 
//         rvfi_out_forward = rvfi[forward_idx];;
//         rvfi_out_forward.r1_rdata = mem[forward_idx].r1_v;
//         rvfi_out_forward.r2_rdata = mem[forward_idx].r2_v;
//     end
//     // assign rvfi_out_forward     =   rvfi[forward_idx];


//     always_ff @(posedge clk) begin
//         if (rst || flush) begin
//           wrPtr <= '0;
//         end else begin
//           wrPtr <= wrPtrNext;
//         end
//     end

// endmodule