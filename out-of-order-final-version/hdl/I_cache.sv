module I_cache (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    // output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    // output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);
// address -> tag,set,offset

logic [22:0] cpu_address_tag ;
logic [3:0]  cpu_address_set ;
logic [4:0]  cpu_address_offset ;
//for pipeline cache
logic [22:0] cpu_address_tag_late ;
logic [3:0]  cpu_address_set_late ;
logic [4:0]  cpu_address_offset_late ;


// cpu address
assign cpu_address_tag = ufp_addr[31:9];
assign cpu_address_set = ufp_addr[8:5] ;
assign cpu_address_offset = {ufp_addr[4:2], {2{1'b0}}};



// data_array
logic [255:0] data_array_din;
logic [255:0] data_array_dout[4];
logic [3:0] data_array_web;
logic [31:0]  data_array_wmask;



//tag_array
logic dirty_in;
logic dirty_out[4];
// logic [22:0] tag_array_din;
logic [22:0] tag_array_dout [4];
logic  [3:0] tag_array_web;

// valid_array
logic valid_out[4];
logic [3:0] valid_web;

//plru
logic [2:0] status_mru [15:0];
logic [1:0] plru_way;
logic [1:0] plru;
logic       plru_we;

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
//***************offset bits for wmask to choose which byte I want to read from 32 bytes data
        
        always_comb begin
        if(state == allocate) begin // because we want to write all 32bytes data to cache from memory
            data_array_wmask =  32'hffffffff;
        end
        else
            data_array_wmask = {28'b0 ,ufp_wmask} << cpu_address_offset;
        end       





// hit signal / dirty
    logic [3:0] way_hit;
    logic tag_hit;    
    logic dirty;
    logic [1:0] way_dex; //connect to the plru input mru
    logic [1:0] way_select;


        
    
        //compare tag:
        always_comb begin
            way_hit[3] = ((tag_array_dout[3][22:0] == cpu_address_tag_late) && valid_out[3]);
            way_hit[2] = ((tag_array_dout[2][22:0] == cpu_address_tag_late) && valid_out[2]);
            way_hit[1] = ((tag_array_dout[1][22:0] == cpu_address_tag_late) && valid_out[1]);
            way_hit[0] = ((tag_array_dout[0][22:0] == cpu_address_tag_late) && valid_out[0]);
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


        //for pipeline cache
        always_ff@(posedge clk) begin
            if(rst) begin
                cpu_address_tag_late <= '0;
                cpu_address_set_late <= '0;
                cpu_address_offset_late <= '0;
            end
            //first time request must in idle
            else if (state == idle) begin
                cpu_address_tag_late <= cpu_address_tag;
                cpu_address_set_late <= cpu_address_set;
                cpu_address_offset_late <= cpu_address_offset;
            end
            //after first time, the state will never go back to idle, so whenever is hit, the request can send immediately to compare tag state.
            //pipeline cache, sending new request from cpu, whenever is hit
            else if ((state == compare_tag)&& tag_hit) begin
                cpu_address_tag_late <= cpu_address_tag;
                cpu_address_set_late <= cpu_address_set;
                cpu_address_offset_late <= cpu_address_offset;
            end
            else begin
                cpu_address_tag_late <= cpu_address_tag_late;
                cpu_address_set_late <= cpu_address_set_late;
                cpu_address_offset_late <= cpu_address_offset_late;
            end
        end


    //plru here is mru, but we want to choose the lru (so the logic should be opposite)
    plru plru_state(
        .clk(clk),
        .rst(rst),
        .set_index(cpu_address_set_late),
        .plru_we(plru_we),
        .mru(way_dex),
        .plru(plru),
        .status(status_mru)
        );
    always_comb begin
        if(status_mru[cpu_address_set_late][2] == '0) begin
            if(status_mru[cpu_address_set_late][0] == '0) begin
                plru_way = 2'b11;
            end
            else begin
                plru_way = 2'b10;
            end
        end
        else begin //status[cpu_address_set][2] == '1
            if(status_mru[cpu_address_set_late][1] =='0) begin
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
            dfp_read = 1'b0;
            // dfp_write = 1'b0;
            ufp_rdata = 32'd0;
            dirty_in = 1'b0;
            // dfp_wdata = 32'd0;
            ufp_resp = 1'b0;
            dfp_addr = '0;
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
                    ufp_resp = tag_hit;
                    if(tag_hit) begin
                        plru_we = 1'b1;
                        //read hit
                        if(|ufp_rmask) begin
                            ufp_rdata = data_array_dout[way_select][cpu_address_offset_late[4:2]*32 +: 32];
                        end
                    //write hit
                        else if(|ufp_wmask) begin
                            data_array_web = {~way_hit[3], ~way_hit[2], ~way_hit[1], ~way_hit[0]};
                            tag_array_web  = {~way_hit[3], ~way_hit[2], ~way_hit[1], ~way_hit[0]};
                        //offset can move to any word in data_array(total 8 words), 1 word = 4bytes, 1 bytes = 8bits
                            data_array_din = {{224{1'b0}}, ufp_wdata} << (cpu_address_offset_late*8);
                            dirty_in = 1'b1; // set dirty to one, when it is a write !
                        end
                    end

                end
                dummy : begin
                end

                //for a read miss, if we get the data from DRAM, we 
                allocate : begin
                    //read data from memory
                    dfp_read = 1'b1;
                    // dfp_write = 1'b0;
                    //we have to set the address(tag, set, valid) and mask first before the dfp_resp
                    //dfp_resp means, we get the data from memory, but before this, we need to give it an address
                    dfp_addr = {cpu_address_tag_late,cpu_address_set_late, 5'b00000};
                    if(dfp_resp) begin
                        valid_web = ~({{3{1'b0}}, 1'b1} << plru_way);
                        data_array_web = ~({{3{1'b0}}, 1'b1} << plru_way);
                        tag_array_web  = ~({{3{1'b0}}, 1'b1} << plru_way);
                        data_array_din = dfp_rdata;
                        dirty_in = 1'b0;
                    end
                    else begin
                        valid_web = 4'hf;
                        data_array_web = 4'hf;
                        tag_array_web  = 4'hf;
                    end

                    end
                    
                // write_back : begin
                //     dfp_read = 1'b0;
                //     dfp_write = 1'b1;
                //     dfp_addr={tag_array_dout[way_select], cpu_address_set, {5{1'b0}}};
                //     dfp_wdata = data_array_dout[way_select];
                //     end
            endcase
        end
            
            

        // State to State
        always_comb begin

            case(state) 
                idle        : next_state = (ufp_wmask!=4'b0 || ufp_rmask != 4'b0) ? compare_tag : idle;
                compare_tag : next_state = tag_hit ? compare_tag : (dirty) ? write_back : allocate;
                allocate    : next_state = dfp_resp ? dummy : allocate ;
                dummy       : next_state = compare_tag;
                write_back  : next_state = dfp_resp ? allocate : write_back ;
                default : next_state = idle;
            endcase
        end
        





//******************4 ways per set, these all things is cache**********************
//Active low chip select(csb0), assert this when you need to read or write. 
//You can have it permanently asserted for this MP.
        generate for (genvar i = 0; i < 4; i++) begin : arrays
            mp_cache_data_array data_array (
                .clk0       (clk),
                .csb0       (1'b0),
                .web0       (data_array_web[i]),
                .wmask0     (data_array_wmask),
                .addr0      (cpu_address_set),
                .din0       (data_array_din),
                .dout0      (data_array_dout[i])
            );
            mp_cache_tag_array tag_array (
                .clk0       (clk),
                .csb0       (1'b0),
                .web0       (tag_array_web[i]),
                .addr0      (cpu_address_set),
                .din0       ({dirty_in,cpu_address_tag_late}),
                .dout0      ({dirty_out[i],tag_array_dout[i]})
            );
            ff_array #(.WIDTH(1)) valid_array (
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