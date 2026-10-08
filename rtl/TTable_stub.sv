`timescale 1ns/1ps

// PLACEHOLDER for TTable -- NOT functional storage.
// Same ports/parameters as TTable, but one register stage instead of a memory array.
// Use ONLY for fast logic-area / timing sweeps:   make synth TTABLE_FILE=TTable_stub.sv
// (addr/we/wdata still feed a register so the converter logic is not optimised away.)
// Report the memory separately (SRAM macro or the flop-based number from a full run).
module TTable #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 36
)(
    input  logic                   CLK,
    input  logic                   we,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [DATA_WIDTH-1:0]  wdata,
    output logic [DATA_WIDTH-1:0]  rdata
);
    always_ff @(posedge CLK)
        rdata <= we ? wdata : (wdata ^ DATA_WIDTH'(addr));
endmodule
