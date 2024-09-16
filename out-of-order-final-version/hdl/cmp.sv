// TODO 
module cmp
	import rv32i_types::*;
    (	input rvfi_data rvfi_in,
		input [6:0] op_code,
        input   [2:0] cmp_opcode, 
        input   [31:0] a,
        input   [31:0] b,
		input 	[31:0] pc,
		input 	[31:0] imm_out, 
        input   [3:0] tag_rs,
        input   logic ready,// if both a and b value are ready
		output 	rvfi_data rvfi_out,
		output  cdb_t           out
	
	);
		logic br_en_;

		logic signed   [31:0] as;
        logic signed   [31:0] bs ;
        logic unsigned [31:0] au ;
        logic unsigned [31:0] bu ;
    
        assign as =   signed'(a);
        assign bs =   signed'(b);
        assign au = unsigned'(a);
        assign bu = unsigned'(b);
	
		always_comb begin
				if(ready) begin
					out.valid = 1'b1;
					if(op_code inside{op_jal, op_jalr}) begin
					  br_en_ =1'b1; // default value for jump, always taken
					end
					else begin
						unique case (cmp_opcode)
							beq:  br_en_ = (au == bu);
							bne:  br_en_ = (au != bu);
							blt:  br_en_= (as <  bs);
							//since bge stands for "branch if greater than or equal, should use ">="
							bge:  br_en_ = (as >=  bs);
							bltu: br_en_ = (au <  bu);
							//"bgeu" stands for "branch if greater than or equal, unsigned."
							bgeu: br_en_ = (au >=  bu);
							default: br_en_ = 1'bx;
						endcase
					end
				end
				else begin
					out.valid = 1'b0;
					br_en_ = '0;
				end
		end


		always_comb begin
			out.value = '0; 
			if(ready) begin
				unique case(op_code) 
					op_jal : out.value = pc+32'd4;
					op_jalr : out.value = pc + 32'd4;
				default : out.value = {31'b0, br_en_}; 
				endcase
			end
		end
		
		// assign out.value = {31'b0, out.br_en}; //Send to ROB
	//address unit for branch/jump
		always_comb begin
			out.br_target = '0;
			out.br_en	  = '0;
			if(ready) begin
				unique case(op_code)
					op_jal : begin
						out.br_target = pc + imm_out;
						out.br_en	  = br_en_;
					end
					op_jalr: begin
						out.br_target = (a + imm_out) & 32'hfffffffe;
						out.br_en	  = br_en_;
					end
					op_br :	 begin
						out.br_target = pc + imm_out; //imm_out might be : b_imm, j_imm, i_imm
						out.br_en	  = br_en_;
					end
					default : begin
						out.br_target = '0;
						out.br_en	  = '0;
					end
				endcase
			end
		end
				
		assign out.tag = tag_rs;
		always_comb begin
				if(ready) begin
					rvfi_out = rvfi_in;
					rvfi_out.r1_rdata = a;
					rvfi_out.r2_rdata = b;
					rvfi_out.rd_wdata = out.value;
					if(op_code inside {op_br, op_jal, op_jalr}) rvfi_out.pc_wdata = out.br_en ? out.br_target : pc + 4;
					else rvfi_out.pc_wdata = pc + 4;
					
				end
				else rvfi_out = '0;
			end

	endmodule