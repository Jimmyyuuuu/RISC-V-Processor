module mul
    import rv32i_types::*;
    
    (
    input rvfi_data rvfi_in,
    output rvfi_data rvfi_out,
    input logic done,
    input logic [1:0] mulop,
    input logic [63:0] p,
    output logic [31:0] mulout  
    
    );
    
    logic [31:0] p_1;
    
    always_comb begin
        p_1 = 32'd0;
    if (done) begin 
        if (mulop inside {mulh, mul})
         p_1 = p [31:0];
        else
         p_1 = p [63:32]; 
        end
    else 
        p_1 = 32'd0;
    end 
    
    assign mulout = p_1;
    
    always_comb begin
        rvfi_out = rvfi_in;
        rvfi_out.rd_wdata = p_1;
    end
    endmodule 