`timescale 1ns/1ps

module TTable_tb;

    // Parameters
    localparam int ADDR_WIDTH = 12;
    localparam int DATA_WIDTH = 36;
    // localparam int DEPTH      = 1 << ADDR_WIDTH;

    // DUT signals
    logic                   clk;
    logic                   we;
    logic [ADDR_WIDTH-1:0]  addr;
    logic [DATA_WIDTH-1:0]  wdata;
    logic [DATA_WIDTH-1:0]  rdata;

    // Instantiate DUT
    TTable #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk   (clk),
        .we    (we),
        .addr  (addr),
        .wdata  (wdata),
        .rdata  (rdata)
    );

    // Clock: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initial values
        we    = 1'b0;
        addr  = '0;
        wdata = '0;

        // Wait for a couple clock cycles
        repeat (2) @(posedge clk);

        // Test 1: Write address 0
        $display("TEST 1: Writing address 0");

        @(negedge clk);
        we    = 1'b1;
        addr  = 12'd0;
        wdata = 36'h123456789;

        @(posedge clk);

        // Stop writing
        @(negedge clk);
        we = 1'b0;

        // Read address 0
        addr = 12'd0;

        @(posedge clk);
        #1;
        if (rdata !== 36'h123456789)
            $error("TEST 1 FAILED: expected %h, got %h",
                   36'h123456789, rdata);
        else
            $display("TEST 1 PASSED");

        // Test 2: Write/read another address
        $display("TEST 2: Writing address 123");

        @(negedge clk);
        we    = 1'b1;
        addr  = 12'd123;
        wdata = 36'hABCDEF123;

        @(posedge clk);

        @(negedge clk);
        we   = 1'b0;
        addr = 12'd123;

        @(posedge clk);
        #1;
        if (rdata !== 36'hABCDEF123)
            $error("TEST 2 FAILED: expected %h, got %h",
                   36'hABCDEF123, rdata);
        else
            $display("TEST 2 PASSED");

        // Test 3: Make sure address 0 still contains its value
        $display("TEST 3: Checking address 0");

        @(negedge clk);
        addr = 12'd0;

        @(posedge clk);
        #1;
        if (rdata !== 36'h123456789)
            $error("TEST 3 FAILED: expected %h, got %h",
                   36'h123456789, rdata);
        else
            $display("TEST 3 PASSED");

        // Test 4: Overwrite address 0
        $display("TEST 4: Overwriting address 0");

        @(negedge clk);
        we    = 1'b1;
        addr  = 12'd0;
        wdata = 36'hFEDCBA987;

        @(posedge clk);

        @(negedge clk);
        we = 1'b0;

        @(posedge clk);
        #1;
        if (rdata !== 36'hFEDCBA987)
            $error("TEST 4 FAILED: expected %h, got %h",
                   36'hFEDCBA987, rdata);
        else
            $display("TEST 4 PASSED");

        // Test 5: Several addresses
        $display("TEST 5: Writing multiple addresses");

        // Address 10
        @(negedge clk);
        we    = 1'b1;
        addr  = 12'd10;
        wdata = 36'h111111111;
        @(posedge clk);

        // Address 20
        @(negedge clk);
        addr  = 12'd20;
        wdata = 36'h222222222;
        @(posedge clk);

        // Address 30
        @(negedge clk);
        addr  = 12'd30;
        wdata = 36'h333333333;
        @(posedge clk);

        // Stop writing
        @(negedge clk);
        we = 1'b0;

        // Read address 10
        addr = 12'd10;
        @(posedge clk);
        #1;
        if (rdata !== 36'h111111111)
            $error("TEST 5A FAILED: expected %h, got %h",
                   36'h111111111, rdata);

        // Read address 20
        addr = 12'd20;
        @(posedge clk);
        #1;
        if (rdata !== 36'h222222222)
            $error("TEST 5B FAILED: expected %h, got %h",
                   36'h222222222, rdata);

        // Read address 30
        addr = 12'd30;
        @(posedge clk);
        #1;
        if (rdata !== 36'h333333333)
            $error("TEST 5C FAILED: expected %h, got %h",
                   36'h333333333, rdata);

        $display("TEST 5 PASSED");

        // Finish
        $display("ALL TESTS COMPLETED");

        $finish;
    end

    // VCD Dump
    initial begin
        $dumpfile("waves/ttable.vcd");
        $dumpvars(0, TTable_tb);
    end
endmodule