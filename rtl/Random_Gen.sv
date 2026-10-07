// Random Generator
// Weston Nguyen

`timescale 1ns/1ps

import Convert_Defs::*;

module Random_Gen
#(
    parameter WIDTH = 32,
    parameter SHARES = 3,
    parameter POOL_SIZE = 256  // Table size
)(
    input logic clk,        // Still need clock for generation
    input logic rst_n,
    input logic generate_new,
    output logic [WIDTH-1:0] r [POOL_SIZE-1:0][SHARES-2:0]  // Random pool
);

    // Pre-generate random values for all table entries
    logic [WIDTH-1:0] random_pool [POOL_SIZE-1:0][SHARES-2:0];
    
    // Generate all random values at once (or on demand)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || generate_new) begin
            for (int u = 0; u < POOL_SIZE; u++) begin
                for (int s = 0; s < SHARES-1; s++) begin
                    random_pool[u][s] <= $urandom();  // Replace with TRNG
                end
            end
        end
    end
    
    // Combinational output
    always_comb begin
        for (int u = 0; u < POOL_SIZE; u++) begin
            for (int s = 0; s < SHARES-1; s++) begin
                r[u][s] = random_pool[u][s];
            end
        end
    end
endmodule