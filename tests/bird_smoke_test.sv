`ifndef BIRD_SMOKE_TEST_SV
`define BIRD_SMOKE_TEST_SV

class bird_smoke_test;

  bird_env env;

  function new(bird_env env);
    this.env = env;
  endfunction

  task run();
    bird_transaction tr;
    u8_t p[];

    $display("[TEST] Starting BIRD smoke test at %0t", $time);

    p = new[4];
    p[0] = 8'h11;
    p[1] = 8'h22;
    p[2] = 8'h33;
    p[3] = 8'h44;

    tr = new("local_smoke_packet");
    tr.is_remote = 1'b0;
    tr.frag_num  = 1;
    tr.seq_num   = 1;
    tr.set_payload(p);

    env.agent.drv_mbx.put(tr);

    repeat (120) @(env.vif.mon_cb);

    env.report();

    $display("[TEST] Finished smoke test at %0t", $time);
  endtask

endclass

`endif
