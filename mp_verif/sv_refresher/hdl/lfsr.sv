module lfsr #(
  parameter bit [15:0] SEED_VALUE = 'hECEB
) (
  input               clk,
  input               rst,
  input               en,
  output logic        rand_bit,
  output logic [15:0] shift_reg
);
logic feedback;
assign feedback = shift_reg[0] ^ shift_reg[2] ^ shift_reg[3] ^ shift_reg[5];

always_ff @(posedge clk) begin
  if (rst) begin
      shift_reg <= SEED_VALUE;
    end 
  else begin
    if (en) begin
        shift_reg <= {feedback, shift_reg[15:1]};
        rand_bit <= shift_reg[0];
    end
  end
end
endmodule : lfsr

