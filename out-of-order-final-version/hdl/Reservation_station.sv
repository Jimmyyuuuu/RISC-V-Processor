module rs import rv32i_types::*;
    #(
      parameter  data_      = 32,                           //number of bits per line                    
      parameter  size_      = 4,                            //number of lines in a queue
      localparam ptr_       = $clog2(size_)                 //number of pointer bits needed for the correspond size_
    ) (
      input  logic          flush,
      input  logic          clk,
      input  logic          rst,
      //from function unit
      input  logic          work,
      //rvfi signal
      input rvfi_data rvfi_in,
      output rvfi_data rvfi_out,
      //things coming from dispatch
      input  logic          dispatch,         //enque signal
      //fill in struct
      input  logic  [2:0]   aluop,
      input  logic  [2:0]   cmpop,
      input  logic  [1:0]   mulop,
      input  logic  [6:0]   opcode,
      input  logic  [4:0]   rd_s,
      input  logic  [3:0]   rs1_rob,
      input  logic  [3:0]   rs2_rob,
      input  logic  [3:0]   rob_entry,
      input  logic          busy_1,
      input  logic          busy_2,
      input  logic  [31:0]  r1_v,
      input  logic  [31:0]  r2_v,
      input  logic  [31:0]  pc,
      input  logic  [31:0]  imm,

      // input  logic          iq_re_in,
    
      //coming from CDB value/valid/rob_tag to fill in a or b
      //value
      input  logic  [31:0]  CDB_1,  
      input  logic  [31:0]  CDB_2,
      input  logic  [31:0]  CDB_3,  
      input  logic  [31:0]  CDB_4,
      //valid
      input  logic          CDB1_valid,
      input  logic          CDB2_valid,
      input  logic          CDB3_valid,
      input  logic          CDB4_valid,
      //rob_tag
      input  logic  [3:0]   CDB1_rob,
      input  logic  [3:0]   CDB2_rob,
      input  logic  [3:0]   CDB3_rob,
      input  logic  [3:0]   CDB4_rob,
    
      //rs output to function unit based on ready bit
      output logic          output_valid,
      output rs_t           rs_out,
    
      output logic          full,
      output logic          empty
    );
      logic fl1, fl2, fl3, fl4, fl5;

      rs_t mem[size_];
      rvfi_data rvfi[size_];
    
      // set extra bit to determine full/empty
      logic [ptr_-1:0] wrPtr, wrPtrNext;              //head
    
      //the index of the ready inst
      // logic unsigned [ptr_-1:0] sel_idx;
      int sel_idx;
      //determine if we found a ready inst
      logic            sel;
    
      //empty = mem[0] not taken && wrptr at top
      assign empty = (!mem[0].taken && (wrPtr == 2'b00));
      //full = mem[last]
      assign full  = (mem[3].taken && (wrPtr == 2'b11));
      
      //update pointer 
      always_comb begin
        
        // default: keep same
        wrPtrNext = wrPtr;
        sel = 1'b0;
        // sel_idx = 2'b00;
        sel_idx = '0;
        // fl1 = '0;
        // fl2 = '0;
        // fl3 = '0;
    
        // if only dispatch, enque
        if (opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
          if (!full && dispatch) begin
              // fl1 = '1;
              if (wrPtr == (2'b11)) wrPtrNext = wrPtr;
              else                    wrPtrNext = wrPtr + 1'b1;
          end
        end

        //search for ready signal, then store the index
        for (int i=0; i < size_; i++) begin
          //if only deque
          if (!work && !empty) begin
            if (mem[i].opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
              if (!mem[i].busy_1 && !mem[i].busy_2 && mem[i].taken) begin
                sel_idx = i;
                sel = 1'b1;
                if (full) begin
                  wrPtrNext = wrPtr;
                end
                else begin
                  wrPtrNext = wrPtr - 1'b1;
                end
                break;
              end
            end
          end
        end

        //if dispatch and deque
        if((!full && dispatch) && sel) begin
          wrPtrNext = wrPtr;
        end

        if(flush) wrPtrNext = '0;

      end    
      
      logic [1:0] f1,f2,f3,f4;

      always_ff @( posedge clk ) begin 
        //default
        fl1 <= '0;
        fl2 <= '0;
        fl3 <= '0;
        f1 <= '0;
        f2 <= '0;
        f3 <= '0;
        f4 <= '0;
        mem[wrPtr[ptr_-1:0]] <= mem[wrPtr[ptr_-1:0]];
        rvfi[wrPtr[ptr_-1:0]] <=  rvfi[wrPtr[ptr_-1:0]];
        
        
        // if (rst || flush) begin
        //   for(int i = 0; i<size_; i++) begin
        //     // mem[i].taken <= '0;
        //     mem[i] <= '0;
        //     rvfi[i] <= '0;
        //   end
        // end
        //if a instruction is ready for execute
        // if(sel && (sel_idx < (size_-1))) begin
        if(sel) begin
          //perform collapse
          for(int i = 0; i<(size_-1); i++) begin
            if(i >= sel_idx) begin
              mem[i] <= mem[i+1];
              rvfi[i] <= rvfi[i+1];
            end
          end
        end
        //if no dispatch and selected
        if(sel) begin
          mem[wrPtrNext].opcode       <= '0;
          mem[wrPtrNext].rs1_rob      <= '0;
          mem[wrPtrNext].rs2_rob      <= '0;
          mem[wrPtrNext].rds          <= '0;
          mem[wrPtrNext].rob_entry    <= '0;
          mem[wrPtrNext].busy_1       <= '0;
          mem[wrPtrNext].busy_2       <= '0;
          mem[wrPtrNext].r1_v         <= '0;
          mem[wrPtrNext].r2_v         <= '0;
          mem[wrPtrNext].taken        <= '0;
          mem[wrPtrNext].aluop        <= '0;
          mem[wrPtrNext].cmpop        <= '0;
          mem[wrPtrNext].mulop        <= '0;
          mem[wrPtrNext].pc           <= '0;
          mem[wrPtrNext].imm          <= '0;
          // mem[wrPtr].iq_re        <= '0;
          rvfi[wrPtrNext]             <= '0;
        end

        if (opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
          if(!full && dispatch && sel && !flush) begin
            mem[wrPtr -1].opcode       <= opcode;
            mem[wrPtr -1].rs1_rob      <= rs1_rob;
            mem[wrPtr -1].rs2_rob      <= rs2_rob;
            mem[wrPtr -1].rds          <= rd_s;
            mem[wrPtr -1].rob_entry    <= rob_entry;
            mem[wrPtr -1].taken        <= 1'b1;
            mem[wrPtr -1].aluop        <= aluop;
            mem[wrPtr -1].cmpop        <= cmpop;
            mem[wrPtr -1].mulop        <= mulop;
            mem[wrPtr -1].pc           <= pc;
            mem[wrPtr -1].imm          <= imm;

            // mem[wrPtr -1].busy_1       <= busy_1;
            // mem[wrPtr -1].r1_v         <= r1_v;
            // mem[wrPtr -1].busy_2       <= busy_2;
            // mem[wrPtr -1].r2_v         <= r2_v;

            // r1_v
            if (!busy_1) begin
              mem[wrPtr -1].busy_1       <= busy_1;
              mem[wrPtr -1].r1_v         <= r1_v;
            end
            else if (busy_1 && CDB1_valid && !flush && rs1_rob == CDB1_rob) begin
              mem[wrPtr -1].busy_1       <= 1'b0;
              mem[wrPtr -1].r1_v         <= CDB_1;
            end
            else if (busy_1 && CDB2_valid && !flush && rs1_rob == CDB2_rob) begin
              mem[wrPtr -1].busy_1       <= 1'b0;
              mem[wrPtr -1].r1_v         <= CDB_2;
            end
            else if (busy_1 && CDB3_valid && !flush && rs1_rob == CDB3_rob) begin
              mem[wrPtr -1].busy_1       <= 1'b0;
              mem[wrPtr -1].r1_v         <= CDB_3;
            end
            else if (busy_1 && CDB4_valid && !flush && rs1_rob == CDB4_rob) begin
              fl1 <= '1;
              mem[wrPtr -1].busy_1       <= 1'b0;
              mem[wrPtr -1].r1_v         <= CDB_4;
            end
            else begin
              mem[wrPtr -1].busy_1       <= busy_1;
              mem[wrPtr -1].r1_v         <= r1_v;
            end
              
            // r2v
            if (!busy_2) begin
              mem[wrPtr -1].busy_2       <= busy_2;
              mem[wrPtr -1].r2_v         <= r2_v;
            end
            else if (busy_2 && CDB1_valid && !flush && rs2_rob == CDB1_rob) begin
              mem[wrPtr -1].busy_2       <= 1'b0;
              mem[wrPtr -1].r2_v         <= CDB_1;
            end
            else if (busy_2 && CDB2_valid && !flush && rs2_rob == CDB2_rob) begin
              mem[wrPtr -1].busy_2       <= 1'b0;
              mem[wrPtr -1].r2_v         <= CDB_2;
            end
            else if (busy_2 && CDB3_valid && !flush && rs2_rob == CDB3_rob) begin
              mem[wrPtr -1].busy_2       <= 1'b0;
              mem[wrPtr -1].r2_v         <= CDB_3;
            end
            else if (busy_2 && CDB4_valid && !flush && rs2_rob == CDB4_rob) begin
              mem[wrPtr -1].busy_2       <= 1'b0;
              mem[wrPtr -1].r2_v         <= CDB_4;
            end
            else begin
              mem[wrPtr -1].busy_2       <= busy_2;
              mem[wrPtr -1].r2_v         <= r2_v;
            end

            rvfi[wrPtr -1]             <= rvfi_in;
          end


          //when dispatch,update struct
          else if(!full && dispatch && !flush) begin
            f1 <= '1;
            mem[wrPtr].opcode       <= opcode;
            mem[wrPtr].rs1_rob      <= rs1_rob;
            mem[wrPtr].rs2_rob      <= rs2_rob;
            mem[wrPtr].rds          <= rd_s;
            mem[wrPtr].rob_entry    <= rob_entry;
            
            mem[wrPtr].taken        <= 1'b1;
            mem[wrPtr].aluop        <= aluop;
            mem[wrPtr].cmpop        <= cmpop;
            mem[wrPtr].mulop        <= mulop;
            mem[wrPtr].pc           <= pc;
            mem[wrPtr].imm          <= imm;
            
            // mem[wrPtr].busy_1       <= busy_1;
            // mem[wrPtr].busy_2       <= busy_2;
            // mem[wrPtr].r1_v         <= r1_v;
            // mem[wrPtr].r2_v         <= r2_v;

            // r1_v
            if (!busy_1) begin
              mem[wrPtr ].busy_1       <= busy_1;
              mem[wrPtr ].r1_v         <= r1_v;
            end
            else if (busy_1 && CDB1_valid && !flush && rs1_rob == CDB1_rob) begin
              mem[wrPtr ].busy_1       <= 1'b0;
              mem[wrPtr ].r1_v         <= CDB_1;
            end
            else if (busy_1 && CDB2_valid && !flush && rs1_rob == CDB2_rob) begin
              mem[wrPtr ].busy_1       <= 1'b0;
              mem[wrPtr ].r1_v         <= CDB_2;
            end
            else if (busy_1 && CDB3_valid && !flush && rs1_rob == CDB3_rob) begin
              mem[wrPtr ].busy_1       <= 1'b0;
              mem[wrPtr ].r1_v         <= CDB_3;
            end
            else if (busy_1 && CDB4_valid && !flush && rs1_rob == CDB4_rob) begin
              fl2 <= '1;
              mem[wrPtr ].busy_1       <= 1'b0;
              mem[wrPtr ].r1_v         <= CDB_4;
            end
            else begin
              mem[wrPtr ].busy_1       <= busy_1;
              mem[wrPtr ].r1_v         <= r1_v;
            end

            // r2v
            if (!busy_2) begin
              mem[wrPtr ].busy_2       <= busy_2;
              mem[wrPtr ].r2_v         <= r2_v;
            end
            else if (busy_2 && CDB1_valid && !flush && rs2_rob == CDB1_rob) begin
              mem[wrPtr ].busy_2       <= 1'b0;
              mem[wrPtr ].r2_v         <= CDB_1;
            end
            else if (busy_2 && CDB2_valid && !flush && rs2_rob == CDB2_rob) begin
              mem[wrPtr ].busy_2       <= 1'b0;
              mem[wrPtr ].r2_v         <= CDB_2;
            end
            else if (busy_2 && CDB3_valid && !flush && rs2_rob == CDB3_rob) begin
              mem[wrPtr ].busy_2       <= 1'b0;
              mem[wrPtr ].r2_v         <= CDB_3;
            end
            else if (busy_2 && CDB4_valid && !flush && rs2_rob == CDB4_rob) begin
              mem[wrPtr ].busy_2       <= 1'b0;
              mem[wrPtr ].r2_v         <= CDB_4;
            end
            else begin
              mem[wrPtr ].busy_2       <= busy_2;
              mem[wrPtr ].r2_v         <= r2_v;
            end

            rvfi[wrPtr]             <= rvfi_in;
          end
        end
        //when dispatch and deque happen same time, update struct at wrtptr - 1
        


        //if cdb sends back valid data
        if(CDB1_valid && !flush) begin
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == CDB1_rob)) begin
                    // f1 <= '1;
                    if (output_valid && i!=0 && i>sel_idx) begin
                      mem[i-1].r1_v   <=   CDB_1;
                      mem[i-1].busy_1 <=   1'b0;
                    end
                    else begin
                      mem[i].r1_v   <=   CDB_1;
                      mem[i].busy_1 <=   1'b0;
                    end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == CDB1_rob)) begin
                    // f2 <= '1;
                    if (output_valid && i!=0 && i>sel_idx) begin
                      mem[i-1].r2_v   <=   CDB_1;
                      mem[i-1].busy_2 <=   1'b0;
                    end
                    else begin
                      mem[i].r2_v   <=   CDB_1;
                      mem[i].busy_2 <=   1'b0;
                    end
                end
            end
        end
        
        if(CDB2_valid && !flush) begin
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == CDB2_rob)) begin

                    if(output_valid && i!=0 && i>sel_idx) begin
                      mem[i-1].r1_v   <=   CDB_2;
                      mem[i-1].busy_1 <=   1'b0;
                    end
                    else begin
                      mem[i].r1_v   <=   CDB_2;
                      mem[i].busy_1 <=   1'b0;
                    end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == CDB2_rob)) begin
                  if (output_valid && i!=0 && i>sel_idx) begin
                    mem[i-1].r2_v   <=   CDB_2;
                    mem[i-1].busy_2 <=   1'b0;
                  end
                  else begin
                    mem[i].r2_v   <=   CDB_2;
                    mem[i].busy_2 <=   1'b0;
                  end
                end
            end
        end
    
        if(CDB3_valid && !flush) begin
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == CDB3_rob)) begin
                  if (output_valid && i!=0 && i>sel_idx) begin
                    mem[i-1].r1_v   <=   CDB_3;
                    mem[i-1].busy_1 <=   1'b0;
                  end
                  else begin
                    mem[i].r1_v   <=   CDB_3;
                    mem[i].busy_1 <=   1'b0;
                  end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == CDB3_rob)) begin
                  if(output_valid && i!=0 && i>sel_idx) begin
                    mem[i-1].r2_v   <=   CDB_3;
                    mem[i-1].busy_2 <=   1'b0;
                  end
                  else begin
                    mem[i].r2_v   <=   CDB_3;
                    mem[i].busy_2 <=   1'b0;
                  end
                end
            end
        end
    
        if(CDB4_valid && !flush) begin
          // fl3 <= '1;
            // check all rs
            for(int i=0; i<size_; i++) begin
                //if busy_bit high && tag match
                if(mem[i].busy_1 && (mem[i].rs1_rob == CDB4_rob)) begin
                  if (output_valid && i!=0 && i>sel_idx) begin
                    fl3 <= '1;
                    mem[i-1].r1_v   <=   CDB_4;
                    mem[i-1].busy_1 <=   1'b0;
                  end
                  else begin
                    mem[i].r1_v   <=   CDB_4;
                    mem[i].busy_1 <=   1'b0;
                  end
                end
    
                if(mem[i].busy_2 && (mem[i].rs2_rob == CDB4_rob)) begin
                  if(output_valid && i!=0 && i>sel_idx) begin
                    mem[i-1].r2_v   <=   CDB_4;
                    mem[i-1].busy_2 <=   1'b0;
                  end
                  else begin
                    mem[i].r2_v   <=   CDB_4;
                    mem[i].busy_2 <=   1'b0;
                  end
                end
            end
        end

        if (rst || flush) begin
          for(int i = 0; i<size_; i++) begin
            // mem[i].taken <= '0;
            mem[i] <= '0;
            rvfi[i] <= '0;
          end
        end
      end
    
      
    
      assign output_valid = sel && !work && mem[sel_idx].taken && !flush;
      assign rs_out = mem[sel_idx];
      assign rvfi_out = rvfi[sel_idx];
    
    
      always_ff @(posedge clk) begin
        if (rst || flush) begin
          wrPtr <= '0;
        end else begin
          wrPtr <= wrPtrNext;
        end
      end
    
    
      
    
    endmodule


    


// module rs import rv32i_types::*;
//     #(
//       parameter  data_      = 32,                           //number of bits per line                    
//       parameter  size_      = 4,                            //number of lines in a queue
//       localparam ptr_       = $clog2(size_)                 //number of pointer bits needed for the correspond size_
//     ) (
//       input  logic          flush,
//       input  logic          clk,
//       input  logic          rst,
//       //from function unit
//       input  logic          work,
//       //rvfi signal
//       input rvfi_data rvfi_in,
//       output rvfi_data rvfi_out,
//       //things coming from dispatch
//       input  logic          dispatch,         //enque signal
//       //fill in struct
//       input  logic  [2:0]   aluop,
//       input  logic  [2:0]   cmpop,
//       input  logic  [1:0]   mulop,
//       input  logic  [6:0]   opcode,
//       input  logic  [4:0]   rd_s,
//       input  logic  [3:0]   rs1_rob,
//       input  logic  [3:0]   rs2_rob,
//       input  logic  [3:0]   rob_entry,
//       input  logic          busy_1,
//       input  logic          busy_2,
//       input  logic  [31:0]  r1_v,
//       input  logic  [31:0]  r2_v,
//       input  logic  [31:0]  pc,
//       input  logic  [31:0]  imm,

//       // input  logic          iq_re_in,
    
//       //coming from CDB value/valid/rob_tag to fill in a or b
//       //value
//       input  logic  [31:0]  CDB_1,  
//       input  logic  [31:0]  CDB_2,
//       input  logic  [31:0]  CDB_3,  
//       input  logic  [31:0]  CDB_4,
//       //valid
//       input  logic          CDB1_valid,
//       input  logic          CDB2_valid,
//       input  logic          CDB3_valid,
//       input  logic          CDB4_valid,
//       //rob_tag
//       input  logic  [3:0]   CDB1_rob,
//       input  logic  [3:0]   CDB2_rob,
//       input  logic  [3:0]   CDB3_rob,
//       input  logic  [3:0]   CDB4_rob,
    
//       //rs output to function unit based on ready bit
//       output logic          output_valid,
//       output rs_t           rs_out,
    
//       output logic          full,
//       output logic          empty
//     );
//       logic fl1, fl2, fl3, fl4, fl5;

//       rs_t mem[size_];
//       rvfi_data rvfi[size_];
    
//       // set extra bit to determine full/empty
//       logic [ptr_-1:0] wrPtr, wrPtrNext;              //head
    
//       //the index of the ready inst
//       // logic unsigned [ptr_-1:0] sel_idx;
//       int sel_idx;
//       //determine if we found a ready inst
//       logic            sel;
    
//       //empty = mem[0] not taken && wrptr at top
//       assign empty = (!mem[0].taken && (wrPtr == 2'b00));
//       //full = mem[last]
//       assign full  = (mem[3].taken && (wrPtr == 2'b11));
      
//       //update pointer 
//       always_comb begin
        
//         // default: keep same
//         wrPtrNext = wrPtr;
//         sel = 1'b0;
//         // sel_idx = 2'b00;
//         sel_idx = '0;
//         fl1 = '0;
    
//         // if only dispatch, enque
//         if (opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
//           if (!full && dispatch) begin
//               fl1 = '1;
//               if (wrPtr == (2'b11)) wrPtrNext = wrPtr;
//               else                    wrPtrNext = wrPtr + 1'b1;
//           end
//         end

//         //search for ready signal, then store the index
//         for (int i=0; i < size_; i++) begin
//           //if only deque
//           if (!work && !empty) begin
//             if (mem[i].opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
//               if (!mem[i].busy_1 && !mem[i].busy_2 && mem[i].taken) begin
//                 sel_idx = i;
//                 sel = 1'b1;
//                 if (full) begin
//                   wrPtrNext = wrPtr;
//                 end
//                 else begin
//                   wrPtrNext = wrPtr - 1'b1;
//                 end
//                 break;
//               end
//             end
//           end
//         end

//         //if dispatch and deque
//         if((!full && dispatch) && sel) begin
//           wrPtrNext = wrPtr;
//         end

//       end    
      
//       logic [1:0] f1,f2,f3,f4;

//       always_ff @( posedge clk ) begin 
//         //default
//         f1 <= '0;
//         f2 <= '0;
//         f3 <= '0;
//         f4 <= '0;
//         mem[wrPtr[ptr_-1:0]] <= mem[wrPtr[ptr_-1:0]];
//         rvfi[wrPtr[ptr_-1:0]] <=  rvfi[wrPtr[ptr_-1:0]];
        
        
//         if (rst || flush) begin
//           for(int i = 0; i<size_; i++) begin
//             // mem[i].taken <= '0;
//             mem[i] <= '0;
//             rvfi[i] <= '0;
//           end
//         end
//         //if a instruction is ready for execute
//         // if(sel && (sel_idx < (size_-1))) begin
//         if(sel) begin
//           //perform collapse
//           for(int i = 0; i<(size_-1); i++) begin
//             if(i >= sel_idx) begin
//               mem[i] <= mem[i+1];
//               rvfi[i] <= rvfi[i+1];
//             end
//           end
//         end
//         //if no dispatch and selected
//         if(sel) begin
//           mem[wrPtrNext].opcode       <= '0;
//           mem[wrPtrNext].rs1_rob      <= '0;
//           mem[wrPtrNext].rs2_rob      <= '0;
//           mem[wrPtrNext].rds          <= '0;
//           mem[wrPtrNext].rob_entry    <= '0;
//           mem[wrPtrNext].busy_1       <= '0;
//           mem[wrPtrNext].busy_2       <= '0;
//           mem[wrPtrNext].r1_v         <= '0;
//           mem[wrPtrNext].r2_v         <= '0;
//           mem[wrPtrNext].taken        <= '0;
//           mem[wrPtrNext].aluop        <= '0;
//           mem[wrPtrNext].cmpop        <= '0;
//           mem[wrPtrNext].mulop        <= '0;
//           mem[wrPtrNext].pc           <= '0;
//           mem[wrPtrNext].imm          <= '0;
//           // mem[wrPtr].iq_re        <= '0;
//           rvfi[wrPtrNext]             <= '0;
//         end

//         if (opcode inside {op_lui,op_auipc,op_jal,op_jalr,op_br,op_load,op_store,op_imm,op_reg}) begin
//           if(!full && dispatch && sel && !flush) begin
//             mem[wrPtr -1].opcode       <= opcode;
//             mem[wrPtr -1].rs1_rob      <= rs1_rob;
//             mem[wrPtr -1].rs2_rob      <= rs2_rob;
//             mem[wrPtr -1].rds          <= rd_s;
//             mem[wrPtr -1].rob_entry    <= rob_entry;
//             mem[wrPtr -1].busy_1       <= busy_1;
//             mem[wrPtr -1].busy_2       <= busy_2;
//             mem[wrPtr -1].r1_v         <= r1_v;
//             mem[wrPtr -1].r2_v         <= r2_v;
//             mem[wrPtr -1].taken        <= 1'b1;
//             mem[wrPtr -1].aluop        <= aluop;
//             mem[wrPtr -1].cmpop        <= cmpop;
//             mem[wrPtr -1].mulop        <= mulop;
//             mem[wrPtr -1].pc           <= pc;
//             mem[wrPtr -1].imm          <= imm;
//             // mem[wrPtr].iq_re        <= iq_re_in;
//             rvfi[wrPtr -1]             <= rvfi_in;
//           end

//           //when dispatch,update struct
//           else if(!full && dispatch && !flush) begin
//             f1 <= '1;
//             mem[wrPtr].opcode       <= opcode;
//             mem[wrPtr].rs1_rob      <= rs1_rob;
//             mem[wrPtr].rs2_rob      <= rs2_rob;
//             mem[wrPtr].rds          <= rd_s;
//             mem[wrPtr].rob_entry    <= rob_entry;
//             mem[wrPtr].busy_1       <= busy_1;
//             mem[wrPtr].busy_2       <= busy_2;
//             mem[wrPtr].r1_v         <= r1_v;
//             mem[wrPtr].r2_v         <= r2_v;
//             mem[wrPtr].taken        <= 1'b1;
//             mem[wrPtr].aluop        <= aluop;
//             mem[wrPtr].cmpop        <= cmpop;
//             mem[wrPtr].mulop        <= mulop;
//             mem[wrPtr].pc           <= pc;
//             mem[wrPtr].imm          <= imm;
//             // mem[wrPtr].iq_re     <= iq_re_in;
//             rvfi[wrPtr]             <= rvfi_in;
//           end
//         end
//         //when dispatch and deque happen same time, update struct at wrtptr - 1
        


//         //if cdb sends back valid data
//         if(CDB1_valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == CDB1_rob)) begin
//                     // f1 <= '1;
//                     if (output_valid && i!=0) begin
//                       mem[i-1].r1_v   <=   CDB_1;
//                       mem[i-1].busy_1 <=   1'b0;
//                     end
//                     else begin
//                       mem[i].r1_v   <=   CDB_1;
//                       mem[i].busy_1 <=   1'b0;
//                     end
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == CDB1_rob)) begin
//                     // f2 <= '1;
//                     if (output_valid && i!=0) begin
//                       mem[i-1].r2_v   <=   CDB_1;
//                       mem[i-1].busy_2 <=   1'b0;
//                     end
//                     else begin
//                       mem[i].r2_v   <=   CDB_1;
//                       mem[i].busy_2 <=   1'b0;
//                     end
//                 end
//             end
//         end
        
//         if(CDB2_valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == CDB2_rob)) begin

//                     if(output_valid && i!=0) begin
//                       mem[i-1].r1_v   <=   CDB_2;
//                       mem[i-1].busy_1 <=   1'b0;
//                     end
//                     else begin
//                       mem[i].r1_v   <=   CDB_2;
//                       mem[i].busy_1 <=   1'b0;
//                     end
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == CDB2_rob)) begin
//                   if (output_valid && i!=0) begin
//                     mem[i-1].r2_v   <=   CDB_2;
//                     mem[i-1].busy_2 <=   1'b0;
//                   end
//                   else begin
//                     mem[i].r2_v   <=   CDB_2;
//                     mem[i].busy_2 <=   1'b0;
//                   end
//                 end
//             end
//         end
    
//         if(CDB3_valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == CDB3_rob)) begin
//                   if (output_valid && i!=0) begin
//                     mem[i-1].r1_v   <=   CDB_3;
//                     mem[i-1].busy_1 <=   1'b0;
//                   end
//                   else begin
//                     mem[i].r1_v   <=   CDB_3;
//                     mem[i].busy_1 <=   1'b0;
//                   end
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == CDB3_rob)) begin
//                   if(output_valid && i!=0) begin
//                     mem[i-1].r2_v   <=   CDB_3;
//                     mem[i-1].busy_2 <=   1'b0;
//                   end
//                   else begin
//                     mem[i].r2_v   <=   CDB_3;
//                     mem[i].busy_2 <=   1'b0;
//                   end
//                 end
//             end
//         end
    
//         if(CDB4_valid && !flush) begin
//             // check all rs
//             for(int i=0; i<size_; i++) begin
//                 //if busy_bit high && tag match
//                 if(mem[i].busy_1 && (mem[i].rs1_rob == CDB4_rob)) begin
//                   if (output_valid && i!=0) begin
//                     mem[i-1].r1_v   <=   CDB_4;
//                     mem[i-1].busy_1 <=   1'b0;
//                   end
//                   else begin
//                     mem[i].r1_v   <=   CDB_4;
//                     mem[i].busy_1 <=   1'b0;
//                   end
//                 end
    
//                 if(mem[i].busy_2 && (mem[i].rs2_rob == CDB4_rob)) begin
//                   if(output_valid && i!=0) begin
//                     mem[i-1].r2_v   <=   CDB_4;
//                     mem[i-1].busy_2 <=   1'b0;
//                   end
//                   else begin
//                     mem[i].r2_v   <=   CDB_4;
//                     mem[i].busy_2 <=   1'b0;
//                   end
//                 end
//             end
//         end
//       end
    
      
    
//       assign output_valid = sel && !work && mem[sel_idx].taken && !flush;
//       assign rs_out = mem[sel_idx];
//       assign rvfi_out = rvfi[sel_idx];
    
    
//       always_ff @(posedge clk) begin
//         if (rst || flush) begin
//           wrPtr <= '0;
//         end else begin
//           wrPtr <= wrPtrNext;
//         end
//       end
    
    
      
    
//     endmodule