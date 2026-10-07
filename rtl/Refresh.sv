// Modular Refresh Algorithm
// Inputs: x[1], ..., x[n] in G
// Outputs: y[1], ..., y[n] in H such that y[1] + ... + y[n] = f(x[1] + ... + x[n])
// Parameters: size of H, number of shares, mod Q, and H group mode
//Weston Nguyen

`timescale 1ns/1ps

import Convert_Defs::*;

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

    // H-domain addition
    // B2A: H = Zq        -> modular addition
    // A2B: H = Boolean   -> XOR
    function automatic logic [H_WIDTH-1:0] h_add (
        input logic [H_WIDTH-1:0] a,
        input logic [H_WIDTH-1:0] b
    );
        logic [H_WIDTH:0] temp;

        begin
            if (H_MODE != BOOLEAN) begin
                // H = Zq
                temp = {1'b0, a} + {1'b0, b};
                /* verilator lint_off WIDTHEXPAND*/
                if (temp >= H_WIDTH'(Q))
                /* verilator lint_on WIDTHEXPAND*/
                    temp = temp - H_WIDTH'(Q);

                h_add = temp[H_WIDTH-1:0];
            end
            else begin
                // H = Boolean
                h_add = a ^ b;
            end
        end
    endfunction

    // H-domain subtraction
    // B2A: H = Zq        -> modular subtraction
    // A2B: H = Boolean   -> XOR
    function automatic logic [H_WIDTH-1:0] h_sub (
        input logic [H_WIDTH-1:0] a,
        input logic [H_WIDTH-1:0] b
    );
        logic [H_WIDTH:0] temp;

        begin
            if (H_MODE != BOOLEAN) begin
                // H = Zq
                if (a >= b)
                    temp = {1'b0, a} - {1'b0, b};
                else
                    temp = {1'b0, a} + H_WIDTH'(Q) - {1'b0, b};

                h_sub = temp[H_WIDTH-1:0];
            end
            else begin
                // H = Boolean
                h_sub = a ^ b;
            end
        end
    endfunction

    always_comb begin

        // yn <- xn
        y = '0;
        y[SHARES-1] = x[SHARES-1];

        // for j = 1 ... n-1
        for (int j = 0; j < SHARES-1; j++) begin

            // yj <- xj + rj
            y[j] = h_add(x[j], r[j]);

            // yn <- yn - rj
            y[SHARES-1] = h_sub(y[SHARES-1], r[j]);

        end

    end

endmodule