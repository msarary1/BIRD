
interface bird_if(input logic clk);

  logic        rst_n;

  // Input interface
  logic        in_vld;
  logic        in_rdy;
  logic [7:0]  data_in;
  logic [31:0] cfg;

  // Status output
  logic [15:0] drop_cnt;

  // Local output interface
  logic        local_vld;
  logic        local_rdy;
  logic [7:0]  data_local;

  // Remote output interface
  logic        remote_vld;
  logic        remote_rdy;
  logic [31:0] data_remote;

  // Driver clocking block
  clocking drv_cb @(posedge clk);
    default input #1step output #0;

    output rst_n;
    output in_vld;
    output data_in;
    output cfg;
    output local_rdy;
    output remote_rdy;

    input  in_rdy;
    input  local_vld;
    input  data_local;
    input  remote_vld;
    input  data_remote;
    input  drop_cnt;
  endclocking

  // Monitor clocking block
  clocking mon_cb @(posedge clk);
    default input #1step output #0;

    input rst_n;
    input in_vld;
    input in_rdy;
    input data_in;
    input cfg;

    input local_vld;
    input local_rdy;
    input data_local;

    input remote_vld;
    input remote_rdy;
    input data_remote;

    input drop_cnt;
  endclocking

  modport dut_mp (
    input  clk,
    input  rst_n,
    input  in_vld,
    output in_rdy,
    input  data_in,
    input  cfg,
    output drop_cnt,
    output local_vld,
    input  local_rdy,
    output data_local,
    output remote_vld,
    input  remote_rdy,
    output data_remote
  );

  modport tb_mp (
    clocking drv_cb,
    clocking mon_cb,
    input clk
  );

endinterface
