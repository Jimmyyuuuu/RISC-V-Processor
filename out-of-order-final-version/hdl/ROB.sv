module ROB  
    import rv32i_types::*;
    #(
        parameter data_         = 45,                       //number of bits per line  (opcode + rds + val + commit)
        parameter size_         = 16,                       //number of lines in a queue
        localparam ptr_         = $clog2(size_)               //number of pointer bits needed for the correspond size_
    )
    (   
        input   logic           dmem_work,
        input   logic           lsq_store_commit,
        input   rvfi_data       lsq_store_rvfi,

        input   logic           flush,
        input   logic           clk,
        input   logic           rst,
    
        // items stored in ROB
        input   logic   [6:0]   opcode,                 //store opcode
        input   logic   [4:0]   rds,                    //store rds  

        //from CDB
        input   logic           br_en1,
        input   logic           br_en2,
        input   logic           br_en3,
        input   logic           br_en4,
        input   logic   [31:0]  br_target1,
        input   logic   [31:0]  br_target2,
        input   logic   [31:0]  br_target3,
        input   logic   [31:0]  br_target4,

        // input values from CDB 
        input   logic   [31:0]  ROB_val1,               //ALU CDB
        input   logic   [31:0]  ROB_val2,               //MUL CDB
        input   logic   [31:0]  ROB_val3,               //Br  CDB
        input   logic   [31:0]  ROB_val4,               //Ld  CDB
    
        //when CDB value is valid and ready to store in ROB
        input   logic           CDB_valid1,             
        input   logic           CDB_valid2,
        input   logic           CDB_valid3,
        input   logic           CDB_valid4,
    
        // CDB ROB entry (where to store in ROB)
        input   logic   [3:0]   CDB_ROB1,
        input   logic   [3:0]   CDB_ROB2,
        input   logic   [3:0]   CDB_ROB3,
        input   logic   [3:0]   CDB_ROB4,

        //rvfi coming in from CDB
        input   rvfi_data   rvfi_1,
        input   rvfi_data   rvfi_2,
        input   rvfi_data   rvfi_3,
        input   rvfi_data   rvfi_4,
    
        //write_en to ROB at dispatch -> store opcode and rds
        input   logic           dispatch,   
        
        //for rs1/2 rob_entry -> return a valid signal and a value
        input   logic                 tag1_valid,
        input   logic                 tag2_valid,
        input   logic           [3:0] rs1_renaming_rob,
        input   logic           [3:0] rs2_renaming_rob,         
        
        //for rs1/2 renaming, return valid and value
        output  logic           rs1_valid,
        output  logic           rs2_valid,
        output  logic   [31:0]  rs1_val,
        output  logic   [31:0]  rs2_val,
        output  logic   [3:0]   rs1_rob,
        output  logic   [3:0]   rs2_rob,
    
    
        //for rds renaming 
        output  logic           entry_valid,        //check if the returned rob entry for rds renaming is valid
        output  logic   [3:0]   ROB_entry,        
        
    
        //for commiting in regfile      
        output  rob_t           commit_output,
        output  logic           ready_,                  // ready signal for commit (deque)
        output  logic   [3:0]    ROB_commit_tag,
        // FIFO stuff
        output logic                 full,
        output logic                 empty,

        //output to rvfi
        output  rvfi_data          rvfi_out
    );  
        //ready to commit
        // logic             ready_;   
    
        rob_t mem[size_];

        rvfi_data rvfi[size_];
    
        // set extra bit to determine full/empty
        logic [ptr_:0] wrPtr, wrPtrNext;              //head
        logic [ptr_:0] rdPtr, rdPtrNext;              //tail
    
        //ready to commit
        logic br_ready;
        always_comb begin
            br_ready = '1;

            if (mem[rdPtr[ptr_-1:0]].opcode inside {op_br, op_jal, op_jalr} && dmem_work) br_ready = '0;
            
        end

        assign ready_ = (mem[rdPtr[ptr_-1:0]].commit == 1'b1) && !flush && br_ready;

        //if rob value is not ready, this rob tag is for comparing with CDB
        assign rs1_rob = rs1_renaming_rob;
        assign rs2_rob = rs2_renaming_rob;

        always_comb begin
            // set default value
            wrPtrNext = wrPtr;
            rdPtrNext = rdPtr;
    
            // if dispatch, head + 1 (new instruction enque in ROB from dispatch)
            if (dispatch && !full) begin
                wrPtrNext = wrPtr + 1'b1;
            end
    
            // if ready to commit, tail + 1 (instruction deque from ROB to Regfile)
            if (ready_) begin
                rdPtrNext = rdPtr + 1'b1;
            end
        end
    
        always_ff @(posedge clk) begin
            if (rst || flush) begin
                wrPtr <= '0;
                rdPtr <= '0;
            end else begin
                wrPtr <= wrPtrNext;
                rdPtr <= rdPtrNext;
            end
        end
    
        logic   f1,f2,f3,f4,f5,f6,f7;
        // update ROB
        always_ff @(posedge clk) begin
            // default
            mem[wrPtr[ptr_-1:0]] <= mem[wrPtr[ptr_-1:0]];
            rvfi[wrPtr[ptr_-1:0]] <= rvfi[wrPtr[ptr_-1:0]] ;
            f1 <= '0;
            f2 <= '0;
            f3 <= '0;
            f4 <= '0;
            f5 <= '0;
            f6 <= '0;
            f7 <= '0;

            if(rst || flush) begin
                for(int i=0; i < size_; i++) begin
                    mem[i] <= '0;
                    rvfi[i] <= '0;
                end
            end
    
            //updating opcode and rds at dispatch
            if(!full && dispatch && !flush) begin
                mem[wrPtr[ptr_-1:0]].opcode <= opcode;
                mem[wrPtr[ptr_-1:0]].rds <= rds;
                mem[wrPtr[ptr_-1:0]].commit <= 1'b0;
                rvfi[wrPtr[ptr_-1:0]] <= '0;
                f1 <= '1;
            end
    
            //updating ROB value when CDB is ready
            if(CDB_valid1 && !flush) begin
                mem[CDB_ROB1].br_target <= br_target1;
                mem[CDB_ROB1].br_en <= br_en1;
                mem[CDB_ROB1].ROB_val <= ROB_val1;
                mem[CDB_ROB1].commit <= 1'b1;
                rvfi[CDB_ROB1] <= rvfi_1;
                rvfi[CDB_ROB1].valid <= 1'b1;
                f2 <= '1;
            end
            if(CDB_valid2 && !flush) begin
                mem[CDB_ROB2].br_target <= br_target2;
                mem[CDB_ROB2].br_en <= br_en2;
                mem[CDB_ROB2].ROB_val <= ROB_val2;
                mem[CDB_ROB2].commit <= 1'b1;
                rvfi[CDB_ROB2] <= rvfi_2;
                rvfi[CDB_ROB2].valid <= 1'b1;
                f3 <= '1;
            end
            if(CDB_valid3 && !flush) begin
                mem[CDB_ROB3].br_target <= br_target3;
                mem[CDB_ROB3].br_en <= br_en3;
                mem[CDB_ROB3].ROB_val <= ROB_val3;
                mem[CDB_ROB3].commit <= 1'b1;
                rvfi[CDB_ROB3] <= rvfi_3;
                rvfi[CDB_ROB3].valid <= 1'b1;
                f4 <= '1;
            end
            if(CDB_valid4 && !flush) begin
                mem[CDB_ROB4].br_target <= br_target4;
                mem[CDB_ROB4].br_en <= br_en4;
                mem[CDB_ROB4].ROB_val <= ROB_val4;
                mem[CDB_ROB4].commit <= 1'b1;
                rvfi[CDB_ROB4] <= rvfi_4;
                rvfi[CDB_ROB4].valid <= 1'b1;
                f5 <= '1;
            end

            if (lsq_store_commit) begin
                mem[rdPtr[ptr_-1:0]].commit <= 1'b1;
                rvfi[rdPtr[ptr_-1:0]]  <= lsq_store_rvfi;
                f6 <= '1;
            end


            if (ready_) begin
                mem[rdPtr[ptr_-1:0]] <= '0;
                rvfi[rdPtr[ptr_-1:0]] <= '0;
                f7 <= '1;
            end

            // if (lsq_store_commit) begin
            //     mem[0].commit <= 1'b1;
            //     rvfi[0]  <= lsq_store_rvfi;
            // end
        end
    
    
        //pass on a rob struct when commit, need to see if ready_signal is high
        assign commit_output = mem[rdPtr[ptr_-1:0]];
        assign ROB_commit_tag = rdPtr[ptr_-1:0];
    
        // this will be giving our available slot for renaming 
        assign ROB_entry = wrPtr[ptr_-1:0];
        assign entry_valid = !full;
    
        // this is for rs1_s/rs2_s renaming -> return a value and valid bit (valid value)
        assign rs1_valid = mem[rs1_renaming_rob].commit && tag1_valid;
        assign rs2_valid = mem[rs2_renaming_rob].commit && tag2_valid;
    
        assign rs1_val   = mem[rs1_renaming_rob].ROB_val;
        assign rs2_val   = mem[rs2_renaming_rob].ROB_val;
    
        // determine full or empty
        assign empty = (wrPtr[ptr_] == rdPtr[ptr_]) && (wrPtr[ptr_-1:0] == rdPtr[ptr_-1:0]);
        assign full  = (wrPtr[ptr_] != rdPtr[ptr_]) && (wrPtr[ptr_-1:0] == rdPtr[ptr_-1:0]);
    
        //commit rvfi
        assign rvfi_out = rvfi[rdPtr[ptr_-1:0]];
    
    
    endmodule   :   ROB
    
    
    // note:
    // still have to implement ready signal
    // update CDB values