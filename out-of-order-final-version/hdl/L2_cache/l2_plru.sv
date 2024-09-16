module l2_plru
#(
    parameter s_offset = 5,
    parameter s_index  = 4 ,
    parameter s_tag    = 32 - s_offset - s_index,
    parameter s_bytes   = 2**s_offset, //32 bytes
    parameter s_line   = 8*s_bytes,
    parameter num_sets = 2**s_index,
    parameter s_address = 2**s_offset
)

(
    input logic clk,
    input logic rst,
    //input logic tag_hit,
    input logic [s_index-1:0] set_index, //connect from cpu_address_set
    input logic plru_we,
    input logic [1:0] mru,
    output logic [1:0] plru,
    output logic [2:0] status [num_sets-1:0]
);
//each set has one plru
always_ff@(posedge clk ) begin
    if(rst) begin
        for(int i = 0; i<num_sets; i++) begin
        status[i] <= 3'b000;
    end
    end
    else if (plru_we) begin
        status[set_index][2] <= mru[1]; // choose way0,way1 or way2,way3
    // if mru[1] == 0, It will be AB, then status[0] remains same    
    // if mru[1] == 1, it will be CD, then status[1] remains same
        status[set_index][1] <= (mru[1]) ? status[set_index][1] : mru[0];
        status[set_index][0] <= (mru[1]) ? mru[0] : status[set_index][0];
    end
    else
        status <= status;
end

always_comb begin
    if(status[set_index][2]) begin
        plru = {status[set_index][2],status[set_index][1]};
    end
    else
        plru = {status[set_index][2:1]};
end

endmodule
        