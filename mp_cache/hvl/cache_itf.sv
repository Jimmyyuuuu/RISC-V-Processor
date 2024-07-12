interface cache_itf(
    input   bit     clk,
    input   bit     rst
);

logic   [31:0]  addr;
logic   [3:0]   rmask;
logic   [3:0]   wmask;
logic   [31:0]  rdata;
logic   [31:0]  wdata;
logic           resp;

bit             error = 1'b0;

modport dut (
        input       clk,
        input       rst,
        input       addr,
        input       rmask,
        input       wmask,
        input       wdata,
        output      rdata,
        output      resp
    );




endinterface : cache_itf
