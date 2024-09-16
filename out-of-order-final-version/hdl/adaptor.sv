module adaptor
    (
        input clk,
        input rst,
    
        // Port to cache
        input logic [255:0] line_in, // for dfp_wdata 
        output logic [255:0] line_out, // for dfp_rdata
        input logic [31:0] address_in, // for dfp_addr
        input dfp_read, // for dfp_read 
        input dfp_write, // for dfp_write 
        output logic adaptor_dfp_resp, //for dsp_resp 
    
        // Port to memory
        input logic [63:0] burst_in,
        output logic [63:0] burst_out,
        output logic [31:0] address_out, // for bmem_addr
        output logic  bmem_read, // for bmem_read 
        output logic bmem_write, // for bmem_write 
        input logic         bmem_rvalid  // for bmem_rvalid 
    );

  
    
    logic [63:0] buffer [0:3];

    enum logic [3:0] {
        IDLE, 
        Readcc1, 
        Readcc2, 
        Readcc3, 
        Readcc4, 
        Writecc1,
        Writecc2, 
        Writecc3, 
        Writecc4, 
        DONE
    } state, next_state;
    
    
    always_ff @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else begin
            state <= next_state;
            if ( bmem_rvalid)
                {  buffer[3], buffer[2], buffer[1], buffer[0]} <=  {  burst_in, buffer[3], buffer[2], buffer[1]};
        end
    end
    
    
    always_comb begin
    
        bmem_read = 1'b0;
        bmem_write = 1'b0;
        adaptor_dfp_resp = 1'b0;
        burst_out = 64'h0;
        next_state = state;
        address_out = 32'd0;
        line_out = {buffer[3], buffer[2], buffer[1], buffer[0]};
    
        unique case (state)

            IDLE: begin
                if (dfp_read) begin
                    address_out = address_in;
                    next_state = Readcc1;
                    bmem_read = 1'b1;
                end else if (dfp_write) begin
                    address_out = address_in;
                    next_state = Writecc1;
                end
            end
    
            Readcc1: begin 
            bmem_read = 1'b0;
            if ( bmem_rvalid)
            next_state = Readcc2;   
            end
            Readcc2: begin 
            if ( bmem_rvalid) 
            next_state = Readcc3;    
            end
            Readcc3: begin 
            if ( bmem_rvalid) 
            next_state = Readcc4;   
            end
            Readcc4: begin 
            if ( bmem_rvalid) 
            next_state = DONE; 
            end
            Writecc1: begin 
            address_out=address_in;
            // if ( bmem_rvalid)
            next_state = Writecc2;   
            bmem_write = 1'b1; 
            burst_out = line_in[63:0]; 
            end
            Writecc2: begin 
            // if ( bmem_rvalid) 
            address_out=address_in;
            next_state = Writecc3;   
            bmem_write = 1'b1; 
            burst_out = line_in[127:64]; 
            end
            Writecc3: begin 
            // if ( bmem_rvalid) 
            address_out=address_in;
            next_state = Writecc4;   
            bmem_write = 1'b1; 
            burst_out = line_in[191:128]; 
            end
            Writecc4: begin 
            // if ( bmem_rvalid) 
            address_out=address_in;
            next_state = DONE; 
            bmem_write = 1'b1; 
            burst_out = line_in[255:192]; 
            end
    
            DONE: begin
                next_state = IDLE;
                adaptor_dfp_resp = 1'b1;
                bmem_read = 1'b0;
                bmem_write = 1'b0;
            end
    
            default: next_state = IDLE;
    
        endcase
    
    end
    
    
    endmodule : adaptor