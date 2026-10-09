`timescale 1ns/1ps

import Convert_Defs::*;

// Drop-in replacement for Refresh (same module name, parameters and ports).
//
//   chain version : y[n-1] = x[n-1] - r[0] - r[1] - ... - r[n-2]   (n-1 serial operations)
//   tree  version : S = r[0] + ... + r[n-2] as a balanced tree      (ceil(log2(n-1)) levels)
//                   y[n-1] = x[n-1] - S                             (one operation)
//
// Same function (modular add/sub is associative, XOR too). Because S depends only on the
// fresh randoms, the secret-dependent value x[n-1] now passes through a single operation.
module Refresh #(
    parameter int           H_WIDTH = 12,
    parameter int           SHARES  = 2,
    parameter int           Q = 3329,
    parameter group_mode_t  H_MODE = BOOLEAN
)(
    input  logic [SHARES-1:0][H_WIDTH-1:0] x,
    input  logic [SHARES-2:0][H_WIDTH-1:0] r,
    output logic [SHARES-1:0][H_WIDTH-1:0] y
);

    // H-domain addition: Zq mod-add (B2A) or XOR (A2B)
    function automatic logic [H_WIDTH-1:0] h_add (
        input logic [H_WIDTH-1:0] a,
        input logic [H_WIDTH-1:0] b
    );
        logic [H_WIDTH:0] temp;

        begin
            if (H_MODE != BOOLEAN) begin
                temp = {1'b0, a} + {1'b0, b};
                /* verilator lint_off WIDTHEXPAND*/
                if (temp >= H_WIDTH'(Q))
                /* verilator lint_on WIDTHEXPAND*/
                    temp = temp - H_WIDTH'(Q);

                h_add = temp[H_WIDTH-1:0];
            end
            else begin
                h_add = a ^ b;
            end
        end
    endfunction

    // H-domain subtraction: Zq mod-sub (B2A) or XOR (A2B)
    function automatic logic [H_WIDTH-1:0] h_sub (
        input logic [H_WIDTH-1:0] a,
        input logic [H_WIDTH-1:0] b
    );
        logic [H_WIDTH:0] temp;

        begin
            if (H_MODE != BOOLEAN) begin
                if (a >= b)
                    temp = {1'b0, a} - {1'b0, b};
                else
                    temp = {1'b0, a} + H_WIDTH'(Q) - {1'b0, b};

                h_sub = temp[H_WIDTH-1:0];
            end
            else begin
                h_sub = a ^ b;
            end
        end
    endfunction

    // Balanced reduction tree over the NR = SHARES-1 random words
    // (padded with zeros to a power of two; 0 is neutral for add and xor)
    localparam int NR = SHARES - 1;
    localparam int L  = (NR > 1) ? $clog2(NR) : 0;   // number of tree levels
    localparam int P  = 1 << L;                      // padded leaf count

    logic [L:0][P-1:0][H_WIDTH-1:0] t;

    for (genvar i = 0; i < P; i++) begin : g_leaf
        if (i < NR) begin : g_r
            assign t[0][i] = r[i];
        end else begin : g_pad
            assign t[0][i] = '0;
        end
    end

    for (genvar k = 0; k < L; k++) begin : g_lvl
        for (genvar i = 0; i < P; i++) begin : g_node
            if (i < (P >> (k + 1))) begin : g_add
                assign t[k+1][i] = h_add(t[k][2*i], t[k][2*i+1]);
            end else begin : g_pad
                assign t[k+1][i] = '0;
            end
        end
    end

    // Outputs
    always_comb begin
        y = '0;
        for (int j = 0; j < SHARES-1; j++)
            y[j] = h_add(x[j], r[j]);              // yj <- xj + rj (all in parallel)

        y[SHARES-1] = h_sub(x[SHARES-1], t[L][0]); // yn <- xn - sum(rj)
    end

endmodule
