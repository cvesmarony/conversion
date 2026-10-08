// One iteration of the scalable masking converter
//
// Operation:
//
//     u' = address
//     T(u') -> x[0], x[1], ..., x[n-1]
//     Generate n-1 random values
//     Refresh(T(u'), random)
//     Output refreshed shares
//
// Weston Nguyen

`timescale 1ns/1ps

import Convert_Defs::*;

module Mini_Refresh #(
    parameter int           ADDR_WIDTH = 12,
    parameter int           H_WIDTH = 12,
    parameter int           SHARES = 3,
    parameter int           Q = 3329,
    parameter group_mode_t  H_MODE = BOOLEAN
)(
    input logic CLK,
    input logic RSTN,

    // Start one iteration
    input logic [ADDR_WIDTH-1:0] address,
    input logic                  start,

    // Refreshed output
    output logic [SHARES-1:0][H_WIDTH-1:0] result,

    // One-cycle pulse when result is valid
    output logic done
);

    // State machine
    typedef enum logic [1:0] {
        IDLE,
        WAIT_TABLE,
        OUTPUT
    } state_t;

    state_t state;

    // Address register
    logic [ADDR_WIDTH-1:0] address_reg;

    // TTable
    localparam int DATA_WIDTH = SHARES * H_WIDTH;

    logic                    table_we;
    logic [ADDR_WIDTH-1:0]   table_addr;
    logic [DATA_WIDTH-1:0]   table_wdata;
    logic [DATA_WIDTH-1:0]   table_rdata;

    assign table_we    = 1'b0;
    assign table_addr  = address_reg;
    assign table_wdata = '0;

    TTable #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) table_inst (
        .CLK   (CLK),
        .we    (table_we),
        .addr  (table_addr),
        .wdata (table_wdata),
        .rdata (table_rdata)
    );


    // Table output -> shares
    // DATA_WIDTH = SHARES * H_WIDTH
    // For SHARES=3:
    // table_rdata = {x[2], x[1], x[0]}
    logic [SHARES-1:0][H_WIDTH-1:0] x;

    generate
        for (genvar i = 0; i < SHARES; i++) begin : UNPACK
            assign x[i] =
                table_rdata[i*H_WIDTH +: H_WIDTH];
        end
    endgenerate

    // PRNG
    // Refresh needs SHARES-1 random values.
    // For SHARES=3:
    //     r[0] = PRNG(address)
    //     r[1] = PRNG(address + 1)
    logic [SHARES-2:0][H_WIDTH-1:0] r;

    generate
        for (genvar i = 0; i < SHARES-1; i++) begin : PRNGS
            PRNG #(
                .WIDTH(H_WIDTH)
            ) prng_inst (
                .address(address_reg + i),
                .rand_out(r[i])
            );
        end
    endgenerate

    // Refresh
    logic [SHARES-1:0][H_WIDTH-1:0] y;

    Refresh #(
        .H_WIDTH(H_WIDTH),
        .SHARES(SHARES),
        .Q(Q),
        .H_MODE(H_MODE)
    ) refresh_inst (
        .x(x),
        .r(r),
        .y(y)
    );

    // Output
    always_ff @(posedge CLK) begin
        if (!RSTN) begin
            state       <= IDLE;
            address_reg <= '0;
            result      <= '0;
            done        <= 1'b0;
        end
        else begin
            // done is a pulse
            done <= 1'b0;

            case (state)
                // Wait for request
                IDLE: begin
                    if (start) begin
                        // Capture address
                        address_reg <= address;

                        // Start synchronous table read
                        state <= WAIT_TABLE;
                    end
                end

                // TTable has one-cycle read latency
                WAIT_TABLE: begin
                    state <= OUTPUT;
                end

                // T(u) is available.
                // Refresh is combinational, so y is available.
                OUTPUT: begin
                    result <= y;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule