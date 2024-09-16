
module FIFO 
  import rv32i_types::*;
  #(
  parameter  data_      = 32,                           //number of bits per line                    
  parameter  size_      = 16,                            //number of lines in a queue
  localparam ptr_       = $clog2(size_)                 //number of pointer bits needed for the correspond size_
) (
  input  logic                 imem_resp,
  input  logic                 flush,
  input  logic                 clk,
  input  logic                 rst,
  input  logic                 writeEn,         //enque signal
  input  logic [data_-1:0] writeData,
  input  logic [data_-1 :0]   pc_if,
  input  logic                 readEn,          //dequeue
  output iq_t              iq_out, 
  output logic                 full,
  output logic                 empty
);
logic full_delay;
  iq_t mem[size_];

  // set extra bit to determine full/empty
  logic [ptr_:0] wrPtr, wrPtrNext;              //head
  logic [ptr_:0] rdPtr, rdPtrNext;              //tail


  logic flush_delay;


  always_ff @ (posedge clk) begin
    if (rst) flush_delay <= '0;
    else if (flush) flush_delay <= '1;
    else if (full_delay) flush_delay <= flush_delay;
    else if (imem_resp) flush_delay <= '0;
    else    flush_delay <= flush_delay;
  end 

  
    always_comb begin
    // set default value
    wrPtrNext = wrPtr;
    rdPtrNext = rdPtr;

    // if enque, head + 1
    if (writeEn) begin
      wrPtrNext = wrPtr + 1'b1;
    end

    // if deque, tail + 1
    if (readEn) begin
      rdPtrNext = rdPtr + 1'b1;
    end
  end

  always_ff @(posedge clk) begin
    if (rst || flush || flush_delay) begin
      wrPtr <= '0;
      rdPtr <= '0;
    end else begin
      wrPtr <= wrPtrNext;
      rdPtr <= rdPtrNext;
    end
    
  end

  always_ff @(posedge clk) begin
    if (rst || flush || flush_delay) begin
      for (int i=0; i < size_; i++) begin
        mem[i] <= '0;
      end
    end
    else if(!full && writeEn) begin
      mem[wrPtr[ptr_-1:0]].data <= writeData;
      mem[wrPtr[ptr_-1:0]].pc   <= pc_if;
    end
    else begin
      mem[wrPtr[ptr_-1:0]].data <= mem[wrPtr[ptr_-1:0]].data;
      mem[wrPtr[ptr_-1:0]].pc   <= mem[wrPtr[ptr_-1:0]].pc;
    end
  end

  // assign iq_out.data = mem[rdPtr[ptr_-1:0]].data;
  // assign iq_out.pc   = mem[rdPtr[ptr_-1:0]].pc;
  assign iq_out.data = readEn ? mem[rdPtr[ptr_-1:0]].data : 'x;
  assign iq_out.pc   = readEn ? mem[rdPtr[ptr_-1:0]].pc   : 'x;

  assign empty = (wrPtr[ptr_] == rdPtr[ptr_]) && (wrPtr[ptr_-1:0] == rdPtr[ptr_-1:0]);
  assign full  = (wrPtr[ptr_] != rdPtr[ptr_]) && (wrPtr[ptr_-1:0] == rdPtr[ptr_-1:0]);

  always_ff @( posedge clk ) begin 
    if (rst) 
    full_delay <= '0;
    else 
    full_delay <= full;
  end
endmodule