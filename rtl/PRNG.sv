// Combinational LFSR-based pseudo-random generator (for simulation/low-security)
// Weston Nguyen

`timescale 1ns/1ps

import Convert_Defs::*;

module PRNG #(
    parameter int           WIDTH = 32,
    parameter bit [31:0]    SEED = 32'hDEAD_BEEF
)(
    input  logic [WIDTH-1:0]    address,  // Use address as seed variation
    output logic [WIDTH-1:0]    rand_out
);
    // Combinational LFSR using address as seed
    // This generates a deterministic pseudo-random value based on address
    
    function automatic logic [WIDTH-1:0] lfsr_step
    (
        input logic [WIDTH-1:0] state
    );
        logic [WIDTH-1:0] new_state;
        logic feedback;
        
        // Use a polynomial that fits within WIDTH bits
        // For WIDTH=12, use polynomial x^12 + x^6 + x^4 + x^1 + 1
        feedback = state[WIDTH-1] ^ state[WIDTH-2] ^ state[WIDTH-4] ^ state[WIDTH-6];
        
        new_state = {state[WIDTH-2:0], feedback};
        return new_state;
    endfunction
    
    function automatic logic [WIDTH-1:0] generate_random
    (
        input logic [WIDTH-1:0] addr
    );
        logic [WIDTH-1:0] state;
        // Use SEED's lower WIDTH bits
        logic [WIDTH-1:0] seed_truncated;
        
        seed_truncated = SEED[WIDTH-1:0];
        state = addr ^ seed_truncated;
        
        // Iterate LFSR for better distribution
        for (int i = 0; i < 8; i++) begin
            state = lfsr_step(state);
        end
        
        return state;
    endfunction
    
    assign rand_out = generate_random(address);
    
endmodule