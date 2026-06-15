`ifndef BIRD_ENV_SV
`define BIRD_ENV_SV

class bird_env;

  virtual bird_if vif;

  mailbox #(bird_input_fragment) in_obs_mbx;
  mailbox #(bird_output_item)    local_mbx;
  mailbox #(bird_output_item)    remote_mbx;

  bird_agent      agent;
  bird_scoreboard scoreboard;

  function new(virtual bird_if vif);
    this.vif = vif;

    in_obs_mbx = new();
    local_mbx  = new();
    remote_mbx = new();

    agent = new(vif, in_obs_mbx, local_mbx, remote_mbx);
    scoreboard = new(in_obs_mbx, local_mbx, remote_mbx);
  endfunction

  task start();
    agent.start();
    scoreboard.run();
  endtask

  task report();
    scoreboard.report();
  endtask

endclass

`endif

