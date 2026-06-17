`ifndef BIRD_COVERAGE_SV
`define BIRD_COVERAGE_SV

class bird_coverage;

  virtual bird_if vif;

  int unsigned input_sample_count;
  int unsigned local_sample_count;
  int unsigned remote_sample_count;
  int unsigned drop_sample_count;
  int unsigned handshake_sample_count;

  covergroup cg_input with function sample(
    bit remote,
    int unsigned len,
    int unsigned frag,
    int unsigned seq
  );
    option.per_instance = 1;

    cp_remote: coverpoint remote {
      bins local_pkt  = {0};
      bins remote_pkt = {1};
    }

    cp_len: coverpoint len {
      bins len_zero  = {0};
      bins len_one   = {1};
      bins len_small = {[2:15]};
      bins len_mid   = {[16:127]};
      bins len_large = {[128:255]};
    }

    cp_frag: coverpoint frag {
      bins frag_zero = {0};
      bins frag_one  = {1};
      bins frag_mid  = {[2:15]};
      bins frag_high = {[16:31]};
    }

    cp_seq: coverpoint seq {
      bins seq_zero = {0};
      bins seq_one  = {1};
      bins seq_mid  = {[2:15]};
      bins seq_high = {[16:31]};
    }

    cross_remote_len  : cross cp_remote, cp_len;
    cross_remote_frag : cross cp_remote, cp_frag;
  endgroup

  covergroup cg_output with function sample(
    bit local_transfer,
    bit remote_transfer
  );
    option.per_instance = 1;

    cp_local_transfer: coverpoint local_transfer {
      bins no_local  = {0};
      bins has_local = {1};
    }

    cp_remote_transfer: coverpoint remote_transfer {
      bins no_remote  = {0};
      bins has_remote = {1};
    }

    cross_outputs: cross cp_local_transfer, cp_remote_transfer;
  endgroup

  covergroup cg_drop with function sample(bit [15:0] drop_cnt);
    option.per_instance = 1;

    cp_drop_cnt: coverpoint drop_cnt {
      bins zero_drop = {16'd0};
      bins low_drop  = {[16'd1:16'd5]};
      bins mid_drop  = {[16'd6:16'd100]};
      bins high_drop = {[16'd101:16'hFFFF]};
    }
  endgroup

  covergroup cg_handshake with function sample(
    bit in_vld,
    bit in_rdy,
    bit local_vld,
    bit local_rdy,
    bit remote_vld,
    bit remote_rdy
  );
    option.per_instance = 1;

    cp_input_hs: coverpoint {in_vld, in_rdy} {
      bins idle       = {2'b00};
      bins ready_only = {2'b01};
      bins wait_ready = {2'b10};
      bins transfer   = {2'b11};
    }

    cp_local_hs: coverpoint {local_vld, local_rdy} {
      bins idle       = {2'b00};
      bins ready_only = {2'b01};
      bins wait_ready = {2'b10};
      bins transfer   = {2'b11};
    }

    cp_remote_hs: coverpoint {remote_vld, remote_rdy} {
      bins idle       = {2'b00};
      bins ready_only = {2'b01};
      bins wait_ready = {2'b10};
      bins transfer   = {2'b11};
    }
  endgroup

  function new(virtual bird_if vif);
    this.vif = vif;

    input_sample_count = 0;
    local_sample_count = 0;
    remote_sample_count = 0;
    drop_sample_count = 0;
    handshake_sample_count = 0;

    cg_input = new();
    cg_output = new();
    cg_drop = new();
    cg_handshake = new();
  endfunction

  task run();
    fork
      sample_input();
      sample_outputs();
      sample_drop_counter();
      sample_handshakes();
    join_none
  endtask

  task sample_input();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rst_n && vif.mon_cb.in_vld && vif.mon_cb.in_rdy) begin
        input_sample_count++;
        cg_input.sample(
          vif.mon_cb.cfg[0],
          vif.mon_cb.cfg[15:8],
          vif.mon_cb.cfg[20:16],
          vif.mon_cb.cfg[28:24]
        );
      end
    end
  endtask

  task sample_outputs();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rst_n) begin
        if (vif.mon_cb.local_vld && vif.mon_cb.local_rdy) begin
          local_sample_count++;
          cg_output.sample(1'b1, 1'b0);
        end

        if (vif.mon_cb.remote_vld && vif.mon_cb.remote_rdy) begin
          remote_sample_count++;
          cg_output.sample(1'b0, 1'b1);
        end
      end
    end
  endtask

  task sample_drop_counter();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rst_n) begin
        drop_sample_count++;
        cg_drop.sample(vif.mon_cb.drop_cnt);
      end
    end
  endtask

  task sample_handshakes();
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rst_n) begin
        handshake_sample_count++;
        cg_handshake.sample(
          vif.mon_cb.in_vld,
          vif.mon_cb.in_rdy,
          vif.mon_cb.local_vld,
          vif.mon_cb.local_rdy,
          vif.mon_cb.remote_vld,
          vif.mon_cb.remote_rdy
        );
      end
    end
  endtask

  function void report();
    $display("");
    $display("================ BIRD FUNCTIONAL COVERAGE REPORT ================");
    $display("Input samples          : %0d", input_sample_count);
    $display("Local samples          : %0d", local_sample_count);
    $display("Remote samples         : %0d", remote_sample_count);
    $display("Drop samples           : %0d", drop_sample_count);
    $display("Handshake samples      : %0d", handshake_sample_count);
    $display("cg_input coverage      = %0.2f%%", cg_input.get_coverage());
    $display("cg_output coverage     = %0.2f%%", cg_output.get_coverage());
    $display("cg_drop coverage       = %0.2f%%", cg_drop.get_coverage());
    $display("cg_handshake coverage  = %0.2f%%", cg_handshake.get_coverage());
    $display("Total functional cov   = %0.2f%%",
             (cg_input.get_coverage()
            + cg_output.get_coverage()
            + cg_drop.get_coverage()
            + cg_handshake.get_coverage()) / 4.0);
    $display("==================================================================");
    $display("");
  endfunction

endclass

`endif