module regfile 
    import rv32i_types::*;
    #(
        parameter width = 32,
        parameter size = 16
    )

    (
        input logic flush,
        
        input logic clk,
        input logic rst,
        // ROB signal (when commit)
        input rob_t rdest,
        input logic [3:0]    ROB_commit_tag,
        input logic ready,
        //Dispatch stage signal
        input logic dispatch,
        input logic [$clog2(size)-1:0] rob_entry, // for rename
        input logic [4:0] rs1_s, rs2_s, rd_s,
        output reg_d rs_out,
        //Branch
        
        // output logic [31:0] br_addr,
        // output logic br_en,
        //output to ROB
        output logic tag1_valid,
        output logic tag2_valid,
        output logic [$clog2(size)-1:0] tag_out1, // send to ROB, and tell instruction to get the data from ROB
        output logic [$clog2(size)-1:0] tag_out2, // send to ROB, and tell instruction to get the data from ROB

        // output logic mem_flush,
        // output logic flush,

        //to bp
        output logic [31:0] br_addr,
        output logic br_en,
        output  logic [6:0] commit_opcode,
        output  logic       bp_ready
        
    );
//resigster file elements
    reg_t data[32];

    // assign flush = ready && rdest.br_en;

    // assign mem_flush   = ready && rdest.br_en;
    assign br_addr = rdest.br_target;
    assign br_en = rdest.br_en;
    assign commit_opcode = rdest.opcode;
    assign bp_ready = ready;
    
    logic f1, f2, f3;

//Get the rename ROB entry from Dispatch stage, set busy_bit to 1.
        always_ff@(posedge clk) begin
            f1 <= '0;
            f2 <= '0;
            f3 <= '0;



            // flush   <= '0;
            // br_addr <= '0;
            // br_en   <= '0;
            // commit_opcode <= '0;

            data[rd_s].tag <= data[rd_s].tag;
            data[rd_s].busy <= data[rd_s].busy;
            data[rd_s].value <= data[rd_s].value;
            // data[rd_s] <= data[rd_s];
            // data[rdest.rds] <= data[rdest.rds];
            //reset value
            if (rst) begin
                for (int i = 0; i < 32; i++) begin
                    data[i].tag <= '0;
                    data[i].busy <= '0;
                    data[i].value <= '0;
                end
            end

            if (dispatch && (rd_s != 0)) begin
                f2 <= '1;
                data[rd_s].tag <= rob_entry;
                data[rd_s].busy <= 1'b1;
                data[rd_s].value <=  data[rd_s].value;
            end

            //if rob commit
            if ((ready))begin
                f1 <= '1;
                //update flush
                // br_addr <= rdest.br_target;
                // br_en   <= rdest.br_en;
                // flush   <= rdest.br_en;
                // commit_opcode <= rdest.opcode;
                //update reg value
                data[rdest.rds].value <= rdest.ROB_val;
                //tag dont change
                data[rdest.rds].tag <= data[rdest.rds].tag;
                //if not edge case
                if (data[rdest.rds].tag == ROB_commit_tag) begin
                    //set busy to zero
                    data[rdest.rds].busy <= 1'b0;
                    //if at the same time dispatch = 1
                    if (dispatch && (rd_s != 0)) begin
                        //update rob entry and busy 
                        data[rd_s].tag <= rob_entry;
                        data[rd_s].busy <= 1'b1;
                    end
                    //if commit and no edge case
                    else begin
                        data[rdest.rds].busy <= 1'b0;;
                    end
                end
                else if (dispatch && (rd_s != 0)) begin
                    data[rd_s].tag <= rob_entry;
                end
                //if edge case
                else begin
                    data[rdest.rds].busy <= 1'b1;
                end
            end
                    
            // if (dispatch && (rd_s != 0)) begin
            //     f2 <= '1;
            //     data[rd_s].tag <= rob_entry;
            //     data[rd_s].busy <= 1'b1;
            //     data[rd_s].value <=  data[rd_s].value;
            // end

            if (flush) begin
                for (int i = 0; i < 32; i++) begin
                    data[i].tag <= '0;
                    data[i].busy <= '0;
                end
            end


            //if not commit and not dispatch, do nothing
            // else begin
            //     data[rd_s].tag <= data[rd_s].tag;
            //     data[rd_s].busy <= data[rd_s].busy;
            //     data[rd_s].value <= data[rd_s].value;
            // end
        end


// Store the data from ROB
// because register destination x0 means 0, it doesn't mean anything if u write to it
        // always_ff @(posedge clk) begin
        //     if (rst) begin
        //         for (int i = 0; i < 32; i++) begin
        //             data[i].value <= '0;
        //             data[i].busy <= '0;
        //         end
        //     end 
        //     else if ((ready) && (rd_s != 5'd0) ) begin // ready to commit, but we need to make sure there is no repeated rd_s inside the ROB ! 
        //         data[rdest.rds].value <= rdest.ROB_val;
        //         if(data[rdest.rds].tag == ROB_commit_tag) begin
        //             data[rdest.rds].busy <= 1'b0;
        //         end
        //     end
        //     else begin
        //         data[rdest.rds].value <= data[rdest.rds].value;
        //         data[rdest.rds].busy <= data[rdest.rds].busy ;

        //     end

        // end

//Give data to Reservation station
        always_comb begin
            if(data[rs1_s].busy== 1'b1) begin
                tag_out1 = data[rs1_s].tag;
                tag1_valid = 1'b1;
                rs_out.r1_v = 32'b0;
                rs_out.r1_valid = (rs1_s == '0) ? 1'b1: 1'b0;
            end
            else begin
                rs_out.r1_v = (rs1_s != 5'd0) ? data[rs1_s].value: '0;
                tag1_valid = 1'b0;
                tag_out1 = 4'd0;
                rs_out.r1_valid = 1'b1;
                end
        end

        always_comb begin
            if(data[rs2_s].busy == 1'b1) begin
                tag_out2 = data[rs2_s].tag;
                tag2_valid = 1'b1;
                rs_out.r2_v = 32'b0;
                rs_out.r2_valid =(rs2_s == '0) ? 1'b1:   1'b0;
            end
            else begin
                rs_out.r2_v = (rs2_s != 5'd0) ? data[rs2_s].value : '0;
                tag2_valid = 1'b0;
                tag_out2 = 4'd0;
                rs_out.r2_valid = 1'b1;
            end
        end
                 
endmodule 