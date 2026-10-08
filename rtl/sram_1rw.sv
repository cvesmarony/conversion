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
    // Pin map for TS1N16ADFPCLLLVTA512X45M4SWSHOD (pins read from the .lib):
    //   CLK, CEB (active-low enable), WEB (active-low write enable), A[8:0], D[44:0],
    //   BWEB[44:0] (active-low bit write mask), Q[44:0], RTSEL/WTSEL[1:0],
    //   SD / DSLP / SLP (power modes, tied off), PUDELAY (output, unused).
    // Other macros (e.g. 128x64) have the same pins with different widths.
    `SRAM_CELL u_macro (
        .CLK    (clk),
        .CEB    (~en),
        .WEB    (~we),
        .A      (addr),
        .D      (din),
        .BWEB   ('0),                       // write every bit
        .Q      (dout),
        .RTSEL  (2'(`SRAM_RTSEL_V)),
        .WTSEL  (2'(`SRAM_WTSEL_V)),
        .SD     (1'b0),
        .DSLP   (1'b0),
        .SLP    (1'b0),
        .PUDELAY()
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
