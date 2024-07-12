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

        output logic i_cache_resp, // from adaptor_dfp_resp
        output logic d_cache_resp,


        output [255:0] i_cache_rdata, // from lint_out 
        output [255:0] d_cache_rdata,
       
        
        //********* signals to/from adaptor ***************//
        input logic adaptor_resp,// from adaptor_dfp_resp
        input [255:0] adaptor_rdata, // from lint_out 

        output [255:0] adaptor_wdata, // from dfp_wdata to adaptor 
        output [31:0] adaptor_address, // from dfp_addr to adaptor
        output logic adaptor_read, // to adaptor
        output logic adaptor_write // to adaptor 
        //***************Freeze cache***************************

    );
    
    logic mux_sel;
    



    arbiter_control arbiter_control
    (
        .*
    );
    
    assign i_cache_resp = mux_sel? 1'b0 : adaptor_resp;
    assign d_cache_resp = mux_sel? adaptor_resp : 1'b0;


    assign i_cache_rdata = mux_sel? 0 : adaptor_rdata;
    assign d_cache_rdata = mux_sel? adaptor_rdata : 0; 

    assign adaptor_wdata = d_cache_wdata;
    

    MUX addr
    (
        .sel(mux_sel),
        .a(i_cache_address),
        .b(d_cache_address),
        .f(adaptor_address)
    );
    MUX #(.width(1)) read
    (
        .sel(mux_sel),
        .a(i_cache_read),
        .b(d_cache_read),
        .f(adaptor_read)
    );
    MUX #(.width(1)) write
    (
        .sel(mux_sel),
        .a(1'b0),
        .b(d_cache_write),
        .f(adaptor_write)
    );
    
    endmodule : arbiter