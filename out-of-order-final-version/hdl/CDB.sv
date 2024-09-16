module cdb_alu
    import rv32i_types::*;
    (
        input logic valid_alu,
        input logic [3:0] tag_alu,
        input logic [31:0] value_alu,
        input rvfi_data rvfi_in,
        output rvfi_data rvfi_out,
        output cdb_t alu_out
    );

    always_comb begin
        alu_out.br_en = '0;
        alu_out.br_target = '0;
        

        if(valid_alu) begin
            alu_out.value = value_alu;
            alu_out.tag = tag_alu;
            alu_out.valid = valid_alu;
            rvfi_out      = rvfi_in;
            rvfi_out.dmem_addr = '0;
            rvfi_out.dmem_rmask = '0;
            rvfi_out.dmem_wmask = '0;
            rvfi_out.dmem_rdata = '0;
            rvfi_out.dmem_wdata = '0;
        end
        else begin
            alu_out.valid = 1'b0;
            alu_out.tag = 4'd0;
            alu_out.value = 32'd0;
            rvfi_out      = '0;
        end
    end
endmodule

module cdb_mul
    import rv32i_types::*;
    (
        input logic valid_mul,
        input logic [3:0] tag_mul,
        input logic [31:0] value_mul,
        input rvfi_data rvfi_in,
        output rvfi_data rvfi_out,
        output cdb_t mul_out
    );

    always_comb begin
        mul_out.br_en = '0;
        mul_out.br_target = '0;
        

        if(valid_mul) begin
            mul_out.value = value_mul;
            mul_out.tag = tag_mul;
            mul_out.valid = valid_mul;
            rvfi_out      = rvfi_in;
            rvfi_out.dmem_addr = '0;
            rvfi_out.dmem_rmask = '0;
            rvfi_out.dmem_wmask = '0;
            rvfi_out.dmem_rdata = '0;
            rvfi_out.dmem_wdata = '0;
        end
        else begin
            mul_out.valid = 1'b0;
            mul_out.tag = 4'd0;
            mul_out.value = 32'd0;
            rvfi_out      = '0;
        end
    end
endmodule

module cdb_cmp
    import rv32i_types::*;
    (
        input logic valid_cmp,
        input logic [3:0] tag_cmp,
        input logic [31:0] br_value,
        input logic br_en,
        input logic [31:0] br_target,
        input rvfi_data rvfi_in,
        output rvfi_data rvfi_out,
        output cdb_t cmp_out
    );

    always_comb begin
        

        if(valid_cmp) begin
            cmp_out.value = br_value;
            cmp_out.br_target = br_target;
            cmp_out.br_en = br_en;
            cmp_out.tag = tag_cmp;
            cmp_out.valid = valid_cmp;
            rvfi_out      = rvfi_in;
            rvfi_out.dmem_addr = '0;
            rvfi_out.dmem_rmask = '0;
            rvfi_out.dmem_wmask = '0;
            rvfi_out.dmem_rdata = '0;
            rvfi_out.dmem_wdata = '0;
        end
        else begin
            cmp_out.value = 32'd0;
            cmp_out.valid = 1'b0;
            cmp_out.tag = 4'd0;
            cmp_out.br_target = 32'd0;
            cmp_out.value = 32'd0;
            cmp_out.br_en = '0;
            rvfi_out      = '0;
        end
    end
endmodule
// // load store 
module cdb_load
    import rv32i_types::*;
    (
        input logic forward_valid,      //from forwarding
        input logic [3:0] tag_load,
        input logic [31:0] value_load,

        input logic cdb_load_valid,     //from mem unit
        input logic [2:0]   tmp_funct3,
        input logic [31:0]  tmp_addr,

        output cdb_t load_out,
        input rvfi_data rvfi_in,
        output rvfi_data rvfi_out
    );
    logic error;
    assign error = forward_valid & cdb_load_valid;
    always_comb begin
        //forwarding
        if(forward_valid) begin
            //already done shifting
            load_out.value = value_load;
            load_out.tag = tag_load;
            load_out.valid = forward_valid;
            load_out.br_target = '0;
            load_out.br_en = '0;
            rvfi_out      = rvfi_in;
        end
        
        //mem unit
        else if (cdb_load_valid) begin
            load_out.tag = tag_load;
            load_out.valid = cdb_load_valid;
            load_out.br_target = '0;
            load_out.br_en = '0;
            
            unique case (tmp_funct3)
                lb : load_out.value = {{24{value_load[7 +8 *tmp_addr[1:0]]}}, value_load[8 *tmp_addr[1:0] +: 8 ]};
                lbu: load_out.value = {{24{1'b0}}                                        , value_load[8 *tmp_addr[1:0] +: 8 ]};
                lh : load_out.value = {{16{value_load[15+16*tmp_addr[1]  ]}}, value_load[16*tmp_addr[1]   +: 16]};
                lhu: load_out.value = {{16{1'b0}}                                        , value_load[16*tmp_addr[1]   +: 16]};
                lw : load_out.value = value_load;
                default : load_out.value = 'x;
            endcase

            rvfi_out            = cdb_load_valid  ?  rvfi_in    : '0;;
            rvfi_out.dmem_rdata = cdb_load_valid  ?  value_load : '0;
            rvfi_out.rd_wdata   = cdb_load_valid  ?  load_out.value : '0;

        end
        else begin
            load_out.valid = 1'b0;
            load_out.tag = 4'd0;
            load_out.value = 32'd0;
            load_out.br_target = '0;
            load_out.br_en = '0;
            rvfi_out      = '0;
        end
    end
endmodule


// 0x00c f -> 1111 lw
// 12345678
// 12345678
// 0x00e lb 
// 0x00c 4 -> 0100
// 12345678 0x00000034
// mem_rdata 0x000c0000 rd_wdata 0x0000000c good
// 0000000c 0x00000000

       