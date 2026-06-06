import uvm_pkg::*;
`include "uvm_macros.svh"
import bird_pkg::*;

module bird_tb_top;

  logic clk;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  bird_if bird_vif(clk);

  bird dut (
    .clk         (clk),
    .rst_n       (bird_vif.rst_n),

    .in_vld      (bird_vif.in_vld),
    .in_rdy      (bird_vif.in_rdy),
    .data_in     (bird_vif.data_in),
    .cfg         (bird_vif.cfg),

    .drop_cnt    (bird_vif.drop_cnt),

    .local_vld   (bird_vif.local_vld),
    .local_rdy   (bird_vif.local_rdy),
    .data_local  (bird_vif.data_local),

    .remote_vld  (bird_vif.remote_vld),
    .remote_rdy  (bird_vif.remote_rdy),
    .data_remote (bird_vif.data_remote)
  );

  initial begin
    uvm_config_db#(virtual bird_if)::set(null, "uvm_test_top", "vif", bird_vif);
    run_test("bird_base_test");
  end

  initial begin
    $dumpfile("bird_tb.vcd");
    $dumpvars(0, bird_tb_top);
  end

endmodule
