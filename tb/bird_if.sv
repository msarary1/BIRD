`ifndef BIRD_IF_SV
`define BIRD_IF_SV

`timescale 1ns/1ps

interface bird_if(input logic clk);

  // Global signals
  logic rst_n;

  // Input interface
  logic        in_vld;
  logic        in_rdy;
  logic [7:0]  data_in;
  logic [31:0] cfg;

  // Status output
  logic [15:0] drop_cnt;

  // Local output interface
  logic       local_vld;
  logic       local_rdy;
  logic [7:0] data_local;

  // Remote output interface
  logic        remote_vld;
  logic        remote_rdy;
  logic [31:0] data_remote;

  // Driver clocking block
  // The driver drives on negedge so the DUT sees stable signals at posedge.
  clocking drv_cb @(negedge clk);
    default input #1step output #0;

    output in_vld;
    output data_in;
    output cfg;
    output local_rdy;
    output remote_rdy;

    input in_rdy;
    input local_vld;
    input data_local;
    input remote_vld;
    input data_remote;
    input drop_cnt;
    input rst_n;
  endclocking

  // Monitor clocking block
  // The monitor samples on posedge because the DUT is rising-edge triggered.
  clocking mon_cb @(posedge clk);
    default input #1step output #0;

    input rst_n;
    input in_vld;
    input in_rdy;
    input data_in;
    input cfg;
    input drop_cnt;

    input local_vld;
    input local_rdy;
    input data_local;

    input remote_vld;
    input remote_rdy;
    input data_remote;
  endclocking

endinterface

`endif
