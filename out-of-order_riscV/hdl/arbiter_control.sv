module arbiter_control
    (
         input clk,
         input rst,
         input logic i_cache_read,
         input logic d_cache_read,
         input logic d_cache_write,
         input logic adaptor_resp,
         output logic mux_sel
    );
    
    enum logic [2:0] {
        idle,
        service_i,
        service_d
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
        mux_sel = '1;
        next_state = state;
        case(state)
            idle: begin
            mux_sel='1;
            if ((d_cache_read || d_cache_write ) && !adaptor_resp)
            next_state = service_d;    
            else if ((i_cache_read && !(d_cache_read || d_cache_write )) && !adaptor_resp)
            next_state = service_i;
            end
            service_i: begin 
            mux_sel = '0;
            if (adaptor_resp) 
            next_state = idle;
            end 
            service_d: begin 
            mux_sel = '1;
            if (adaptor_resp) 
            next_state = idle;
            end 
            default: next_state = idle;
        endcase
    end
    
    endmodule : arbiter_control