`timescale 1ns/1ps

module bird_tb_top;

  import bird_pkg::*;

  logic clk;

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

  bird_env env;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    bird_vif.rst_n      = 1'b0;
    bird_vif.in_vld     = 1'b0;
    bird_vif.data_in    = 8'h00;
    bird_vif.cfg        = 32'h0000_0000;
    bird_vif.local_rdy  = 1'b1;
    bird_vif.remote_rdy = 1'b1;

    repeat (5) @(posedge clk);
    bird_vif.rst_n = 1'b1;

    $display("[TOP] Reset deasserted at time %0t", $time);
  end

  initial begin
    env = new(bird_vif);
    env.start();
  end

  initial begin
    string testname;

    wait (bird_vif.rst_n === 1'b1);
    repeat (2) @(posedge clk);

    if (!$value$plusargs("TEST=%s", testname)) begin
      testname = "smoke";
    end

    $display("[TOP] Selected TEST = %s", testname);

    if (testname == "smoke") begin
      bird_smoke_test t;
      t = new(env);
      t.run();
    end
    else if (testname == "local") begin
      bird_local_test t;
      t = new(env);
      t.run();
    end
    else if (testname == "remote") begin
      bird_remote_test t;
      t = new(env);
      t.run();
    end
    else if (testname == "remote_oo") begin
      bird_remote_oo_test t;
      t = new(env);
      t.run();
    end
    else if (testname == "invalid") begin
      bird_invalid_drop_test t;
      t = new(env);
      t.run();
    end
    else if (testname == "backpressure") begin
      bird_backpressure_test t;
      t = new(env);
      t.run();
    end
    else if (testname == "reset") begin
      bird_reset_test t;
      t = new(env);
      t.run();
    end
    else begin
      $error("[TOP] Unknown TEST=%s", testname);
    end

    #100;
    $finish;
  end

endmodule
