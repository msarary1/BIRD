`ifndef BIRD_AGENT_SV
`define BIRD_AGENT_SV

class bird_agent;

  virtual bird_if vif;

  mailbox #(bird_transaction)    drv_mbx;
  mailbox #(bird_input_fragment) in_obs_mbx;
  mailbox #(bird_output_item)    local_mbx;
  mailbox #(bird_output_item)    remote_mbx;

  bird_driver        driver;
  bird_input_monitor input_monitor;
  bird_local_monitor local_monitor;
  bird_remote_monitor remote_monitor;

  function new(virtual bird_if vif,
               mailbox #(bird_input_fragment) in_obs_mbx,
               mailbox #(bird_output_item)    local_mbx,
               mailbox #(bird_output_item)    remote_mbx);

    this.vif = vif;
    this.in_obs_mbx = in_obs_mbx;
    this.local_mbx = local_mbx;
    this.remote_mbx = remote_mbx;

    drv_mbx = new();

    driver = new(vif, drv_mbx);
    input_monitor = new(vif, in_obs_mbx);
    local_monitor = new(vif, local_mbx);
    remote_monitor = new(vif, remote_mbx);
  endfunction

  task start();
    fork
      driver.run();
      input_monitor.run();
      local_monitor.run();
      remote_monitor.run();
    join_none
  endtask

endclass

`endif
