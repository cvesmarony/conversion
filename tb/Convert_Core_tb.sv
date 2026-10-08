`timescale 1ns/1ps

import Convert_Defs::*;

// convert_check : one DUT + driver + scoreboard for a given (direction, SHARES)
//   A2B (H_MODE == BOOLEAN) : inputs in Zq,   check  XOR(y)        == SUM(x) mod q
//   B2A (H_MODE != BOOLEAN) : inputs k-bit,   check  SUM(y) mod q  == XOR(x) mod q
/* verilator lint_off DECLFILENAME */
module convert_check #(
/* verilator lint_on DECLFILENAME */
    parameter int          SHARES   = 2,
    parameter group_mode_t H_MODE   = BOOLEAN,
    parameter int          NUM_RAND = 20,
    parameter int          H_WIDTH  = 12,
    parameter int          Q        = 3329
)(
    output logic finished,
    output logic pass
);

    localparam bit A2B     = (H_MODE == BOOLEAN);
    localparam int DOMAIN  = A2B ? Q : (1 << H_WIDTH);
    localparam int MAXV    = A2B ? (Q - 1) : ((1 << H_WIDTH) - 1);
    localparam int MAX_CYC = 2 * SHARES * (DOMAIN + 2) + 100;

    // Clock / DUT
    logic CLK = 1'b0;
    always #5 CLK <= ~CLK;

    logic                           RSTN;
    logic                           start;
    logic [SHARES-1:0][H_WIDTH-1:0] x;
    logic [SHARES-1:0][H_WIDTH-1:0] y;
    logic                           busy;
    logic                           done;

    Convert_Core #(
        .H_WIDTH(H_WIDTH),
        .SHARES (SHARES),
        .Q      (Q),
        .H_MODE (H_MODE)
    ) dut (
        .CLK  (CLK),
        .RSTN(RSTN),
        .start(start),
        .x    (x),
        .busy (busy),
        .done (done),
        .y    (y)
    );

    // Scoreboard state
    string name;
    int    errors;
    int    tests;
    logic [SHARES-1:0][H_WIDTH-1:0] y_last;

    function automatic logic [SHARES-1:0][H_WIDTH-1:0] rand_vec();
        logic [SHARES-1:0][H_WIDTH-1:0] v;
        for (int i = 0; i < SHARES; i++)
            v[i] = H_WIDTH'($urandom_range(MAXV, 0));
        return v;
    endfunction

    // Drive on negedge, sample on negedge -> no races with the DUT's posedge logic
    task automatic run_one(input logic [SHARES-1:0][H_WIDTH-1:0] xin);
        int cyc;
        int sum_in, xor_in, sum_out, xor_out;
        int exp_v, got_v;

        // random idle gap so runs do not always start at the same nonce phase
        repeat ($urandom_range(0, 7)) @(negedge CLK);

        @(negedge CLK);
        x     = xin;
        start = 1'b1;
        @(negedge CLK);
        start = 1'b0;

        cyc = 0;
        while (!done && cyc < MAX_CYC) begin
            @(negedge CLK);
            cyc++;
        end
        tests++;

        if (!done) begin
            errors++;
            $display("[%s n=%0d] TIMEOUT, x=%h", name, SHARES, xin);
            return;
        end

        if ($isunknown(y)) begin
            errors++;
            $display("[%s n=%0d] X/Z on output, x=%h y=%h", name, SHARES, xin, y);
            return;
        end

        y_last  = y;
        sum_in  = 0; xor_in  = 0;
        sum_out = 0; xor_out = 0;
        for (int i = 0; i < SHARES; i++) begin
            sum_in  += int'(xin[i]);
            xor_in  ^= int'(xin[i]);
            sum_out += int'(y[i]);
            xor_out ^= int'(y[i]);
        end

        if (A2B) begin
            exp_v = sum_in % Q;
            got_v = xor_out;
        end else begin
            exp_v = xor_in % Q;
            got_v = sum_out % Q;
            for (int i = 0; i < SHARES; i++) begin
                if (int'(y[i]) >= Q) begin
                    errors++;
                    $display("[%s n=%0d] share %0d out of range: %0d >= q (x=%h y=%h)",
                             name, SHARES, i, int'(y[i]), xin, y);
                end
            end
        end

        if (got_v != exp_v) begin
            errors++;
            $display("[%s n=%0d] MISMATCH exp=%0d got=%0d  x=%h y=%h",
                     name, SHARES, exp_v, got_v, xin, y);
        end
    endtask

    // Test sequence
    initial begin
        logic [SHARES-1:0][H_WIDTH-1:0] v;
        logic [SHARES-1:0][H_WIDTH-1:0] y_prev;
        int distinct;

        name     = A2B ? "A2B" : "B2A";
        finished = 1'b0;
        pass     = 1'b0;
        errors   = 0;
        tests    = 0;
        RSTN    = 1'b0;
        start    = 1'b0;
        x        = '0;

        repeat (4) @(negedge CLK);
        RSTN = 1'b1;
        repeat (2) @(negedge CLK);

        if (busy || done) begin
            errors++;
            $display("[%s n=%0d] busy/done not idle after reset", name, SHARES);
        end

        // directed
        v = '0;
        run_one(v);                                    // all zero

        for (int i = 0; i < SHARES; i++) v[i] = H_WIDTH'(MAXV);
        run_one(v);                                    // all max

        for (int s = 0; s < SHARES; s++) begin         // one share hot
            v    = '0;
            v[s] = H_WIDTH'(MAXV);
            run_one(v);
        end

        v = '0;                                        // wrap-around at q
        if (A2B) begin
            v[0] = H_WIDTH'(Q - 1);
            v[1] = H_WIDTH'(1);                        // sum = q  -> 0
        end else begin
            v[0] = H_WIDTH'(Q);                        // xor = q  -> 0
        end
        run_one(v);

        if (!A2B) begin                                // xor result >= q
            v = '0;
            v[0] = H_WIDTH'(MAXV);
            v[1] = H_WIDTH'(12'h555);
            run_one(v);
        end

        // random
        for (int t = 0; t < NUM_RAND; t++)
            run_one(rand_vec());

        // re-randomisation: same input, output shares should differ
        v = rand_vec();
        run_one(v);
        y_prev   = y_last;
        distinct = 0;
        for (int k = 0; k < 3; k++) begin
            run_one(v);
            if (y_last != y_prev) distinct++;
            y_prev = y_last;
        end
        if (distinct == 0) begin
            errors++;
            $display("[%s n=%0d] identical output shares for repeated input (no re-randomisation)",
                     name, SHARES);
        end

        // summary
        pass = (errors == 0);
        $display("[%s n=%0d] %0d runs, %0d errors -> %s",
                 name, SHARES, tests, errors, pass ? "PASS" : "FAIL");
        finished = 1'b1;
    end

endmodule

// Top
module Convert_Core_tb;

    // Rename if Convert_Defs calls the non-BOOLEAN mode something else
    // localparam group_mode_t ARITH_MODE = ZQ;

    localparam int NUM_RAND = 20;     // random vectors per config (raise for soak)
    localparam int NCFG     = 6;
    localparam int CFG_SHARES [NCFG] = '{2, 3, 4, 2, 3, 4};
    localparam bit CFG_A2B    [NCFG] = '{1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0};

    wire [NCFG-1:0] fin_v;
    wire [NCFG-1:0] pass_v;

    for (genvar k = 0; k < NCFG; k++) begin : g_cfg
        convert_check #(
            .SHARES  (CFG_SHARES[k]),
            .H_MODE  (CFG_A2B[k] ? BOOLEAN : ZQ),
            .NUM_RAND(NUM_RAND)
        ) u_chk (
            .finished(fin_v[k]),
            .pass    (pass_v[k])
        );
    end

    initial begin
        wait (&fin_v);
        #1;
        if (&pass_v) $display("ALL TESTS PASSED");
        else         $display("TEST FAILED");
        $finish;
    end

    // watchdog
    initial begin
        #200ms;
        $display("TB WATCHDOG TIMEOUT");
        $finish;
    end

    // VCD Dump
    initial begin
        $dumpfile("waves/convert_core.vcd");
        $dumpvars(0, Convert_Core_tb);
    end

endmodule