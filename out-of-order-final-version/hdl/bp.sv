// use five bits of PC => pc[6:2]
// 2^5 = 32 GShare entries
// branch history records last 5 branches/jump results

// 16 entries (same as ROB) for our BP FIFO
// BP FIFO keeps pc, incase we mispredicted and need to restore correct addr
// BP FIFO keeps taken/not taken, this is to determine if we mispredicted
// BP FIFO will be updated when br/jal is commited in ROB

module bp
    import rv32i_types::*;
    (
        // input   logic   [31:0]  pc_target_addr,
        input   logic           jump_valid1,
        input   logic           jump_valid2,
        // input   logic           ufp_resp_late,
        input   logic           imem_resp,
        input   logic           bp_ready,
        input   logic           clk,
        input   logic           rst,

        input   logic           flush,

        //imput pc to access GShare
        input   logic   [31:0]  pc,     //this should be pc_late
        input   logic           valid,  //from bp_decode

        //update BP FIFO
        //signals from Reg
        input   logic   [31:0]  commit_br_pc,
        input   logic           commit_br_en,
        input   logic   [6:0]   commit_opcode,

        //output
        output  logic           taken,
        output  logic           mispredict,
        output  logic   [31:0]  recover_pc,
        output  logic           full,
        output  logic           empty
    );
    //////BP FIFO out///////////////////////////////////////////////////////////
    logic           edge1;
    logic   [31:0]  pc_out;
    logic           taken_out;
    logic   [4:0]   gshare_out;
    logic           readEn;
    logic           writeEn;
    // logic           empty, full;
    logic   [31:0]  br_target_out;
    ////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////
   // logic           valid;      //if instruction is br / jump

    logic   [4:0]   pc_idx;
    logic   [4:0]   history;    //branch history table

    
    logic   [1:0]   GShare[32];
    logic   [4:0]   gshare_idx; //for prediction
    /////////////////////////////////////////////////////////////////////////

    assign pc_idx = pc[6:2];
    // assign gshare_idx = pc_idx ^ history; //我們沒有用XOR, 因為少了XOR 效能比較好
    assign gshare_idx = pc_idx;

    always_ff @( posedge clk ) begin 
        if (rst) begin
            history <= '0;

            for (int i=0; i<32; i++) begin
                GShare[i] <= '0;
            end
        end

        //branch/jump is commited
        else if (commit_opcode inside {op_br, op_jal, op_jalr})begin
            // history update
            history <= {history[3:0], commit_br_en};
    // 2bits counter 的更新
            // gshare update
            if (commit_br_en) begin
                if (GShare[gshare_out] ==  2'b11)
                    GShare[gshare_out] <= 2'b11;
                else 
                    GShare[gshare_out] <= GShare[gshare_out] + 1'b1;
            end
            else begin
                if (GShare[gshare_out] <= 2'b00)
                    GShare[gshare_out] <=  2'b00;
                else 
                    GShare[gshare_out] <= GShare[gshare_out] -  1'b1;
            end
        end

        else begin
            history <= history;
            GShare[gshare_out] <= GShare[gshare_out];
        end
    end

    assign taken = !jump_valid2 && (jump_valid1 || (GShare[gshare_idx][1] && valid));
  //GShare[gshare_idx][1] 意思是 GShare[這個entry]裡面的第二個bit
  //因為每一個entry都有一個2 bits counter, 那為什麼只看第二個? 因為 taken = 第二個bits = 1 ( 2'b11, 2'b10)
  // Not Taken = ( 2'b01, 2'b00)


    //TODO
    // figure flush signal



    // // set BP FIFO writeEn
    // assign writeEn = valid && ufp_resp_late;
    // // set BP FIFO readEn
    // assign readEn = (commit_opcode inside {op_br, op_jal, op_jalr}) && bp_ready;
    // // figure flush signal

     // set BP FIFO writeEn
    // assign writeEn = valid && ufp_resp_late;
    assign writeEn = valid && imem_resp && !full;
    // set BP FIFO readEn
    // assign readEn = (commit_opcode inside {op_br, op_jal, op_jalr});
    //只要ROB給了ready signal就會寫進去 FIFO
    assign readEn = (commit_opcode inside {op_br, op_jal, op_jalr}) && bp_ready;

    always_ff @( posedge clk ) begin 
        if (rst) edge1 <= '0;
        else if (bp_ready) edge1 <= '1;
        else if (commit_opcode inside {op_br, op_jal, op_jalr}) edge1 <= '0;
        else edge1 <= edge1;
    end
    
    ////////////////////////////////////////////////////////////////////////
    ///BP_FIFO//////////////////////////////////////////////////////////////
    bp_t mem[16];

    logic [4:0] wrPtr, wrPtrNext;              //head
    logic [4:0] rdPtr, rdPtrNext;              //tail

    always_comb begin
        // set default value
        wrPtrNext = wrPtr;
        rdPtrNext = rdPtr;

        // if enque, head + 1
        if (writeEn) begin
            wrPtrNext = wrPtr + 1'b1;
        end

        // if deque, tail + 1
        if (readEn) begin
            rdPtrNext = rdPtr + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            wrPtr <= '0;
            rdPtr <= '0;
        end 
        else begin
            wrPtr <= wrPtrNext;
            rdPtr <= rdPtrNext;
        end 
    end

    always_ff @(posedge clk) begin
        if (rst || flush) begin
            for (int i=0; i < 16; i++) begin
                mem[i] <= '0;
            end
        end
        else if(!full && !flush) begin
            mem[wrPtr[3:0]].taken           <= taken;
            mem[wrPtr[3:0]].pc              <= pc;
            mem[wrPtr[3:0]].gshare          <= gshare_idx;
        end
        else begin
            mem[wrPtr[3:0]]     <=   mem[wrPtr[3:0]];
        end
    end

    assign pc_out       = readEn ? mem[rdPtr[3:0]].pc     : 'x;
    assign taken_out    = readEn ? mem[rdPtr[3:0]].taken  : 'x;
    assign gshare_out   = readEn ? mem[rdPtr[3:0]].gshare : 'x;
    

    assign empty = (wrPtr[4] == rdPtr[4]) && (wrPtr[3:0] == rdPtr[3:0]);
    assign full  = (wrPtr[4] != rdPtr[4]) && (wrPtr[3:0] == rdPtr[3:0]);

    assign mispredict = (bp_ready && (commit_opcode inside {op_br, op_jal, op_jalr})) ? (commit_br_en != taken_out) : '0;
    
    assign recover_pc = commit_br_en ? commit_br_pc : pc_out + 32'h4;

endmodule