`ifndef BIRD_PROTOCOL_CHECKER_SV
`define BIRD_PROTOCOL_CHECKER_SV

class bird_protocol_checker;

  virtual bird_if vif;

  int unsigned error_count;
  int unsigned input_stability_checks;
  int unsigned local_stability_checks;
  int unsigned remote_stability_checks;

  bit prev_in_hold;
  bit prev_local_hold;
  bit prev_remote_hold;

  logic [7:0]  prev_data_in;
  logic [31:0] prev_cfg;

  logic [7:0]  prev_data_local;
  logic [31:0] prev_data_remote;

  function new(virtual bird_if vif);
    this.vif = vif;

    error_count = 0;
    input_stability_checks = 0;
    local_stability_checks = 0;
    remote_stability_checks = 0;

    prev_in_hold = 0;
    prev_local_hold = 0;
    prev_remote_hold = 0;

    prev_data_in = 8'h00;
    prev_cfg = 32'h0000_0000;
    prev_data_local = 8'h00;
    prev_data_remote = 32'h0000_0000;
  endfunction

  task run();
    forever begin
      @(vif.mon_cb);

      if (!vif.mon_cb.rst_n) begin
        prev_in_hold = 0;
        prev_local_hold = 0;
        prev_remote_hold = 0;
      end
      else begin
        check_input_stability();
        check_local_stability();
        check_remote_stability();

        prev_in_hold     = (vif.mon_cb.in_vld     && !vif.mon_cb.in_rdy);
        prev_local_hold  = (vif.mon_cb.local_vld  && !vif.mon_cb.local_rdy);
        prev_remote_hold = (vif.mon_cb.remote_vld && !vif.mon_cb.remote_rdy);

        prev_data_in     = vif.mon_cb.data_in;
        prev_cfg         = vif.mon_cb.cfg;
        prev_data_local  = vif.mon_cb.data_local;
        prev_data_remote = vif.mon_cb.data_remote;
      end
    end
  endtask

  function void checker_error(string msg);
    error_count++;
    $error("[PROTOCOL_CHECKER][ERROR] %s", msg);
  endfunction

  function void check_input_stability();
    if (prev_in_hold) begin
      input_stability_checks++;

      if (vif.mon_cb.in_vld !== 1'b1) begin
        checker_error("Input in_vld changed while previous cycle had in_vld=1 and in_rdy=0");
      end

      if (vif.mon_cb.data_in !== prev_data_in) begin
        checker_error($sformatf("Input data_in changed under backpressure. Previous=0x%02h Current=0x%02h",
                                prev_data_in, vif.mon_cb.data_in));
      end

      if (vif.mon_cb.cfg !== prev_cfg) begin
        checker_error($sformatf("Input cfg changed under backpressure. Previous=0x%08h Current=0x%08h",
                                prev_cfg, vif.mon_cb.cfg));
      end
    end
  endfunction

  function void check_local_stability();
    if (prev_local_hold) begin
      local_stability_checks++;

      if (vif.mon_cb.local_vld !== 1'b1) begin
        checker_error("local_vld changed while previous cycle had local_vld=1 and local_rdy=0");
      end

      if (vif.mon_cb.data_local !== prev_data_local) begin
        checker_error($sformatf("data_local changed under backpressure. Previous=0x%02h Current=0x%02h",
                                prev_data_local, vif.mon_cb.data_local));
      end
    end
  endfunction

  function void check_remote_stability();
    if (prev_remote_hold) begin
      remote_stability_checks++;

      if (vif.mon_cb.remote_vld !== 1'b1) begin
        checker_error("remote_vld changed while previous cycle had remote_vld=1 and remote_rdy=0");
      end

      if (vif.mon_cb.data_remote !== prev_data_remote) begin
        checker_error($sformatf("data_remote changed under backpressure. Previous=0x%08h Current=0x%08h",
                                prev_data_remote, vif.mon_cb.data_remote));
      end
    end
  endfunction

  function void report();
    $display("");
    $display("================ BIRD PROTOCOL CHECKER REPORT ================");
    $display("Input stability checks  : %0d", input_stability_checks);
    $display("Local stability checks  : %0d", local_stability_checks);
    $display("Remote stability checks : %0d", remote_stability_checks);
    $display("Protocol checker errors : %0d", error_count);

    if (error_count == 0) begin
      $display("PROTOCOL CHECKER RESULT : PASS");
    end
    else begin
      $display("PROTOCOL CHECKER RESULT : FAIL");
    end

    $display("==============================================================");
    $display("");
  endfunction

endclass

`endif
