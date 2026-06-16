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

  string testname;

  bird_smoke_test        smoke_test;
  bird_local_test        local_test;
  bird_remote_test       remote_test;
  bird_invalid_drop_test invalid_drop_test;
  bird_backpressure_test backpressure_test;
  bird_reset_test        reset_test;

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
    if (!$value$plusargs("TEST=%s", testname)) begin
      testname = "smoke";
    end

    wait (bird_vif.rst_n === 1'b1);

    repeat (2) @(posedge clk);

    $display("[TOP] Selected TEST=%s", testname);

    case (testname)

      "smoke": begin
        smoke_test = new(env);
        smoke_test.run();
      end

      "local": begin
        local_test = new(env);
        local_test.run();
      end

      "remote": begin
        remote_test = new(env);
        remote_test.run();
      end

      "invalid": begin
        invalid_drop_test = new(env);
        invalid_drop_test.run();
      end

      "backpressure": begin
        backpressure_test = new(env);
        backpressure_test.run();
      end

      "reset": begin
        reset_test = new(env);
        reset_test.run();
      end

      default: begin
        $display("[TOP] Unknown TEST=%s", testname);
        $display("[TOP] Running smoke test instead.");
        smoke_test = new(env);
        smoke_test.run();
      end

    endcase

    #100;
    $finish;
  end

endmodule