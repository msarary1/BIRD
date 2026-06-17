`ifndef BIRD_REMOTE_TEST_SV
`define BIRD_REMOTE_TEST_SV

class bird_remote_test;

  bird_env env;

  function new(bird_env env);
    this.env = env;
  endfunction

  task run();
    bird_remote_seq remote_seq;

    $display("[TEST] Starting bird_remote_test at %0t", $time);

    remote_seq = new(env.agent.drv_mbx);
    remote_seq.body();

    repeat (240) @(env.vif.mon_cb);

    env.report();

    $display("[TEST] Finished bird_remote_test at %0t", $time);
  endtask

endclass

`endif
