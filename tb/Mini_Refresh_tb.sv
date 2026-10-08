// Mini_Refresh Testbench
// Tests one table lookup + PRNG + Refresh iteration
//
// Weston Nguyen

`timescale 1ns/1ps

module Mini_Refresh_tb;
    // Parameters
    localparam int          ADDR_WIDTH = 12;
    localparam int          H_WIDTH = 12;
    localparam int          SHARES = 3;
    localparam int          Q = 3329;

    localparam int DATA_WIDTH = SHARES * H_WIDTH;

    logic CLK;
    logic RSTN;

    always #5 CLK <= ~CLK;

    // Mini_Refresh inputs / outputs
    logic [ADDR_WIDTH-1:0] address;
    logic                  start;

    logic [SHARES-1:0][H_WIDTH-1:0] result;
    logic                            done;

    // DUT
    Mini_Refresh #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .H_WIDTH   (H_WIDTH),
        .SHARES    (SHARES),
        .Q         (Q),
        .H_MODE    (BOOLEAN)
    ) dut (
        .CLK     (CLK),
        .RSTN     (RSTN),
        .address (address),
        .start   (start),
        .result  (result),
        .done    (done)
    );

    // Test
    initial begin
        // Initialize
        CLK     = 0;
        RSTN     = 1;
        start   = 0;
        address = 0;

        repeat (2) @(posedge CLK);

        RSTN = 0;

        // TEST 1
        // Put known shares into TTable at address 5.
        // x[0] = 100
        // x[1] = 200
        // x[2] = 300
        // TTable stores:
        // {x[2], x[1], x[0]}

        $display("");
        $display("TEST 1: Mini_Refresh iteration");

        write_table(
            12'd5,
            {12'd300, 12'd200, 12'd100}
        );

        // Start Mini_Refresh
        $display("[%0t] Starting Mini_Refresh at address 5", $time);

        address = 12'd5;
        start   = 1'b1;

        @(posedge CLK);

        start = 1'b0;

        wait(done);
        #1;
        $display("[%0t] Mini_Refresh done", $time);

        $display("    result[0] = %0d", result[0]);
        $display("    result[1] = %0d", result[1]);
        $display("    result[2] = %0d", result[2]);

        // Check BOOLEAN refresh
        // In BOOLEAN mode:
        // y0 = x0 ^ r0
        // y1 = x1 ^ r1
        // y2 = x2 ^ r0 ^ r1
        // XOR of all shares should remain unchanged:
        // y0 ^ y1 ^ y2
        //     =
        // x0 ^ x1 ^ x2
        if ((result[0] ^ result[1] ^ result[2]) !=
            (12'd100 ^ 12'd200 ^ 12'd300)) begin

            $error(
                "TEST 1 FAILED: XOR of output shares does not match input"
            );
        end
        else begin
            $display("TEST 1 PASSED: XOR of shares preserved");
        end

        @(posedge CLK);

        // TEST 2: Second table address
        $display("");
        $display("TEST 2: Second table address");

        write_table(
            12'd10,
            {12'd1234, 12'd567, 12'd89}
        );

        address = 12'd10;
        start   = 1'b1;

        @(posedge CLK);

        start = 1'b0;

        wait(done);
        #1;
        $display("[%0t] Mini_Refresh done", $time);

        $display("    result[0] = %0d", result[0]);
        $display("    result[1] = %0d", result[1]);
        $display("    result[2] = %0d", result[2]);

        // Check preservation again
        if ((result[0] ^ result[1] ^ result[2]) !=
            (12'd89 ^ 12'd567 ^ 12'd1234)) begin

            $error(
                "TEST 2 FAILED: XOR of output shares does not match input"
            );
        end
        else begin
            $display("TEST 2 PASSED: XOR of shares preserved");
        end

        // Finished
        $display("");
        $display("ALL TESTS COMPLETE");

        $finish;
    end

    // Task: write one location in the DUT's TTable
    // We access the memory hierarchically because Mini_Refresh itself only performs reads.
    // This is testbench-only behavior.
    task automatic write_table(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data
    );
        begin
            // Write directly into the RAM.
            // This avoids adding a write interface to Mini_Refresh just for testing
            dut.table_inst.mem[addr] = data;
            $display(
                "[%0t] TTable[%0d] = %h",
                $time,
                addr,
                data
            );
        end
    endtask

    // VCD Dump
    initial begin
        $dumpfile("waves/mini_refresh_core.vcd");
        $dumpvars(0, Mini_Refresh_tb);
    end
endmodule