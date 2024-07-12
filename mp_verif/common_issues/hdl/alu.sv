module alu (
  input               clk,
  input               rst,
  input [63:0]        a,
  input [63:0]        b,
  input               valid_i,
  input [3:0]         op,
  output logic [63:0] z,
  output logic        valid_o
);


logic [3:0] op_reg1,op_reg2,op_reg3,op_reg4;

always_ff @( posedge clk ) begin 
  if(rst) begin
    op_reg1 <= 0;
    op_reg2 <= 0;
    op_reg3 <= 0;
    op_reg4 <= 0;
  end
  else begin  
  op_reg1 <= op;
  op_reg2 <= op_reg1;
  op_reg3 <= op_reg2;
  op_reg4 <= op_reg3;
  end
end



  //----------------------------------------------------------------------------
  // Valid signaling
  //----------------------------------------------------------------------------
  // The ALU is currently purely combinational, so it responds as soon as
  // it gets input.
  logic valid_0,valid_1,valid_2,valid_3,valid_4;
  always_ff@(posedge clk) begin
    if(rst) begin
    valid_0 <= 0;
     valid_1 <= 0;
     valid_2 <= 0;
     valid_3 <= 0;
     valid_4 <= 0;
  end  
  else begin
     valid_0 <= valid_i;
     valid_1 <= valid_0;
     valid_2 <= valid_1;
     valid_3 <= valid_2;
     valid_4 <= valid_3;
  end
  end  
//----------------------------------------------------------------------------
  // Simple logical/arithmetic operations
  //----------------------------------------------------------------------------
  logic [63:0] land;
  logic [63:0] lor;
  logic [63:0] lnot;
  logic [63:0] add;
  logic [63:0] sub;
  logic [63:0] inc;
  logic [63:0] shl;
  logic [63:0] shr;

  logic [63:0] a_reg , b_reg;
  
  always_ff @(posedge clk) begin
    if(rst) begin
      a_reg <= 0;
      b_reg <= 0;
    end
    else begin
    a_reg <= a;
    b_reg <= b;
  end
  end

  always_comb begin
      land = a_reg & b_reg;
      lor  = a_reg | b_reg;
      lnot = ~a_reg;
      add  = a_reg + b_reg;
      sub  = a_reg - b_reg;
      inc  = a_reg + 1'b1;
      shl  = a_reg << b_reg[5:0];
      shr  = a_reg >> b_reg[5:0];
  end

  //----------------------------------------------------------------------------
  // Output MUX
  /*  always_comb begin
    case (op)
      0: z = land;
      1: z = lor;
      2: z = lnot;
      3: z = add;
      4: z = sub;
      5: z = inc;
      6: z = shl;
      7: z = shr;
      8: z = popcnt;
    default z = 'x;
    endcase */

  //----------------------------------------------------------------------------
  // Population count implementation
  //----------------------------------------------------------------------------
  // Popcount = number of '1' bits in a
  logic [63:0] popcnt;
  logic [63:0] popcnt1,popcnt2,popcnt3,popcnt4;
  logic [63:0] temp1,temp2,temp3,temp4;
  
  always_comb begin
    popcnt1 = 0;
    for(int i=0;i<16;i=i+1)
      if (a_reg[i]) popcnt1 = popcnt1 + 1'b1;
    end
  always_ff @(posedge clk) begin
    temp1 <= popcnt1;
  end

  always_comb begin
    popcnt2 = 0;
    for(int i=16;i<32;i=i+1)
      if (a_reg[i]) popcnt2 = popcnt2 + 1'b1;
    end
  always_ff @(posedge clk) begin
    if(rst) begin
      temp2 <=0;
    end
    else begin
    temp2 <= popcnt2;
    end
  end

  always_comb begin
    popcnt3 = 0;
    for(int i=32;i<48;i=i+1)
      if (a_reg[i]) popcnt3 = popcnt3 + 1'b1;
    end
  always_ff @(posedge clk) begin
    if(rst) begin
      temp3 <=0;
    end
    else begin
    temp3 <= popcnt3;
  end
  end

  always_comb begin
    popcnt4 = 0;
    for(int i=48;i<64;i=i+1)
      if (a_reg[i]) popcnt4 = popcnt4 + 1'b1;
    end
  always_ff @(posedge clk) begin
    if(rst) begin
      temp4 <=0;
    end
    else begin
    temp4 <= popcnt4;
    end
  end
  logic [63:0] popcnt_temp1;
  
  always_ff@(posedge clk) begin
    if(rst) begin
      popcnt_temp1 <= 0;
      popcnt <= 0;
    end
    else begin
      popcnt_temp1 <= temp4+temp3+temp2+temp1;
      popcnt <= popcnt_temp1;
    end
  end
    
  
  
  //----------------Pipelining Mux-------------------------------------------
  
  logic [63:0] z1,z2,z3,z4,z5,z6,z7,z8;
  logic [63:0] reg1,reg2,reg3,reg4,reg5,reg6,reg7;
//------------------Breaks into 2-1 Mux---------------------------------------
  always_comb begin
    case(op_reg1[0])
      0: z1 = land ;
      1 :z1 = lor ;
    endcase
  end
  always_ff@(posedge clk) begin
    reg1 <= z1;
  end

  always_comb begin
    case(op_reg1[0])
      0: z2 = lnot ;
      1 :z2 = add ;
    endcase
  end
  always_ff@(posedge clk) begin
    reg2 <= z2;
  end
  always_comb begin
    case(op_reg1[0])
      0: z3 = sub ;
      1 :z3 = inc ;
    endcase
  end
  always_ff@(posedge clk) begin
    reg3 <= z3;
  end
  always_comb begin
    case(op_reg1[0])
      0: z4 = shl ;
      1 :z4 = shr ;
    endcase
  end
  always_ff@(posedge clk) begin
    reg4 <= z4;
  end
  //-----------------------------------------------------------------------------------------------
  always_comb begin
    case(op_reg2[1])
      0: z5 = reg1 ;
      1 :z5 = reg2 ;
    endcase
  end
  always_ff@(posedge clk) begin
    reg5 <= z5;
  end

  always_comb begin
    case(op_reg2[1])
      0: z6 = reg3 ;
      1 :z6 = reg4 ;
    endcase
  end
  always_ff@(posedge clk) begin
    reg6 <= z6;
  end

  //----------------------------------------------------------

  always_comb begin
    case(op_reg3[2])
      0: z7 = reg5 ;
      1 :z7 = reg6 ;
    endcase
  end
  always_ff@(posedge clk) begin
    reg7 <= z7;
  end
  //-------------------------------------------------------
  logic [63:0] z_output ;
  always_comb begin
    case(op_reg4[3])
      0: z8 = reg7;
      1 :z8 = popcnt ;
    endcase
  end

  always_ff@(posedge clk) begin
     z_output <= z8;
  end
  //-----------------------------------------------

  always_ff@(posedge clk) begin
    if(valid_4) begin
      valid_o <= valid_4;
      z <= z_output;
    end
    else begin
     valid_o <= 0;
     z <= 'x;
    end
  end

  

endmodule : alu
