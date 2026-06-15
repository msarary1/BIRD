`ifndef BIRD_INVALID_DROP_TEST_SV
`define BIRD_INVALID_DROP_TEST_SV

class bird_invalid_drop_test;

  bird_env env;

  function new(bird_env env);
    this.env = env;
  endfunction

  task run();
    bird_invalid_seq invalid_seq;

    $display("[TEST] Starting bird_invalid_drop_test at %0t", $time);

    invalid_seq = new(env.agent.drv_mbx);
    invalid_seq.body();

    repeat (150) @(env.vif.mon_cb);

    env.report();

    $display("[TEST] Finished bird_invalid_drop_test at %0t", $time);
  endtask

endclass

`endif
