`timescale 1ns/1ps

module Refresh_tb;
    // Parameters
    localparam int H_W = 12;
    localparam int N   = 8;
    localparam int Q   = 3329;

    localparam int NUM_RANDOM_TESTS = 1000;

    // DUT Signals
    logic [N-1:0][H_W-1:0] x;
    logic [N-2:0][H_W-1:0] r;

    logic [N-1:0][H_W-1:0] y_boolean;
    logic [N-1:0][H_W-1:0] y_arithmetic;

    // Waveform Signals
    logic [H_W-1:0] xor_reconstructed;
    int sum_reconstructed;

    // DUT Instances
    // Boolean Refresh
    Refresh #(
        .H_WIDTH(H_W),
        .SHARES(N),
        .Q(Q),
        .H_MODE(BOOLEAN)
    ) refresh_boolean (
        .x(x),
        .r(r),
        .y(y_boolean)
    );

    // Arithmetic Refresh
    Refresh #(
        .H_WIDTH(H_W),
        .SHARES(N),
        .Q(Q),
        .H_MODE(ZQ)
    ) refresh_arithmetic (
        .x(x),
        .r(r),
        .y(y_arithmetic)
    );

    // Reconstruction Functions
    // Reconstruct a Boolean/XOR-shared value
    function automatic logic [H_W-1:0] reconstruct_boolean(
        input logic [N-1:0][H_W-1:0] shares
    );
        logic [H_W-1:0] result;
        result = '0;
        for (int i = 0; i < N; i++) begin
            result = result ^ shares[i];
        end
        return result;
    endfunction

    // Reconstruct an arithmetic-shared value modulo Q
    function automatic int reconstruct_arithmetic(
        input logic [N-1:0][H_W-1:0] shares
    );
        int result;
        result = 0;
        for (int i = 0; i < N; i++) begin
            result = result + int'(shares[i]);
        end
        return result % Q;
    endfunction

    // Waveform Reconstruction
    assign xor_reconstructed = reconstruct_boolean(y_boolean);
    assign sum_reconstructed = reconstruct_arithmetic(y_arithmetic);

    // Test Status
    int total_tests  = 0;
    int passed_tests = 0;
    int failed_tests = 0;

    // Print Helpers
    task automatic print_test_header(string name);
        $display("");
        $display("TEST: %s", name);
    endtask

    task automatic print_shares();
        // x
        $write("x       = [");
        for (int i = 0; i < N; i++) begin
            $write("%0d", x[i]);

            if (i < N-1)
                $write(", ");
        end
        $display("]");

        // r
        $write("r       = [");
        for (int i = 0; i < N-1; i++) begin
            $write("%0d", r[i]);

            if (i < N-2)
                $write(", ");
        end
        $display("]");

        // Boolean output
        $write("y_bool  = [");
        for (int i = 0; i < N; i++) begin
            $write("%0d", y_boolean[i]);

            if (i < N-1)
                $write(", ");
        end
        $display("]");

        // Arithmetic output
        $write("y_arith = [");
        for (int i = 0; i < N; i++) begin
            $write("%0d", y_arithmetic[i]);

            if (i < N-1)
                $write(", ");
        end
        $display("]");
    endtask

    task automatic print_reconstruction();
        $display(
            "XOR(x) = %0d, XOR(y_bool) = %0d",
            reconstruct_boolean(x),
            reconstruct_boolean(y_boolean)
        );

        $display(
            "SUM(x) mod %0d = %0d, SUM(y_arith) mod %0d = %0d",
            Q,
            reconstruct_arithmetic(x),
            Q,
            reconstruct_arithmetic(y_arithmetic)
        );
    endtask

    // Check Functions
    task automatic check_boolean(string test_name);
        logic [H_W-1:0] expected;
        logic [H_W-1:0] actual;

        expected = reconstruct_boolean(x);
        actual   = reconstruct_boolean(y_boolean);

        total_tests++;

        if (actual == expected) begin
            passed_tests++;

            $display(
                "BOOLEAN: PASS (%s)",
                test_name
            );
        end
        else begin
            failed_tests++;

            $display(
                "BOOLEAN: FAIL (%s)",
                test_name
            );

            $display(
                "Expected: %0d, Actual: %0d",
                expected,
                actual
            );

            print_shares();
        end
    endtask

    task automatic check_arithmetic(string test_name);
        int expected;
        int actual;

        expected = reconstruct_arithmetic(x);
        actual   = reconstruct_arithmetic(y_arithmetic);

        total_tests++;

        if (actual == expected) begin
            passed_tests++;

            $display(
                "ARITHMETIC: PASS (%s)",
                test_name
            );
        end
        else begin
            failed_tests++;

            $display(
                "ARITHMETIC: FAIL (%s)",
                test_name
            );

            $display(
                "Expected: %0d, Actual: %0d",
                expected,
                actual
            );

            print_shares();
        end
    endtask

    task automatic check_range(string test_name);
        bit valid;
        valid = 1'b1;
        for (int i = 0; i < N; i++) begin
            if (int'(y_arithmetic[i]) >= Q)
                valid = 1'b0;
        end

        total_tests++;

        if (valid) begin
            passed_tests++;

            $display(
                "RANGE: PASS (%s)",
                test_name
            );
        end
        else begin
            failed_tests++;

            $display(
                "RANGE: FAIL (%s)",
                test_name
            );

            print_shares();
        end
    endtask

    // TEST 1: Basic Functionality
    task automatic test_basic;
        print_test_header("1. Basic Functionality");

        // Give every share a value
        for (int i = 0; i < N; i++) begin
            x[i] = H_W'(i + 1);
        end

        // Give every random mask a value
        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(i + 2);
        end

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("Basic");
        check_arithmetic("Basic");
        check_range("Basic");
    endtask

    // TEST 2: All Zeros
    task automatic test_all_zeros;
        print_test_header("2. All Zeros");

        x = '0;
        r = '0;

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("All zeros");
        check_arithmetic("All zeros");
        check_range("All zeros");
    endtask

    // TEST 3: Boolean Maximum
    task automatic test_boolean_maximum;
        print_test_header("3. Boolean Maximum");

        for (int i = 0; i < N; i++) begin
            x[i] = {H_W{1'b1}};
        end

        for (int i = 0; i < N-1; i++) begin
            r[i] = {H_W{1'b1}};
        end

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("Boolean maximum");
    endtask

    // TEST 4: Arithmetic Maximum
    task automatic test_arithmetic_maximum;
        print_test_header("4. Arithmetic Maximum (Q-1)");

        for (int i = 0; i < N; i++) begin
            x[i] = H_W'(Q-1);
        end

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(Q-1);
        end

        #1;

        print_shares();
        print_reconstruction();

        check_arithmetic("Arithmetic maximum");
        check_range("Arithmetic maximum");
    endtask

    // TEST 5: Addition / No Wrap
    task automatic test_add_no_wrap;
        print_test_header("5. Addition (No Wrap)");

        for (int i = 0; i < N; i++) begin
            x[i] = H_W'(i + 1);
        end

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(i + 2);
        end

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("Add no wrap");
        check_arithmetic("Add no wrap");
        check_range("Add no wrap");
    endtask

    // TEST 6: Addition / Equals Q
    task automatic test_add_equals_q;
        print_test_header("6. Addition (Equals Q)");

        x = '0;
        r = '0;

        x[0] = H_W'(Q-6);

        if (N > 1)
            r[0] = H_W'(6);

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("Add equals Q");
        check_arithmetic("Add equals Q");
        check_range("Add equals Q");
    endtask

    // TEST 7: Addition / Wrap
    task automatic test_add_wrap;
        print_test_header("7. Addition (Wrap Around)");

        for (int i = 0; i < N; i++) begin
            x[i] = H_W'(Q-3);
        end

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(Q-2);
        end

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("Add wrap");
        check_arithmetic("Add wrap");
        check_range("Add wrap");
    endtask

    // TEST 8: Subtraction / No Underflow
    task automatic test_sub_no_underflow;
        print_test_header("8. Subtraction (No Underflow)");

        x = '0;

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(1);
        end

        x[N-1] = H_W'(Q-1);

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("Sub no underflow");
        check_arithmetic("Sub no underflow");
        check_range("Sub no underflow");
    endtask

    // TEST 9: Subtraction / Underflow
    task automatic test_sub_underflow;
        print_test_header("9. Subtraction (Underflow)");

        x = '0;

        x[N-1] = H_W'(1);

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(Q-2);
        end

        #1;

        print_shares();
        print_reconstruction();

        check_boolean("Sub underflow");
        check_arithmetic("Sub underflow");
        check_range("Sub underflow");
    endtask

    // TEST 10: Arithmetic Boundaries
    task automatic test_arithmetic_boundaries;
        print_test_header("10. Arithmetic Boundaries");

        x = '0;
        r = '0;

        x[0] = H_W'(Q-1);

        if (N > 1)
            x[1] = H_W'(1);

        if (N > 1)
            r[0] = H_W'(Q-1);

        if (N > 2)
            r[1] = H_W'(1);

        #1;

        print_shares();
        print_reconstruction();

        check_arithmetic("Boundaries");
        check_range("Boundaries");
    endtask

    // TEST 11: Random Boolean
    task automatic test_random_boolean;
        int pass_count;
        int rand_val;

        print_test_header(
            $sformatf(
                "11. Random Boolean (%0d tests)",
                NUM_RANDOM_TESTS
            )
        );

        pass_count = 0;

        for (int test = 0; test < NUM_RANDOM_TESTS; test++) begin

            // Random Boolean input shares
            for (int i = 0; i < N; i++) begin
                rand_val = $urandom();
                x[i] = rand_val[H_W-1:0];
            end

            // Random Boolean masks
            for (int i = 0; i < N-1; i++) begin
                rand_val = $urandom();
                r[i] = rand_val[H_W-1:0];
            end

            #1;

            if (
                reconstruct_boolean(y_boolean) ==
                reconstruct_boolean(x)
            ) begin
                pass_count++;
            end
        end

        $display(
            "Boolean: %0d/%0d passed",
            pass_count,
            NUM_RANDOM_TESTS
        );

        total_tests++;

        if (pass_count == NUM_RANDOM_TESTS) begin
            passed_tests++;
            $display("ALL PASSED");
        end
        else begin
            failed_tests++;
            $display("SOME FAILED");
        end
    endtask

    // TEST 12: Random Arithmetic
    task automatic test_random_arithmetic;
        int pass_count;
        int range_pass;
        bit valid;

        print_test_header(
            $sformatf(
                "12. Random Arithmetic (%0d tests)",
                NUM_RANDOM_TESTS
            )
        );

        pass_count = 0;
        range_pass = 0;

        for (int test = 0; test < NUM_RANDOM_TESTS; test++) begin

            // Random arithmetic input shares
            for (int i = 0; i < N; i++) begin
                x[i] = H_W'($urandom_range(0, Q-1));
            end

            // Random arithmetic masks
            for (int i = 0; i < N-1; i++) begin
                r[i] = H_W'($urandom_range(0, Q-1));
            end

            #1;

            // Check arithmetic invariant
            if (
                reconstruct_arithmetic(y_arithmetic) ==
                reconstruct_arithmetic(x)
            ) begin
                pass_count++;
            end

            // Check range
            valid = 1'b1;

            for (int i = 0; i < N; i++) begin
                if (int'(y_arithmetic[i]) >= Q)
                    valid = 1'b0;
            end

            if (valid)
                range_pass++;

        end

        $display(
            "Arithmetic invariant: %0d/%0d passed",
            pass_count,
            NUM_RANDOM_TESTS
        );

        $display(
            "Range check: %0d/%0d passed",
            range_pass,
            NUM_RANDOM_TESTS
        );

        total_tests++;

        if (
            pass_count == NUM_RANDOM_TESTS &&
            range_pass == NUM_RANDOM_TESTS
        ) begin
            passed_tests++;
            $display("ALL PASSED");
        end
        else begin
            failed_tests++;
            $display("SOME FAILED");
        end
    endtask

    // TEST 13: Repeated Refresh
    task automatic test_repeated_refresh;
        print_test_header("13. Repeated Refresh");

        // Stage 1
        for (int i = 0; i < N; i++) begin
            x[i] = H_W'(i + 3);
        end

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(i + 2);
        end

        #1;

        $display("Stage 1: Refresh");

        check_boolean("Repeat 1");
        check_arithmetic("Repeat 1");
        check_range("Repeat 1");

        // Stage 2: Boolean output becomes new input
        x = y_boolean;

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(i + 1);
        end

        #1;

        $display("Stage 2: Refresh Boolean output");

        check_boolean("Repeat 2");

        // Stage 3: Arithmetic output becomes new input
        x = y_arithmetic;

        for (int i = 0; i < N-1; i++) begin
            r[i] = H_W'(i + 3);
        end

        #1;

        $display("Stage 3: Refresh Arithmetic output");

        check_arithmetic("Repeat 3");
        check_range("Repeat 3");
    endtask

    // Main Test Flow
    initial begin
        $dumpfile("waves/refresh.vcd");
        $dumpvars(0, Refresh_tb);

        $display("");
        $display("REFRESH MODULE TESTBENCH");
        $display("H_W = %0d, N = %0d, Q = %0d", H_W, N, Q);
        $display(
            "Random tests per category = %0d",
            NUM_RANDOM_TESTS
        );

        // Run tests
        test_basic();
        test_all_zeros();
        test_boolean_maximum();
        test_arithmetic_maximum();
        test_add_no_wrap();
        test_add_equals_q();
        test_add_wrap();
        test_sub_no_underflow();
        test_sub_underflow();
        test_arithmetic_boundaries();
        test_random_boolean();
        test_random_arithmetic();
        test_repeated_refresh();

        // Final Summary
        $display("");
        $display("TEST SUMMARY");
        $display("Total checks: %-5d", total_tests);
        $display("Passed:       %-5d", passed_tests);
        $display("Failed:       %-5d", failed_tests);

        if (failed_tests == 0) begin
            $display("");
            $display("ALL TESTS PASSED");
        end
        else begin
            $display("");
            $display("SOME TESTS FAILED");
        end

        #10;
        $finish;
    end
endmodule