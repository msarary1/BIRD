`ifndef BIRD_RESET_TEST_SV
`define BIRD_RESET_TEST_SV

class bird_reset_test;

  bird_env env;

  function new(bird_env env);
    this.env = env;
  endfunction

  task run();
    bird_local_seq local_seq;
    bird_reset_seq reset_seq;

    $display("[TEST] Starting bird_reset_test at %0t", $time);

    local_seq = new(env.agent.drv_mbx);
    reset_seq = new(env.vif);

    $display("[TEST] Send packet before reset");
    local_seq.body(1);

    repeat (40) @(env.vif.mon_cb);

    reset_seq.apply_reset(5);

    $display("[TEST] Send packet after reset");
    local_seq.body(1);

    repeat (100) @(env.vif.mon_cb);

    env.report();

    $display("[TEST] Finished bird_reset_test at %0t", $time);
  endtask

endclass

`endif
