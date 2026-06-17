`ifndef BIRD_LOCAL_TEST_SV
`define BIRD_LOCAL_TEST_SV

class bird_local_test;

  bird_env env;

  function new(bird_env env);
    this.env = env;
  endfunction

  task run();
    bird_local_seq local_seq;

    $display("[TEST] Starting bird_local_test at %0t", $time);

    local_seq = new(env.agent.drv_mbx);
    local_seq.body(3);

    repeat (150) @(env.vif.mon_cb);

    env.report();

    $display("[TEST] Finished bird_local_test at %0t", $time);
  endtask

endclass

`endif
