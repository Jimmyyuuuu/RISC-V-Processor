module instruction_holdreg
    import ctrl_types::*;
    import rv32i_types::*;


(   
    input logic flush,
    input logic clk,
    input logic rst,
    input logic dis_freeze,
    input logic iq_re,
    input ctrl_types::rv32i_control_word ctrl_in,
    output ctrl_types::rv32i_control_word ctrl_out,
    //rvfi signal
    input rvfi_data rvfi_in,
    output rvfi_data rvfi_out
);


always_ff @(posedge clk) begin
    if (rst || flush) begin
    ctrl_out <='0;
    // ctrl_out.iq_re <= 1'b0;
    rvfi_out <= '0;
    end
    else if (dis_freeze) begin
    ctrl_out <= ctrl_out;
    ctrl_out.iq_re <= ctrl_out.iq_re;
    rvfi_out <= rvfi_out;
    end
    else if (iq_re) begin
    ctrl_out <= ctrl_in;
    rvfi_out <= rvfi_in;
    rvfi_out.dmem_addr  <= '0;
    rvfi_out.dmem_rmask <= '0;
    rvfi_out.dmem_wmask <= '0;
    rvfi_out.dmem_wdata <= '0;
    rvfi_out.dmem_rdata <= '0;

    ctrl_out.iq_re <= iq_re;
    end
    else    begin
    ctrl_out <='0;
    ctrl_out.iq_re <= 1'b0;
    rvfi_out <= rvfi_in;
    rvfi_out.dmem_addr  <= '0;
    rvfi_out.dmem_rmask <= '0;
    rvfi_out.dmem_wmask <= '0;
    rvfi_out.dmem_wdata <= '0;
    rvfi_out.dmem_rdata <= '0;
    end
end 




endmodule

