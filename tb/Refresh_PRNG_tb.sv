`timescale 1ns/1ps

module Refresh_PRNG_tb;
    import Convert_Defs::*;

    // Parameters
    parameter int H_WIDTH   = 12;
    parameter int SHARES    = 12;
    parameter int Q         = 3329;
    parameter int NUM_TESTS = 1000;

    // Signals
    logic [SHARES-1:0][H_WIDTH-1:0] x;
    logic [SHARES-1:0][H_WIDTH-1:0] y;

    logic [SHARES-2:0][H_WIDTH-1:0] r_from_prng;

    logic [H_WIDTH-1:0] prng_addr;

    // Test Counters
    int total_tests;
    int passed_tests;
    int failed_tests;

    // DUT: Refresh
    Refresh #(
        .H_WIDTH(H_WIDTH),
        .SHARES (SHARES),
        .Q      (Q),
        .H_MODE (ZQ)
    ) dut (
        .x(x),
        .r(r_from_prng),
        .y(y)
    );

    // PRNG Instances
    generate
        for (genvar s = 0; s < SHARES-1; s++) begin : gen_prng
            logic [H_WIDTH-1:0] prng_raw;
            logic [31:0]        prng_value;
            logic [31:0]        prng_mod;

            PRNG #(
                .WIDTH(H_WIDTH),
                .SEED(32'hDEAD_BEEF + s)
            ) prng_inst (
                .address(prng_addr + s),
                .rand_out(prng_raw)
            );

            // Zero-extend PRNG output to 32 bits
            assign prng_value =
                {{(32-H_WIDTH){1'b0}}, prng_raw};

            // Perform modulo at 32-bit width
            assign prng_mod = prng_value % Q;

            // Explicitly convert result back to H_WIDTH
            assign r_from_prng[s] = H_WIDTH'(prng_mod);
        end
    endgenerate

    // Helper Functions
    // Count number of differing bits
    function automatic int count_ones(
        input logic [H_WIDTH-1:0] vec
    );
        int count;

        begin
            count = 0;

            for (int i = 0; i < H_WIDTH; i++) begin
                if (vec[i])
                    count++;
            end

            return count;
        end
    endfunction

    // Generate random value in [0, Q-1]
    function automatic logic [H_WIDTH-1:0] gen_rand_zq();
        logic [31:0] random_32;
        logic [31:0] mod_result;

        begin
            random_32 = $urandom();
            mod_result = random_32 % Q;

            return mod_result[H_WIDTH-1:0];
        end
    endfunction

    // Reconstruct arithmetic shares modulo Q
    function automatic int sum_shares_mod(
        input logic [SHARES-1:0][H_WIDTH-1:0] shares
    );

        int result;
        begin
            result = 0;
            for (int i = 0; i < SHARES; i++) begin
                result = result + int'(shares[i]);
            end
            return result % Q;
        end
    endfunction

    // Printing Helpers
    task automatic print_test_header(
        input string name
    );
        begin
            $display("");
            $display("TEST: %s", name);
        end
    endtask

    task automatic print_shares();
        begin
            $write("x = [");
            for (int i = 0; i < SHARES; i++) begin
                $write("%0d", x[i]);

                if (i < SHARES-1)
                    $write(", ");
            end
            $display("]");
            $write("r = [");
            for (int i = 0; i < SHARES-1; i++) begin
                $write("%0d", r_from_prng[i]);

                if (i < SHARES-2)
                    $write(", ");
            end
            $display("]");
            $write("y = [");
            for (int i = 0; i < SHARES; i++) begin
                $write("%0d", y[i]);

                if (i < SHARES-1)
                    $write(", ");
            end
            $display("]");
        end
    endtask

    // TEST 1: Refresh Invariant
    // Verify:
    //     sum(x) mod Q == sum(y) mod Q
    // This confirms that Refresh preserves the masked value.

    task automatic test_refresh_invariant(
        input string test_name
    );
        int sum_x;
        int sum_y;
        bit test_ok;

        begin
            test_ok = 1'b1;

            // Generate random input shares
            for (int i = 0; i < SHARES; i++) begin
                x[i] = gen_rand_zq();
            end

            // Generate PRNG address
            prng_addr = gen_rand_zq();

            // Allow combinational logic to settle
            #1;

            sum_x = sum_shares_mod(x);
            sum_y = sum_shares_mod(y);

            // Check reconstruction
            if (sum_x != sum_y) begin
                $display(
                    "FAIL: %s - Reconstruction mismatch",
                    test_name
                );

                $display(
                    "sum(x) mod Q = %0d",
                    sum_x
                );

                $display(
                    "sum(y) mod Q = %0d",
                    sum_y
                );

                print_shares();

                test_ok = 1'b0;
            end

            // Check output range
            for (int i = 0; i < SHARES; i++) begin
                if (int'(y[i]) >= Q) begin

                    $display(
                        "FAIL: %s - y[%0d] out of range: %0d",
                        test_name,
                        i,
                        y[i]
                    );

                    test_ok = 1'b0;
                end
            end

            // Record result
            if (test_ok) begin
                $display(
                    "PASS: %s",
                    test_name
                );

                passed_tests++;
            end
            else begin
                failed_tests++;
            end

            total_tests++;
        end
    endtask

    // TEST 2: PRNG / Refresh Output Variation
    // Same x values are used while the PRNG address changes.
    // The reconstructed value must stay constant, while the individual Refresh shares should generally change.
    task automatic test_output_variation();
        logic [SHARES-1:0][H_WIDTH-1:0] previous_y;

        int different_outputs;
        int total_bit_differences;
        int bit_differences;

        int expected_value;
        int current_value;

        begin
            print_test_header(
                "PRNG / Refresh Output Variation"
            );

            // Fixed input
            for (int i = 0; i < SHARES; i++) begin
                x[i] = H_WIDTH'((123 + (333 * i)) % Q);
            end

            expected_value = sum_shares_mod(x);

            different_outputs = 0;
            total_bit_differences = 0;

            // First output
            prng_addr = '0;
            #1;

            previous_y = y;
            // Try many different PRNG addresses
            for (int i = 1; i < 100; i++) begin
                prng_addr = i[H_WIDTH-1:0];

                #1;

                current_value = sum_shares_mod(y);

                // Reconstruction must remain unchanged
                if (current_value != expected_value) begin
                    $display("FAIL: Reconstruction changed at address %0d", i);

                    $display("Expected = %0d, Got = %0d", expected_value, current_value);
                    failed_tests++;
                    total_tests++;
                    return;
                end

                // Compare current shares with previous shares
                bit_differences = 0;
                for (int s = 0; s < SHARES; s++) begin
                    bit_differences =
                        bit_differences +
                        count_ones(previous_y[s] ^ y[s]);
                end

                total_bit_differences =
                    total_bit_differences + bit_differences;

                if (bit_differences > 0)
                    different_outputs++;

                previous_y = y;
            end

            $display("Different outputs: %0d / 99", different_outputs);

            $display("Total differing bits: %0d", total_bit_differences);

            if (different_outputs > 0) begin
                $display("PASS: PRNG address changes produce different shares");
                passed_tests++;
            end
            else begin
                $display("FAIL: PRNG address changes produced no variation");
                failed_tests++;
            end

            total_tests++;
        end
    endtask

    // TEST 3: Same PRNG Address
    // Same x + same PRNG address should produce the same y.
    // This checks that the combinational PRNG/Refresh path is deterministic.

    task automatic test_deterministic_output();
        logic [SHARES-1:0][H_WIDTH-1:0] y_first;
        bit test_ok;

        begin
            print_test_header(
                "Deterministic PRNG / Refresh Output"
            );
            test_ok = 1'b1;

            // Fixed input
            for (int i = 0; i < SHARES; i++) begin
                x[i] = gen_rand_zq();
            end

            prng_addr = 12'd1234;

            #1;

            y_first = y;

            // Evaluate again with exactly same inputs
            #1;

            for (int i = 0; i < SHARES; i++) begin
                if (y[i] !== y_first[i]) begin
                    test_ok = 1'b0;
                end
            end

            if (test_ok) begin
                $display("PASS: Same inputs produce identical outputs");
                passed_tests++;
            end
            else begin
                $display("FAIL: Same inputs produced different outputs");
                print_shares();
                failed_tests++;
            end

            total_tests++;
        end
    endtask

    // Main Test
    initial begin
        // Initialize
        x = '0;
        prng_addr = '0;

        total_tests  = 0;
        passed_tests = 0;
        failed_tests = 0;

        // Header
        $display("");  
        $display("REFRESH + PRNG TESTBENCH");
        $display("H_WIDTH = %0d", H_WIDTH);
        $display("SHARES  = %0d", SHARES);
        $display("Q       = %0d", Q);
        $display("Tests   = %0d", NUM_TESTS);
        $display("Valid range = [0, %0d]", Q-1);

        // TEST 1
        print_test_header($sformatf("Refresh Invariant (%0d random tests)", NUM_TESTS));

        for (int i = 0; i < NUM_TESTS; i++) begin
            test_refresh_invariant($sformatf("Random test %0d", i+1));
        end

        // TEST 2
        test_output_variation();

        // TEST 3
        test_deterministic_output();

        // Summary
        $display("");
        $display("TEST SUMMARY");
        $display("Total tests:  %0d", total_tests);
        $display("Passed:       %0d", passed_tests);
        $display("Failed:       %0d", failed_tests);

        if (failed_tests == 0) begin
            $display("");
            $display("ALL TESTS PASSED");
            $display("");
        end
        else begin
            $display("");
            $display("SOME TESTS FAILED");
            $display("");
        end

        #10;
        $finish;
    end

    // VCD Dump
    initial begin
        $dumpfile("waves/refresh_prng.vcd");
        $dumpvars(0, Refresh_PRNG_tb);
    end
endmodule