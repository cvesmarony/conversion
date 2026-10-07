`timescale 1ns/1ps

module PRNG_tb;

    parameter WIDTH = 12;
    parameter NUM_SAMPLES = 10000;
    
    logic clk;
    logic [WIDTH-1:0] address;
    logic [WIDTH-1:0] rand_out;
    
    // PRNG DUT
    PRNG #(
        .WIDTH(WIDTH),
        .SEED(32'hDEAD_BEEF)
    ) dut (
        .address(address),
        .rand_out(rand_out)
    );
    
    // Clock generation - use non-blocking assignment to avoid BLKSEQ
    always #5 clk <= ~clk;
    
    // Test results
    int total_tests;
    int passed_tests;
    int failed_tests;
    
    // Test 1: Deterministic output test
    task automatic test_deterministic;
        logic [WIDTH-1:0] addr;
        
        $display("\nTEST 1: DETERMINISTIC OUTPUT");
        
        // Test first few addresses - use proper width casting
        for (int i = 0; i < 20; i++) begin
            addr = WIDTH'(i);
            address = addr;
            #1;
            
            $display("addr=%0d -> rand_out=0x%0h", i, rand_out);
        end
        $display("Deterministic test completed\n");
    endtask
    
    // Test 2: Uniqueness test
    task automatic test_uniqueness;
        logic [WIDTH-1:0] values [0:100];
        bit is_unique = 1'b1;
        
        $display("\nTEST 2: UNIQUENESS");
        
        for (int i = 0; i < 100; i++) begin
            address = WIDTH'(i);
            #1;
            values[i] = rand_out;
            
            // Check against previous values
            for (int j = 0; j < i; j++) begin
                if (values[j] == values[i]) begin
                    $display("WARNING: Duplicate value at addresses %0d and %0d: 0x%0h", j, i, values[i]);
                    is_unique = 1'b0;
                end
            end
        end
        
        if (is_unique) begin
            $display("All 100 values unique\n");
        end else begin
            $display("Some duplicate values found (this is expected for PRNG)\n");
        end
    endtask
    
    // Test 3: Statistical distribution test
    task automatic test_distribution;
        integer count [0:15];
        real expected_count;
        real chi_square;
        real chi_square_critical = 25.0;
        logic [3:0] index;  // Use 4-bit for array indexing
        
        $display("\nTEST 3: STATISTICAL DISTRIBUTION");
        
        // Initialize histogram
        for (int i = 0; i < 16; i++) begin
            count[i] = 0;
        end
        
        // Generate samples
        for (int i = 0; i < NUM_SAMPLES; i++) begin
            address = WIDTH'(i);
            #1;
            // Extract lower 4 bits using proper width
            index = rand_out[3:0];
            count[index]++;
        end
        
        // Display histogram
        $display("Distribution of lower 4 bits across %0d samples:", NUM_SAMPLES);
        expected_count = NUM_SAMPLES / 16.0;
        
        for (int i = 0; i < 16; i++) begin
            $display("value %0d: %0d (expected ~%0.0f)", i, count[i], expected_count);
        end
        
        // Calculate chi-square
        chi_square = 0;
        for (int i = 0; i < 16; i++) begin
            chi_square = chi_square + ((count[i] - expected_count) ** 2) / expected_count;
        end
        
        $display("Chi-square = %0.2f (critical = %0.2f)", chi_square, chi_square_critical);
        
        if (chi_square < chi_square_critical) begin
            $display("Distribution is statistically random\n");
        end else begin
            $display("Distribution may not be random\n");
        end
    endtask
    
    // Test 4: Avalanche effect
    task automatic test_avalanche;
        logic [WIDTH-1:0] val1, val2;
        int differences;
        real avg_diff;
        
        $display("\nTEST 4: AVALANCHE EFFECT");
        
        differences = 0;
        
        for (int i = 0; i < 100; i++) begin
            address = WIDTH'(i);
            #1;
            val1 = rand_out;
            
            address = WIDTH'(i + 1);
            #1;
            val2 = rand_out;
            
            // Count bit differences
            differences = differences + $countones(val1 ^ val2);
        end
        
        avg_diff = differences / 100.0;
        $display("Average bit differences for adjacent addresses: %0.2f", avg_diff);
        $display("Expected for good PRNG: ~%0.2f bits", WIDTH/2.0);
        
        if (avg_diff >= WIDTH/4 && avg_diff <= WIDTH*3/4) begin
            $display("Avalanche effect is good\n");
        end else begin
            $display("Avalanche effect may be weak\n");
        end
    endtask
    
    // Main test flow
    initial begin
        // Initialize
        clk = 0;
        address = '0;
        #10;
        
        $display("PRNG TESTBENCH");
        $display("WIDTH = %0d", WIDTH);
        
        // Run tests
        test_deterministic();
        test_uniqueness();
        test_distribution();
        test_avalanche();
        
        // Summary
        $display("TEST SUMMARY");
        $display("All tests completed!");
        
        #10;
        $finish;
    end
    
endmodule