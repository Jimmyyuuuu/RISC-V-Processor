module cache_controler
    import cache_pkg::*;
    (
    input logic clk,
    input logic rst,
    
    input logic [3:0] ufp_rmask,
    input logic [3:0] ufp_wmask,
    input logic dfp_resp,
    
    output logic ufp_resp,
    output logic dfp_read,
    output logic dfp_write,
    
    input logic cache_hit,
    input logic cache_dirty,
    


    output cache_pkg::way_mux_t way_mux, dirty_way_mux,
    output cache_pkg::data_mux_t data_mux,
    output cache_pkg::write_mux_t write_mux,


    output logic valid_load, 
    output logic dirty_load,
    output logic tag_load,
    output logic data_load,
    output logic  plru_load,
    output logic  dirty_in
    );
    

   enum logic [2:0] {
     IDLE,
     COMPARE_TAG,
     WRITE_BACK,
     ALLOCATE,
     DUMMY
   } state, next_state;


    always_ff @ (posedge clk) begin
        if (rst)
           state <= IDLE;
        else
           state <= next_state;
    end
    
    

    always_comb begin
        ufp_resp = 1'b0;
        dfp_read = 1'b0;
        dfp_write = 1'b0;
        valid_load = 1'b0;
        dirty_load = 1'b0;
        dirty_in   = 1'b0;
        tag_load = 1'b0;
        data_load = 1'b0;
        plru_load = 1'b0;
        next_state = state;
        way_mux = wayhit;
        dirty_way_mux = wayhit;
        data_mux = cpu_data;
        write_mux = write_miss;


        
      case (state)
    
    
            IDLE:begin
                if (ufp_rmask != '0 || ufp_wmask != '0)
                     next_state = COMPARE_TAG;  //read write hit第一个cycle来源
            end
            COMPARE_TAG:begin
                if (cache_hit) begin
                   if (ufp_wmask !='0) begin
                   data_load = 1'b1;      
                   way_mux   = wayhit; //load的位置
                   data_mux  = cpu_data;  //ufp_wdata
                   dirty_way_mux = wayhit; //dirty的位置
                   dirty_load= 1'b1;  //使能信号
                   dirty_in  = 1'b1; // 1
                   end
                   plru_load = 1'b1; //plru更新
                   ufp_resp  = 1'b1;
                   next_state = IDLE;
                end
                else if (cache_dirty)
                   next_state = WRITE_BACK; //如果write hit就继续写 没有必要写回去
                else 
                   next_state = ALLOCATE; // write miss clean 
            end
             
            WRITE_BACK:begin
               write_mux = dirty_replace; //被替代的way的tag，写回地址更新
               dfp_write = 1'b1;
               if (dfp_resp)
                  next_state = ALLOCATE; //
            end
    
    
             
//allocate的时候一起写不影响tag和dirty，都是些lru
            ALLOCATE:begin
               tag_load = dfp_resp;//1'b1; //enable
               valid_load = dfp_resp;//1'b1;  //使能
               write_mux = write_miss; // mem中的miss 地址的tag
               data_load =dfp_resp;//1'b1;
               way_mux = waylru; //写入被替代way的位置
               data_mux= mem_data; //来自mem的data   要去dummy state是因为dfpresp为一的时候这个值才出来所以还需要2cycle写进去 等2cc后刚好读出去
               dirty_load = dfp_resp;//1'b1; 
               dirty_in = 1'b0; //新data dirty为0
               dirty_way_mux = waylru;
               dfp_read =1'b1;
               if (dfp_resp) //allocate时间长 因为在找值等resp后才到dummy去
                 // next_state = COMPARE_TAG;
                    next_state = DUMMY;
            end 

            DUMMY: begin
               next_state = COMPARE_TAG;
            end
      endcase
    end 
    
    
    endmodule 


    //next_state = dummy





                             //如果ufp_resp为零 ufp_address不会更新？
    //dummy:begin
    //next_state= compare_tag  //能解决clean miss read and clean miss write 能解决所有


    //end  C           // 这是指同一个sram吗？
                     // 从总体来看？？？
                     // 被覆盖的 mb怎么办？是操作没成功还是只是不显示？

//     generate for (genvar i = 0; i < 4; i++) begin : arrays
//       mp_cache_data_array data_array (
//           .clk0       (clk),
//           .csb0       (1'b0),
//           .web0       (! (data_load & (data_mux ? select_mask_lru[i] : select_mask_hit[i]))),
//           .wmask0     (data_mux ? 32'hffff_ffff : wmask32), 
//           .addr0      (addr_index), //read 只需要地址
//           .din0       (data_mux ? dfp_rdata : ufp_wdata256),       
//           .dout0      (data_out[i])
//       );
//       mp_cache_tag_array tag_array (
//           .clk0       (clk),    //no rst
//           .csb0       (1'b0),
//           .web0       (! (tag_load & select_mask_lru[i])),   //没hit才替换 如果都hit了直接返回idle
//           .addr0      (addr_index),
//           .din0       (addr_tag),              //  tag_in = {dirty_in, addr_tag} 
//           .dout0      (tag_out[i])
//       );
//       ff_array #(.WIDTH(1)) valid_array (
//           .clk0       (clk),
//           .rst0       (rst),
//           .csb0       (1'b0),
//           .web0       (! (valid_load & select_mask_lru[i])),
//           .addr0      (addr_index),
//           .din0       (1'b1),
//           .dout0      (valid_out[i])
//       );
//       ff_array #(.WIDTH(1)) dirty_array (
//           .clk0       (clk),
//           .rst0       (rst),
//           .csb0       (1'b0),
//           .web0       (! (dirty_load & (dirty_way_mux ? select_mask_lru[i] : select_mask_hit [i]))),
//           .addr0      (addr_index),
//           .din0       (dirty_in),
//           .dout0      (dirty_out[i])
//       );
      
//   end endgenerate