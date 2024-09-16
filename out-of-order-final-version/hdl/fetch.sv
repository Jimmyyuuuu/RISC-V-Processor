module fetch
(
    input   logic           bp_full,
    input   logic           rst,
    input   logic           clk,
    input   logic           imem_resp,
    // input  logic            br_en,
    // input  logic   [31:0]   br,

    // prediction
    input   logic           bp_taken,
    input   logic   [31:0]  bp_target_addr,

    // mispredict
    input   logic           mispredict,
    input   logic   [31:0]  recover_addr,

    input   logic           freeze,       //freeze pc
    input   logic           imem_stall, // imem_resp stall

    //for memory
    output  logic   [31:0]  imem_addr,
    output  logic   [3:0]   imem_rmask

);
    // tmp var/////////////////
    // logic           br_en;
    // logic   [31:0]  br;
    // logic           freeze;

    // assign br_en    =   1'b0;
    // assign br       =   32'b0; 
    // assign freeze   =   1'b0;
    ///////////////////////////


    logic   [31:0]  pc_next;
    logic   [31:0]  pc;


    //choose between branch or pc+4
    //FUTURE :  add branch prediction
    // always_comb begin 
    //     unique case (br_en) // br_en  br_en late
    //         1'b0    :   pc_next = pc +32'd4;
    //         1'b1    :   pc_next = br;
    //         default :   pc_next = '0;
    //     endcase
    // end

    // logic tmp_br_en;
    // logic [31:0] tmp_br_targ;

    // always_ff @(posedge clk) begin
        
    //     if (rst) begin
    //         tmp_br_en       <=  '0;
    //         tmp_br_targ     <=  '0;
    //     end
    //     else if (br_en) begin
    //         tmp_br_en       <=  '1;
    //         tmp_br_targ     <=  br;
    //     end
    //     else if (imem_resp )begin
    //         tmp_br_en       <=  '0;
    //         tmp_br_targ     <=  '0;
    //     end
    //     else begin
    //         tmp_br_en       <=  tmp_br_en;
    //         tmp_br_targ     <=  tmp_br_targ;
    //     end

    // end

    logic   tmp_bp_taken, tmp_mispredict;
    logic   [31:0]  tmp_bp_target_addr, tmp_recover_addr;

    always_ff @(posedge clk) begin
        
        if (rst) begin
            tmp_bp_taken    <=  '0;
            tmp_bp_target_addr    <=  '0;
        end
        else if (bp_taken) begin
            tmp_bp_taken    <=  '1;
            tmp_bp_target_addr    <=  bp_target_addr;
        end
        
        else if (imem_resp )begin
            tmp_bp_taken    <=  '0;
            tmp_bp_target_addr    <=  '0;
        end
        else begin
            tmp_bp_taken    <=  tmp_bp_taken;
            tmp_bp_target_addr    <=  tmp_bp_target_addr;
        end
    end

    always_ff @(posedge clk) begin
        
        if (rst) begin
            tmp_mispredict    <=  '0;
            tmp_recover_addr    <=  '0;
        end
        else if (mispredict) begin
            tmp_mispredict    <=  '1;
            tmp_recover_addr    <=  recover_addr;
        end
        
        else if (imem_resp )begin
            tmp_mispredict    <=  '0;
            tmp_recover_addr    <=  '0;
        end
        else begin
            tmp_mispredict    <=  tmp_mispredict;
            tmp_recover_addr    <=  tmp_recover_addr;
        end
    end
    

    // always_comb begin 
    //     unique case (br_en || tmp_br_en) // br_en  br_en late
    //         1'b0    :   pc_next = pc +32'd4;
    //         1'b1    :   pc_next = freeze ? br : tmp_br_targ;
    //         default :   pc_next = '0;
    //     endcase
    // end

    always_comb begin 
        if (mispredict || tmp_mispredict) pc_next = (freeze||bp_full) ? recover_addr : tmp_recover_addr;
        // else if (bp_taken || tmp_bp_taken) pc_next = freeze  ? bp_target_addr : tmp_bp_target_addr;
        else if (bp_taken ) pc_next = bp_target_addr;
        else pc_next = pc + 32'd4;
    end


    // keep a copy of the current pc
    always_ff @( posedge clk ) begin
        if (imem_resp || freeze || imem_stall || bp_full) begin
            pc <= imem_addr;
        end
        else begin
            pc <= 32'h60000000;
        end
    end

    // take care of freeze, or else increment normally
    always_comb begin 
        unique case (imem_resp && !freeze && !imem_stall && !bp_full)
            1'b0    :   imem_addr = pc;
            1'b1    :   imem_addr = pc_next;
            default :   imem_addr = '0;
        endcase
    end

    // set instruction cache rmask
    assign imem_rmask = 4'b1111;

    // assign valid = 1'b1;

endmodule   :   fetch