`timescale 1ns/1ps
`include "sram_cfg.svh"

// Drop-in replacement for TTable built from SRAM macros (same module name, ports, parameters).
// Tiles `SRAM_DEPTH x `SRAM_WIDTH macros: N_ROWS stacked in depth, N_COLS side by side in width.
//
// Assumptions that hold for Convert_Core:
//   * each bank is accessed through ONE port (it is either read or written in a given cycle),
//   * read data is only used the cycle after a read address, and never on a write cycle.
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
    localparam int DEPTH  = 1 << ADDR_WIDTH;
`ifdef SRAM_ROWS
    localparam int N_ROWS = `SRAM_ROWS;      // rows actually needed (e.g. A2B uses only Q words)
`else
    localparam int N_ROWS = (DEPTH + `SRAM_DEPTH - 1) / `SRAM_DEPTH;
`endif
    localparam int N_COLS = (DATA_WIDTH + `SRAM_WIDTH - 1) / `SRAM_WIDTH;
    localparam int MA_W   = $clog2(`SRAM_DEPTH);
    localparam int ROW_W  = (N_ROWS > 1) ? $clog2(N_ROWS) : 1;
    localparam int PAD_W  = N_COLS * `SRAM_WIDTH;

    logic [PAD_W-1:0]  wdata_p;
    logic [MA_W-1:0]   m_addr;
    logic [ROW_W-1:0]  row, row_q;
    logic [N_ROWS-1:0][PAD_W-1:0] q;

    assign wdata_p = PAD_W'(wdata);
    assign m_addr  = MA_W'(addr);

    always_comb begin
        row = '0;
        if (N_ROWS > 1) row = ROW_W'(addr >> MA_W);
    end

    // the read data of the row addressed last cycle is the one to forward
    always_ff @(posedge CLK) row_q <= row;

    for (genvar r = 0; r < N_ROWS; r++) begin : g_row
        for (genvar c = 0; c < N_COLS; c++) begin : g_col
            sram_1rw u_mem (
                .CLK (CLK),
                .en  (row == ROW_W'(r)),
                .we  (we && (row == ROW_W'(r))),
                .addr(m_addr),
                .din (wdata_p[c*`SRAM_WIDTH +: `SRAM_WIDTH]),
                .dout(q[r][c*`SRAM_WIDTH +: `SRAM_WIDTH])
            );
        end
    end

    assign rdata = q[row_q][DATA_WIDTH-1:0];
endmodule
