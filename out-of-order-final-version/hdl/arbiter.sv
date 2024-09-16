module arbiter
    (
        input clk,
        input rst,
        // mem ~~ adaptor
        /* signals to/from caches */
        //******from cache**************//
        input [255:0] d_cache_wdata, //from dfp_wdata

        input [31:0] i_cache_address,// from dfp_addr
        input [31:0] d_cache_address, 

        input logic i_cache_read,// from dfp_read
        input logic d_cache_read,

        input logic d_cache_write,// from dfp_write
        //******from adaptor to cache**********//

        output logic i_cache_resp, // from L2_cache
        output logic d_cache_resp,


        output [255:0] i_cache_rdata, // from lint_out 
        output [255:0] d_cache_rdata,
       
        
        //********* signals to/from adaptor ***************//
        input logic L2_cache_resp,// from L2_cache
        input [255:0] L2_cache_rdata, // from lint_out 

        output [255:0] L2_cache_wdata, // from dfp_wdata to adaptor 
        output [31:0] L2_cache_address, // from dfp_addr to adaptor
        output logic L2_cache_read, // to adaptor
        output logic L2_cache_write // to adaptor 
        //***************Freeze cache***************************

    );
    
    logic [1:0] mux_sel;
    logic [31:0] prefetch_addr_hold;
    logic p_read;
    



    arbiter_control arbiter_control
    (   
        .*
    );
    
    assign i_cache_resp = ( mux_sel == 2'b00)? L2_cache_resp: 1'b0;
    assign d_cache_resp = ( mux_sel == 2'b01 )? L2_cache_resp : 1'b0;


    assign i_cache_rdata = (mux_sel == 2'b00)? L2_cache_rdata : 0;
    assign d_cache_rdata = (mux_sel == 2'b01)? L2_cache_rdata : 0; 

    assign L2_cache_wdata = d_cache_wdata;
    
    
    MUX addr
    (
        .sel(mux_sel),
        .a(i_cache_address),
        .b(d_cache_address),
        .c(prefetch_addr_hold),
        .f(L2_cache_address)
    );
    MUX #(.width(1)) read
    (
        .sel(mux_sel),
        .a(i_cache_read),
        .b(d_cache_read),
        .c(p_read),
        .f(L2_cache_read)
    );
    MUX #(.width(1)) write
    (
        .sel(mux_sel),
        .a(1'b0),
        .b(d_cache_write),
        .c(1'b0),
        .f(L2_cache_write)
    );

    
    endmodule : arbiter