module alu
    import rv32i_types::*;

    (    
        //RVFI Signal
        input rvfi_data rvfi_in,
        output rvfi_data rvfi_out,
        //ALU
        input   [2:0] alu_opcode, 
        input   [31:0] a,
        input   [31:0] b,
        input   [3:0] tag_rs,
        input   logic ready,// if both a and b value are ready
        output  cdb_t out
    );
   
    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);
    
        always_comb begin
                if(ready) begin
                    out.valid = 1'b1;
                    unique case (alu_opcode)
                        alu_add: out.value = au +  bu;
                        //rs2 has 5bits, so it should change to [4:0] for both srl, sra, sll
                        alu_sll: out.value = au <<  bu[4:0];
                        alu_sra: out.value = unsigned'(as >>> bu[4:0]);
                        alu_sub: out.value = au -   bu;
                        alu_xor: out.value = au ^   bu;
                        alu_srl: out.value = au >>  bu[4:0];
                        //from the instruction generate website. shamt should be shamt[4:0]
                        alu_or:  out.value = au |   bu;
                        alu_and: out.value = au &   bu;
                        default: out.value = 'x;
                    endcase
                end
                else begin
                    out.valid = 1'b0;
                    out.value = 32'd0;
                end
        end

        assign out.tag = tag_rs; // send the tag from Dispatch stage to CDB
         //RVFI Signal
        always_comb begin
            if(ready) begin
                rvfi_out = rvfi_in;
                rvfi_out.r1_rdata = a;
                rvfi_out.r2_rdata = b;
                rvfi_out.rd_wdata = out.value;
            end
            else rvfi_out = '0;
        end
    
    endmodule 
