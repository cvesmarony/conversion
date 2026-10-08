`timescale 1ns/1ps

import Convert_Defs::*;

module Convert_Core #(
    parameter int          H_WIDTH = 12,
    parameter int          SHARES  = 2,          // must be >= 2
    parameter int          Q       = 3329,
    parameter group_mode_t H_MODE  = BOOLEAN     // BOOLEAN: A2B (Alg 8), else B2A (Alg 3)
)(
    input  logic                            CLK,
    input  logic                            RSTN,

    input  logic                            start,
    input  logic [SHARES-1:0][H_WIDTH-1:0]  x,      // sampled on start

    output logic                            busy,
    output logic                            done,   // 1-cycle pulse, y valid
    output logic [SHARES-1:0][H_WIDTH-1:0]  y
);

    // Local parameters
    localparam bit A2B     = (H_MODE == BOOLEAN);
    localparam int DOMAIN  = A2B ? Q : (1 << H_WIDTH);   // # table entries
    localparam int DATA_W  = SHARES * H_WIDTH;
    localparam int CNT_W   = H_WIDTH + 1;                // counts 0..DOMAIN
    localparam int RW      = (SHARES > 2) ? $clog2(SHARES) : 1;

    typedef enum logic [2:0] {
        S_IDLE,
        S_INIT,        // T(u) <- (u mod q, 0, ..., 0)
        S_ROUND,       // for i = 1..n-1 : T <- Refresh(T[u op x_i])
        S_FINAL_RD,    // present address x_n
        S_FINAL_WAIT   // rdata valid -> refresh -> y
    } state_t;

    state_t             state;
    logic [CNT_W-1:0]   cnt;
    logic [RW-1:0]      round_q;     // 0 .. SHARES-2
    logic               src_sel;     // bank being read this round
    logic [H_WIDTH-1:0] nonce_q;

    logic [SHARES-1:0][H_WIDTH-1:0] x_q;

    // Two table banks (ping-pong)
    logic [H_WIDTH-1:0] addr0, addr1;
    logic               we0,   we1;
    logic [DATA_W-1:0]  wdata;
    logic [DATA_W-1:0]  rdata0, rdata1, src_rdata;

    TTable #(.ADDR_WIDTH(H_WIDTH), .DATA_WIDTH(DATA_W)) u_bank0 (
        .CLK(CLK), .we(we0), .addr(addr0), .wdata(wdata), .rdata(rdata0)
    );
    TTable #(.ADDR_WIDTH(H_WIDTH), .DATA_WIDTH(DATA_W)) u_bank1 (
        .CLK(CLK), .we(we1), .addr(addr1), .wdata(wdata), .rdata(rdata1)
    );

    assign src_rdata = src_sel ? rdata1 : rdata0;

    // Address generation
    logic [H_WIDTH-1:0] x_i;          // current round's x_i
    logic [H_WIDTH-1:0] rd_addr;      // read address on source bank
    logic [H_WIDTH-1:0] wr_addr;      // write address on destination bank
    logic               wr_en_round;

    assign x_i        = x_q[round_q];
    assign wr_addr    = H_WIDTH'(cnt - 1'b1);       // entry read one cycle ago
    assign wr_en_round = (cnt != '0);               // nothing to write at cnt==0

    always_comb begin
        logic [H_WIDTH:0] sum;
        rd_addr = '0;
        sum     = '0;

        unique case (state)
            S_ROUND: begin
                if (A2B) begin
                    // (u + x_i) mod q
                    sum = {1'b0, cnt[H_WIDTH-1:0]} + {1'b0, x_i};
                    if (sum >= (H_WIDTH+1)'(Q))
                        sum = sum - (H_WIDTH+1)'(Q);
                    rd_addr = sum[H_WIDTH-1:0];
                end else begin
                    // u xor x_i
                    rd_addr = cnt[H_WIDTH-1:0] ^ x_i;
                end
            end
            S_FINAL_RD,
            S_FINAL_WAIT: rd_addr = x_q[SHARES-1];
            default:      rd_addr = '0;
        endcase
    end

    // Init data: T(u) = (u mod q, 0, ..., 0)   (share 0 in the LSBs)
    logic [H_WIDTH-1:0] u_mod;
    logic [DATA_W-1:0]  init_data;

    always_comb begin
        u_mod = cnt[H_WIDTH-1:0];
        if (u_mod >= H_WIDTH'(Q))        // only reachable in B2A (u in 0..2^k-1)
            u_mod = u_mod - H_WIDTH'(Q);
        init_data = DATA_W'(u_mod);
    end

    // Randomness: SHARES-1 words per refresh
    logic [H_WIDTH-1:0]            u_for_rand;
    logic [31:0]                   rnd_round;
    logic [SHARES-2:0][H_WIDTH-1:0] r;

    assign u_for_rand = (state == S_ROUND) ? wr_addr : x_q[SHARES-1];
    assign rnd_round  = (state == S_ROUND) ? 32'(round_q) : 32'(SHARES-1);

    generate
        for (genvar j = 0; j < SHARES-1; j++) begin : g_rng
            logic [H_WIDTH-1:0] prng_in, raw;

            assign prng_in = u_for_rand
                           ^ H_WIDTH'(rnd_round * 32'h9E3 + 32'(j) * 32'h5A5)
                           ^ nonce_q;

            PRNG #(
                .WIDTH(H_WIDTH),
                .SEED (32'hDEAD_BEEF ^ (32'h9E37_79B9 * (j + 1)))
            ) u_prng (
                .address (prng_in),
                .rand_out(raw)
            );

            // Zq mode needs r < Q
            assign r[j] = (!A2B && raw >= H_WIDTH'(Q)) ? raw - H_WIDTH'(Q) : raw;
        end
    endgenerate

    // Refresh (shared by rounds and final step)
    logic [SHARES-1:0][H_WIDTH-1:0] t_in, t_out;
    assign t_in = src_rdata;

    Refresh #(
        .H_WIDTH(H_WIDTH),
        .SHARES (SHARES),
        .Q      (Q),
        .H_MODE (H_MODE)
    ) u_refresh (
        .x(t_in),
        .r(r),
        .y(t_out)
    );

    // Bank port muxing
    assign wdata = (state == S_INIT) ? init_data : DATA_W'(t_out);

    always_comb begin
        addr0 = '0;  addr1 = '0;
        we0   = 1'b0; we1  = 1'b0;

        unique case (state)
            S_INIT: begin
                addr0 = cnt[H_WIDTH-1:0];
                we0   = 1'b1;
            end
            S_ROUND: begin
                if (!src_sel) begin
                    addr0 = rd_addr;
                    addr1 = wr_addr;  we1 = wr_en_round;
                end else begin
                    addr1 = rd_addr;
                    addr0 = wr_addr;  we0 = wr_en_round;
                end
            end
            S_FINAL_RD,
            S_FINAL_WAIT: begin
                if (!src_sel) addr0 = rd_addr;
                else          addr1 = rd_addr;
            end
            default: ;
        endcase
    end

    // Control FSM
    assign busy = (state != S_IDLE);

    always_ff @(posedge CLK or negedge RSTN) begin
        if (!RSTN) begin
            state   <= S_IDLE;
            cnt     <= '0;
            round_q <= '0;
            src_sel <= 1'b0;
            nonce_q <= '0;
            x_q     <= '0;
            y       <= '0;
            done    <= 1'b0;
        end else begin
            done    <= 1'b0;
            nonce_q <= nonce_q + H_WIDTH'(1);   // free-running, see notes

            unique case (state)
                S_IDLE: begin
                    if (start) begin
                        x_q     <= x;
                        cnt     <= '0;
                        round_q <= '0;
                        src_sel <= 1'b0;
                        state   <= S_INIT;
                    end
                end

                S_INIT: begin
                    if (cnt == CNT_W'(DOMAIN-1)) begin
                        cnt   <= '0;
                        state <= S_ROUND;
                    end else
                        cnt <= cnt + 1'b1;
                end

                S_ROUND: begin
                    if (cnt == CNT_W'(DOMAIN)) begin     // last write done
                        cnt     <= '0;
                        src_sel <= ~src_sel;
                        if (round_q == RW'(SHARES-2))
                            state <= S_FINAL_RD;
                        else
                            round_q <= round_q + 1'b1;
                    end else
                        cnt <= cnt + 1'b1;
                end

                S_FINAL_RD:   state <= S_FINAL_WAIT;

                S_FINAL_WAIT: begin
                    y     <= t_out;
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule