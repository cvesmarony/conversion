// Top Module
// Weston Nguyen

`timescale 1ns/1ps
`include "groups.sv"
import groups::*;

module top (
    input  logic        clk,
    input  logic        rst
);

    ram #(
        .G_SIZE(G_SIZE),
        .N(N),
        .W(W)
    ) T_RAM (
        .clk(clk),
        .we(t_we),
        .wr_addr(t_wr_addr),
        .wr_data(t_wr_data),
        .rd_addr(t_rd_addr),
        .rd_data(t_rd_data)
    );

    ram #(
        .G_SIZE(G_SIZE),
        .N(N),
        .W(W)
    ) TP_RAM (
        .clk(clk),
        .we(tp_we),
        .wr_addr(tp_wr_addr),
        .wr_data(tp_wr_data),
        .rd_addr(tp_rd_addr),
        .rd_data(tp_rd_data)
    );

    Refresh #(
        .G_
    ) Refresh_H (
        .x(),
        .r(),
        .y()
    );

    Refresh #(
        .G_
    ) Refresh_Zq (
        .x(),
        .r(),
        .y()
    );

    typedef enum logic {
        GROUP_BOOLEAN,
        GROUP_ZQ
    } group_mode_t;

endmodule
