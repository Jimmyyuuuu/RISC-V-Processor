module arbiter_control
    (
         input clk,
         input rst,
         input logic i_cache_read,
         input logic d_cache_read,
         // for prefetcher
         input logic [31:0] i_cache_address,
         input logic d_cache_write,
         input logic L2_cache_resp,
         output logic [1:0] mux_sel,
         output logic [31:0] prefetch_addr_hold,
         output logic p_read
    );
    logic prefetch_done_hold;
    logic [31:0]prefetch_addr;
    enum logic [2:0] {
        idle,
        service_i,
        service_d,
        service_p
    } state, next_state;
    
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= idle;
        end else begin
            state <= next_state;
        end
    end
//serve dcache first
    
    always_comb begin 
        mux_sel = 2'b01;
        next_state = state;
        p_read = 1'b0;
        case(state)
            idle: begin
            mux_sel=2'b01;
            if ((d_cache_read || d_cache_write ) && !L2_cache_resp)
            next_state = service_d;    
            else if ((i_cache_read && !(d_cache_read || d_cache_write )) && !L2_cache_resp)
            next_state = service_i;
            else if(!prefetch_done_hold)
            next_state = service_p;
            end

            service_i: begin 
            mux_sel = 2'b00;
            //update address to prefetch address
            // prefetch_done = 1'b0;
            prefetch_addr = i_cache_address +32'h20;
            if (L2_cache_resp) 
                next_state = idle;
            end 

            service_d: begin 
            mux_sel = 2'b01;
            if (L2_cache_resp) 
                next_state = idle;
            end
        

            service_p : begin
            mux_sel = 2'b10;
            p_read = 1'b1;
            if(L2_cache_resp)
                next_state = idle;
            end
            default: next_state = idle;
            
        endcase
    end 


    always_ff@(posedge clk) begin
        if(rst) begin
            prefetch_addr_hold <= 32'b0;
        end
        else if (state == service_i)begin
            prefetch_addr_hold <= i_cache_address + 32'h20;
        end
        else
            prefetch_addr_hold <= prefetch_addr_hold ;
    end
    always_ff@(posedge clk) begin
        if(rst) begin
            prefetch_done_hold <= 1'b1;
        end
        else if (state == service_i)
            prefetch_done_hold <= 1'b0;
        else if (state == service_p && L2_cache_resp)
            prefetch_done_hold <= 1'b1;
    end


    endmodule : arbiter_control