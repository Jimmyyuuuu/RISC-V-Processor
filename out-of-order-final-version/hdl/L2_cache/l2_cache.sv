module l2_cache #(
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
    //arbiter <-> L2 Cache
    //input
    input logic [s_address-1 : 0] arbiter_address,
    input logic arbiter_write,
    input logic arbiter_read,
    input logic [s_line-1 : 0 ] arbiter_wdata,
    //output
    output logic arbiter_resp,
    output logic [s_line-1 : 0 ] arbiter_rdata,
//************************************************************
    //L2 Cache <-> adaptor
    //input
    input logic [s_line-1 : 0] adaptor_rdata,
    input logic adaptor_dfp_resp,
    //output
    output logic [s_address-1 : 0] adaptor_address,
    output logic [s_line-1 : 0 ] adaptor_wdata,
    output logic adaptor_read, // to adaptor
    output logic adaptor_write // to adaptor  

);

// address -> tag,set,offset

logic [s_tag -1 :0] cpu_address_tag ;
logic [s_index -1 :0]  cpu_address_set ;
logic [s_offset -1 :0]  cpu_address_offset ;

// cpu address
assign cpu_address_tag = arbiter_address[31:s_offset +s_index ];
assign cpu_address_set = arbiter_address[s_offset +s_index -1 :5] ;
assign cpu_address_offset = {arbiter_address[4:2], {2{1'b0}}};



// data_array
logic [s_line -1 :0] data_array_din;
logic [s_line -1 :0] data_array_dout[4];
logic [3:0] data_array_web;
logic [31:0]  data_array_wmask;



//tag_array
logic dirty_in;
logic dirty_out[4];
// logic [22:0] tag_array_din;
logic [s_tag -1:0] tag_array_dout [4];
logic  [3:0] tag_array_web;

// valid_array
logic valid_out[4];
logic [3:0] valid_web;

//plru
logic [2:0] status_mru [num_sets-1:0];
logic [1:0] plru_way;
logic [1:0] plru;
logic       plru_we;
// //*****************Fix Read/Write signal********************************
//   logic read_data_signal;
//   logic write_data_signal;

//   always_comb begin
//     if()



//******************Finite state Machine**********************************
        enum int unsigned
        {
            idle, 
            compare_tag,
            dummy, 
            allocate,
            write_back          
        } state, next_state;

        always_ff@(posedge clk) begin
            if(rst) begin
                state <= idle;
            end
            else begin
                state <= next_state;
            end
        end

    




// hit signal / dirty
    logic [3:0] way_hit;
    logic tag_hit;    
    logic dirty;
    logic [1:0] way_dex; //connect to the plru input mru
    logic [1:0] way_select;


        
    
        //compare tag:
        always_comb begin
            way_hit[3] = ((tag_array_dout[3][s_tag-1:0] == cpu_address_tag) && valid_out[3]);
            way_hit[2] = ((tag_array_dout[2][s_tag-1:0] == cpu_address_tag) && valid_out[2]);
            way_hit[1] = ((tag_array_dout[1][s_tag-1:0] == cpu_address_tag) && valid_out[1]);
            way_hit[0] = ((tag_array_dout[0][s_tag-1:0] == cpu_address_tag) && valid_out[0]);
            tag_hit = ( way_hit[3]|| way_hit[2] || way_hit[1] || way_hit[0]);
        end


    
          // way_dex (input for the plru, index_fourway)
        always_comb begin : decode_way_hit
            case(way_hit)
                4'b0001 : way_dex = 2'b00; // hit way 0
                4'b0010 : way_dex = 2'b01; // hit way 1
                4'b0100 : way_dex = 2'b10; // hit way 2
                4'b1000 : way_dex = 2'b11; // hit way 3
                default : way_dex = 2'bxx;
            endcase
        end
     //plru here is mru, but we want to choose the lru (so the logic should be opposite)
    l2_plru plru_state(
        .clk(clk),
        .rst(rst),
        .set_index(cpu_address_set),
        .plru_we(plru_we),
        .mru(way_dex),
        .plru(plru),
        .status(status_mru)
        );
    always_comb begin
        if(status_mru[cpu_address_set][2] == '0) begin
            if(status_mru[cpu_address_set][0] == '0) begin
                plru_way = 2'b11;
            end
            else begin
                plru_way = 2'b10;
            end
        end
        else begin //status[cpu_address_set][2] == '1
            if(status_mru[cpu_address_set][1] =='0) begin
                plru_way = 2'b01;
            end
            else begin
                plru_way = 2'b00;
            end
        end
        end

//******************************************FSM****************************************************
        always_comb begin
            // way select from plru or hit-way
            way_select = (tag_hit) ? way_dex : plru_way;
            //this dirty means when I get a miss, I will check whether dirty bit is 1?
            dirty = dirty_out[way_select] && valid_out[way_select] ;
            adaptor_read = 1'b0;
            adaptor_write = 1'b0;
            arbiter_rdata = '0;
            dirty_in = 1'b0;
            adaptor_wdata = '0;
            arbiter_resp = 1'b0;
            adaptor_address = '0;
            data_array_din = '0;
            data_array_web = 4'hf;
            tag_array_web = 4'hf;
            valid_web = 4'hf;
            plru_we = 1'b0;
            case (state)
                idle : begin
                end
                compare_tag : begin
                    //hit
                    arbiter_resp = tag_hit;
                    if(tag_hit) begin
                        plru_we = 1'b1;
                        //read hit
                        if(arbiter_read) begin
                            arbiter_rdata = data_array_dout[way_select];
                        end
                    //write hit
                        else if(arbiter_write) begin
                            data_array_web = {~way_hit[3], ~way_hit[2], ~way_hit[1], ~way_hit[0]};
                            tag_array_web  = {~way_hit[3], ~way_hit[2], ~way_hit[1], ~way_hit[0]};
                        //offset can move to any word in data_array(total 8 words), 1 word = 4bytes, 1 bytes = 8bits
                            data_array_din = arbiter_wdata ;
                            dirty_in = 1'b1; // set dirty to one, when it is a write !
                        end
                    end

                end
                dummy : begin
                end

                //for a read miss, if we get the data from DRAM, we 
                allocate : begin
                    //read data from memory
                    adaptor_read = 1'b1;
                    adaptor_write = 1'b0;
                    //we have to set the address(tag, set, valid) and mask first before the adaptor_dfp_resp
                    //adaptor_dfp_resp means, we get the data from memory, but before this, we need to give it an address
                    adaptor_address = {arbiter_address[31:5], 5'b00000};
                    if(adaptor_dfp_resp) begin
                        valid_web = ~({{3{1'b0}}, 1'b1} << plru_way);
                        data_array_web = ~({{3{1'b0}}, 1'b1} << plru_way);
                        tag_array_web  = ~({{3{1'b0}}, 1'b1} << plru_way);
                        data_array_din = adaptor_rdata;
                        dirty_in = 1'b0;
                    end
                    else begin
                        valid_web = 4'hf;
                        data_array_web = 4'hf;
                        tag_array_web  = 4'hf;
                    end

                    end
                    
                write_back : begin
                    adaptor_read = 1'b0;
                    adaptor_write = 1'b1;
                    adaptor_address={tag_array_dout[way_select], cpu_address_set, {5{1'b0}}};
                    adaptor_wdata = data_array_dout[way_select];
                    end
            endcase
        end
            
            

        // State to State
        always_comb begin

            case(state) 
                idle        : next_state = (arbiter_write || arbiter_read) ? compare_tag : idle;
                compare_tag : next_state = tag_hit ? idle : (dirty) ? write_back : allocate;
                allocate    : next_state = adaptor_dfp_resp ? dummy : allocate ;
                dummy       : next_state = compare_tag;
                write_back  : next_state = adaptor_dfp_resp ? allocate : write_back ;
                default : next_state = idle;
            endcase
        end


///******************4 ways per set, these all things is cache**********************
//Active low chip select(csb0), assert this when you need to read or write. 
//You can have it permanently asserted for this MP.
        generate for (genvar i = 0; i < 4; i++) begin : arrays
            L2_cache_data_array data_array (
                .clk0       (clk),
                .csb0       (1'b0),
                .web0       (data_array_web[i]),
                .wmask0     ('1),
                .addr0      (cpu_address_set),
                .din0       (data_array_din),
                .dout0      (data_array_dout[i])
            );
            L2_cache_tag_array tag_array (
                .clk0       (clk),
                .csb0       (1'b0),
                .web0       (tag_array_web[i]),
                .addr0      (cpu_address_set),
                .din0       ({dirty_in,cpu_address_tag}),
                .dout0      ({dirty_out[i],tag_array_dout[i]})
            );
            l2_ff_array #(.WIDTH(1)) valid_array (
                .clk0       (clk),
                .rst0       (rst),
                .csb0       (1'b0),
                .web0       (valid_web[i]),
                .addr0      (cpu_address_set),
                .din0       (1'b1), // because, whenever the valid = 1'b1, it will never be 0 again!
                .dout0      (valid_out[i])
            );
        end endgenerate
    





endmodule