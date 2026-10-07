`timescale 1ns/1ps

import Convert_Defs::*;

module TTable #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 36
)(
    input  logic                   clk,

    input  logic                   we,
    input  logic [ADDR_WIDTH-1:0]  addr,

    input  logic [DATA_WIDTH-1:0]  wdata,
    output logic [DATA_WIDTH-1:0]  rdata
);

    localparam int DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (we)
            mem[addr] <= wdata;

        rdata <= mem[addr];
    end

endmodule