module data_mem import rv32i_types::*;
(
    input   logic   flush,
    input   lsq_t   dmem_in,
    input   logic   dmem_valid,
    output  logic   [31:0]  dmem_addr,
    output  logic   [3:0]   dmem_rmask,
    output  logic   [3:0]   dmem_wmask,
    output  logic   [31:0]  dmem_wdata,

    input   rvfi_data   rvfi_in,
    output  rvfi_data   rvfi_out
);
    assign dmem_addr = dmem_valid ? {dmem_in.dmem_addr[31:2],2'b00} :   0;

    always_comb begin
        dmem_wdata = '0;
        if (flush) dmem_wdata = '0;

        else if (dmem_valid) begin
            if (dmem_in.opcode == op_store) begin
                unique case (dmem_in.funct3)
                        sb: dmem_wdata[8 *dmem_in.dmem_addr[1:0] +: 8 ] = dmem_in.dmem_wdata[7 :0];
                        sh: dmem_wdata[16*dmem_in.dmem_addr[1]   +: 16] = dmem_in.dmem_wdata[15:0];
                        sw: dmem_wdata = dmem_in.dmem_wdata;
                        default: dmem_wdata = '0;
                endcase
            end
            else begin
                dmem_wdata = '0;
            end
        end
    end


    always_comb begin
            dmem_wmask = '0;
            dmem_rmask = '0;
            if (flush) begin
                dmem_wmask = '0;
                dmem_rmask = '0;
            end
            else if (dmem_valid) begin
                unique case (dmem_in.opcode)
                    op_load   :  begin                //mp verif also set rd_v

                        unique case (dmem_in.funct3)
                            lb, lbu: begin
                                dmem_rmask = 4'b0001 << dmem_in.dmem_addr[1:0];
                                dmem_wmask = '0;
                            end
                            lh, lhu: begin
                                dmem_rmask = 4'b0011 << dmem_in.dmem_addr[1:0];
                                dmem_wmask = '0;
                            end
                            lw:      begin
                                dmem_rmask = 4'b1111;
                                dmem_wmask = '0;
                            end
                            default: begin
                                dmem_rmask = '0;
                                dmem_wmask = '0;
                            end
                        endcase
                    end

                    op_store  :  begin
                        

                        unique case (dmem_in.funct3)
                            sb:     begin
                                dmem_wmask = 4'b0001 << dmem_in.dmem_addr[1:0];
                                dmem_rmask = '0;
                            end
                            sh:     begin
                                dmem_wmask = 4'b0011 << dmem_in.dmem_addr[1:0];
                                dmem_rmask = '0;
                            end
                            sw:     begin
                                dmem_wmask = 4'b1111 << dmem_in.dmem_addr[1:0];
                                dmem_rmask = '0;
                            end
                            default: begin
                                dmem_wmask = '0;
                                dmem_rmask = '0;
                            end
                        endcase
                    end

                    default: begin
                            dmem_wmask = '0;
                            dmem_rmask = '0;
                    end
                endcase
            end
        end
    
    always_comb begin 
        if (dmem_valid) begin
            rvfi_out = rvfi_in;
            rvfi_out.dmem_wmask = dmem_wmask;
            rvfi_out.dmem_rmask = dmem_rmask;
            rvfi_out.dmem_wdata = dmem_wdata;
            rvfi_out.dmem_addr  = dmem_addr;
        end
        else 
            rvfi_out = '0;
    
    end

endmodule


module data_mem_forward import rv32i_types::*;
(   
    input   logic   [31:0]  dmem_wdata,
    input   cdb_t   forward_cdb_in,
    input   lsq_t   dmem_in,
    input   logic   dmem_valid,
    output  cdb_t   forward_cdb,

    input   rvfi_data   rvfi_in,
    output  rvfi_data   rvfi_out
);
    logic   [31:0]  dmem_addr;
    logic   [3:0]   dmem_rmask;
    logic   [3:0]   dmem_wmask;


    assign dmem_addr = dmem_valid ? {dmem_in.dmem_addr[31:2],2'b00} :   0;



    always_comb begin
            dmem_wmask = '0;
            dmem_rmask = '0;
            if (dmem_valid) begin
                unique case (dmem_in.opcode)
                    op_load   :  begin                //mp verif also set rd_v

                        unique case (dmem_in.funct3)
                            lb, lbu: begin
                                dmem_rmask = 4'b0001 << dmem_in.dmem_addr[1:0];
                                dmem_wmask = '0;
                            end
                            lh, lhu: begin
                                dmem_rmask = 4'b0011 << dmem_in.dmem_addr[1:0];
                                dmem_wmask = '0;
                            end
                            lw:      begin
                                dmem_rmask = 4'b1111;
                                dmem_wmask = '0;
                            end
                            default: begin
                                dmem_rmask = '0;
                                dmem_wmask = '0;
                            end
                        endcase
                    end

                    op_store  :  begin
                        

                        unique case (dmem_in.funct3)
                            sb:     begin
                                dmem_wmask = 4'b0001 << dmem_in.dmem_addr[1:0];
                                dmem_rmask = '0;
                            end
                            sh:     begin
                                dmem_wmask = 4'b0011 << dmem_in.dmem_addr[1:0];
                                dmem_rmask = '0;
                            end
                            sw:     begin
                                dmem_wmask = 4'b1111 << dmem_in.dmem_addr[1:0];
                                dmem_rmask = '0;
                            end
                            default: begin
                                dmem_wmask = '0;
                                dmem_rmask = '0;
                            end
                        endcase
                    end

                    default: begin
                            dmem_wmask = '0;
                            dmem_rmask = '0;
                    end
                endcase
            end
        end
    

    always_comb begin
        forward_cdb = forward_cdb_in;

        if(dmem_valid) begin
            unique case (dmem_in.funct3)
                lb : forward_cdb.value = {{24{dmem_wdata[7 +8 *dmem_in.dmem_addr[1:0]]}}, dmem_wdata[8 *dmem_in.dmem_addr[1:0] +: 8 ]};
                lbu: forward_cdb.value = {{24{1'b0}}                                        , dmem_wdata[8 *dmem_in.dmem_addr[1:0] +: 8 ]};
                lh : forward_cdb.value = {{16{dmem_wdata[15+16*dmem_in.dmem_addr[1]  ]}}, dmem_wdata[16*dmem_in.dmem_addr[1]   +: 16]};
                lhu: forward_cdb.value = {{16{1'b0}}                                        , dmem_wdata[16*dmem_in.dmem_addr[1]   +: 16]};
                lw : forward_cdb.value = dmem_wdata;
                default : forward_cdb.value = 'x;
            endcase
        end
        else begin
            forward_cdb= '0;
        end
    end

    always_comb begin 
        rvfi_out =  dmem_valid  ? rvfi_in : '0;
        rvfi_out.dmem_wmask = dmem_valid  ?  dmem_wmask : '0;
        rvfi_out.dmem_rmask = dmem_valid  ?  dmem_rmask : '0;
        rvfi_out.dmem_wdata = '0;
        rvfi_out.dmem_addr  = dmem_valid  ?  dmem_addr  : '0;
        rvfi_out.dmem_rdata = dmem_valid  ?  dmem_wdata : '0;
        rvfi_out.rd_wdata   = dmem_valid  ?  forward_cdb.value : '0;

        
    end

endmodule