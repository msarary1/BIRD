`ifndef BIRD_BACKPRESSURE_TEST_SV
`define BIRD_BACKPRESSURE_TEST_SV

class bird_backpressure_test;

  bird_env env;

  function new(bird_env env);
    this.env = env;
  endfunction

  task run();
    bird_local_seq        local_seq;
    bird_backpressure_seq bp_seq;

    $display("[TEST] Starting bird_backpressure_test at %0t", $time);

    local_seq = new(env.agent.drv_mbx);
    bp_seq    = new(env.vif);

    fork
      local_seq.body(3);
      bp_seq.body(80);
    join

    repeat (150) @(env.vif.mon_cb);

    env.report();

    $display("[TEST] Finished bird_backpressure_test at %0t", $time);
  endtask

endclass

`endif
