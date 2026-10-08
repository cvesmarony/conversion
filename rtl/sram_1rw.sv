`timescale 1ns/1ps
`include "sram_cfg.svh"

// One single-port (1RW) SRAM macro, active-high interface.
//   USE_SRAM_MACRO defined : instantiates the real macro `SRAM_CELL  (EDIT the pin map below)
//   otherwise              : behavioural model with the same 1-cycle read latency
module sram_1rw (
    input  logic                              clk,
    input  logic                              en,
    input  logic                              we,
    input  logic [$clog2(`SRAM_DEPTH)-1:0]    addr,
    input  logic [`SRAM_WIDTH-1:0]            din,
    output logic [`SRAM_WIDTH-1:0]            dout
);
`ifdef USE_SRAM_MACRO
    // EDIT: pin map of the chosen macro
    // Typical TSMC single-port pins (CONFIRM names, widths and polarity in the .lib / datasheet):
    //   CLK, CEB (active-low enable), WEB (active-low write enable), A[], D[],
    //   BWEB[] (active-low per-bit write mask), Q[]; many 16nm macros also need
    //   RTSEL/WTSEL/PTSEL (and possibly SLP/SD/DSLP) tied to datasheet values.
    `SRAM_CELL u_macro (
        .CLK  (clk),
        .CEB  (~en),
        .WEB  (~we),
        .A    (addr),
        .D    (din),
        .BWEB ('0),            // write every bit
        .Q    (dout)
        // .RTSEL(2'b01), .WTSEL(2'b00), .PTSEL(2'b00)   // example tie-offs: use datasheet values
    );
`else
    logic [`SRAM_WIDTH-1:0] mem [0:`SRAM_DEPTH-1];
    always_ff @(posedge clk) begin
        if (en) begin
            if (we) mem[addr] <= din;
            dout <= mem[addr];            // old data on a write cycle
        end
    end
`endif
endmodule
