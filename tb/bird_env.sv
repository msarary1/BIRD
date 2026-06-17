`ifndef BIRD_ENV_SV
`define BIRD_ENV_SV

class bird_env;

  virtual bird_if vif;

  mailbox #(bird_input_fragment) in_obs_mbx;
  mailbox #(bird_output_item)    local_mbx;
  mailbox #(bird_output_item)    remote_mbx;

  bird_agent            agent;
  bird_scoreboard       scoreboard;
  bird_coverage         coverage;
  bird_protocol_checker protocol_checker;

  function new(virtual bird_if vif);
    this.vif = vif;

    in_obs_mbx = new();
    local_mbx  = new();
    remote_mbx = new();

    agent            = new(vif, in_obs_mbx, local_mbx, remote_mbx);
    scoreboard       = new(in_obs_mbx, local_mbx, remote_mbx, vif);
    coverage         = new(vif);
    protocol_checker = new(vif);
  endfunction

  task start();
    agent.start();
    scoreboard.run();
    coverage.run();
    protocol_checker.run();
  endtask

  task report();
    scoreboard.report();
    coverage.report();
    protocol_checker.report();
  endtask

endclass

`endif
