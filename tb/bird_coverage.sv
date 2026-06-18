`ifndef BIRD_COVERAGE_SV
`define BIRD_COVERAGE_SV

class bird_coverage;

  virtual bird_if vif;

  int unsigned input_sample_count;
  int unsigned local_sample_count;
  int unsigned remote_sample_count;
  int unsigned drop_sample_count;
  int unsigned handshake_sample_count;

  // Used to sample cfg-based coverage only once per input fragment,
  // not once for every payload/CRC byte.
  int unsigned input_bytes_left;
  int unsigned drop_reason_bytes_left;

  // Small state model for remote SEQ mismatch coverage.
  bit         cov_remote_active;
  logic [4:0] cov_active_seq;


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


  // Tracks valid drop conditions from the official spec.
  // Removed local_seq_not_one because local SEQ_NUM has no functional impact.
  covergroup cg_drop_reason with function sample(
    bit seq_zero,
    bit frag_zero,
    bit len_zero,
    bit reserved_nonzero,
    bit local_frag_not_one,
    bit remote_mismatch_seq
  );
    option.per_instance = 1;

    cp_seq_zero: coverpoint seq_zero {
      bins hit    = {1};
      bins no_hit = {0};
    }

    cp_frag_zero: coverpoint frag_zero {
      bins hit    = {1};
      bins no_hit = {0};
    }

    cp_len_zero: coverpoint len_zero {
      bins hit    = {1};
      bins no_hit = {0};
    }

    cp_reserved: coverpoint reserved_nonzero {
      bins hit    = {1};
      bins no_hit = {0};
    }

    cp_local_frag_bad: coverpoint local_frag_not_one {
      bins hit    = {1};
      bins no_hit = {0};
    }

    cp_remote_mismatch: coverpoint remote_mismatch_seq {
      bins hit    = {1};
      bins no_hit = {0};
    }
  endgroup


  function new(virtual bird_if vif);
    this.vif = vif;

    input_sample_count      = 0;
    local_sample_count      = 0;
    remote_sample_count     = 0;
    drop_sample_count       = 0;
    handshake_sample_count  = 0;

    input_bytes_left        = 0;
    drop_reason_bytes_left  = 0;

    clear_cov_remote_state();

    cg_input       = new();
    cg_output      = new();
    cg_drop        = new();
    cg_handshake   = new();
    cg_drop_reason = new();
  endfunction


  function void clear_cov_remote_state();
    cov_remote_active = 0;
    cov_active_seq    = 5'd0;
  endfunction


  task run();
    fork
      sample_input();
      sample_outputs();
      sample_drop_counter();
      sample_handshakes();
      sample_drop_reasons();
    join_none
  endtask


  task sample_input();
    forever begin
      @(vif.mon_cb);

      if (!vif.mon_cb.rst_n) begin
        input_bytes_left = 0;
      end
      else if (vif.mon_cb.in_vld && vif.mon_cb.in_rdy) begin

        // First byte of a fragment: sample cfg once.
        if (input_bytes_left == 0) begin
          input_sample_count++;

          cg_input.sample(
            vif.mon_cb.cfg[0],
            vif.mon_cb.cfg[15:8],
            vif.mon_cb.cfg[20:16],
            vif.mon_cb.cfg[28:24]
          );

          // Payload bytes + 2 CRC bytes.
          input_bytes_left = vif.mon_cb.cfg[15:8] + 2;
        end

        if (input_bytes_left > 0) begin
          input_bytes_left--;
        end
      end
    end
  endtask


  task sample_outputs();
    bit local_transfer;
    bit remote_transfer;

    forever begin
      @(vif.mon_cb);

      if (vif.mon_cb.rst_n) begin
        local_transfer  = vif.mon_cb.local_vld  && vif.mon_cb.local_rdy;
        remote_transfer = vif.mon_cb.remote_vld && vif.mon_cb.remote_rdy;

        if (local_transfer) begin
          local_sample_count++;
        end

        if (remote_transfer) begin
          remote_sample_count++;
        end

        // Sample every cycle so no-transfer bins can also be covered.
        cg_output.sample(local_transfer, remote_transfer);
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


  task sample_drop_reasons();
    logic [31:0] c;

    bit is_remote;
    bit seq_zero;
    bit frag_zero;
    bit len_zero;
    bit reserved_nonzero;
    bit local_frag_not_one;
    bit remote_mismatch_seq;
    bit basic_invalid;

    forever begin
      @(vif.mon_cb);

      if (!vif.mon_cb.rst_n) begin
        drop_reason_bytes_left = 0;
        clear_cov_remote_state();
      end
      else if (vif.mon_cb.in_vld && vif.mon_cb.in_rdy) begin

        // First byte of a fragment: evaluate cfg once.
        if (drop_reason_bytes_left == 0) begin
          c = vif.mon_cb.cfg;

          is_remote          = c[0];
          seq_zero           = (c[28:24] == 5'd0);
          frag_zero          = (c[20:16] == 5'd0);
          len_zero           = (c[15:8]  == 8'd0);
          reserved_nonzero   = (c[7:1]   != 7'd0) ||
                               (c[23:21] != 3'd0) ||
                               (c[31:29] != 3'd0);
          local_frag_not_one = (c[0] == 1'b0 && c[20:16] != 5'd1);

          basic_invalid = seq_zero ||
                          frag_zero ||
                          len_zero ||
                          reserved_nonzero ||
                          local_frag_not_one;

          remote_mismatch_seq = 1'b0;

          // Correct remote mismatch logic:
          // A remote fragment has a different SEQ_NUM while another
          // remote packet is being accumulated.
          if (is_remote && !basic_invalid) begin
            if (cov_remote_active && (c[28:24] != cov_active_seq)) begin
              remote_mismatch_seq = 1'b1;
            end
          end

          cg_drop_reason.sample(
            seq_zero,
            frag_zero,
            len_zero,
            reserved_nonzero,
            local_frag_not_one,
            remote_mismatch_seq
          );

          // Update simple remote accumulation state for future mismatch detection.
          if (basic_invalid || remote_mismatch_seq) begin
            if (is_remote || cov_remote_active) begin
              clear_cov_remote_state();
            end
          end
          else if (is_remote) begin
            if (!cov_remote_active) begin
              cov_remote_active = 1'b1;
              cov_active_seq    = c[28:24];
            end
          end

          // Payload bytes + 2 CRC bytes.
          drop_reason_bytes_left = c[15:8] + 2;
        end

        if (drop_reason_bytes_left > 0) begin
          drop_reason_bytes_left--;
        end
      end
    end
  endtask


  function void report();
    real total_cov;

    total_cov = (cg_input.get_coverage()
              + cg_output.get_coverage()
              + cg_drop.get_coverage()
              + cg_handshake.get_coverage()
              + cg_drop_reason.get_coverage()) / 5.0;

    $display("");
    $display("================ BIRD FUNCTIONAL COVERAGE REPORT ================");
    $display("Input samples              : %0d", input_sample_count);
    $display("Local samples              : %0d", local_sample_count);
    $display("Remote samples             : %0d", remote_sample_count);
    $display("Drop samples               : %0d", drop_sample_count);
    $display("Handshake samples          : %0d", handshake_sample_count);
    $display("cg_input coverage          = %0.2f%%", cg_input.get_coverage());
    $display("cg_output coverage         = %0.2f%%", cg_output.get_coverage());
    $display("cg_drop coverage           = %0.2f%%", cg_drop.get_coverage());
    $display("cg_handshake coverage      = %0.2f%%", cg_handshake.get_coverage());
    $display("cg_drop_reason coverage    = %0.2f%%", cg_drop_reason.get_coverage());
    $display("Total functional cov       = %0.2f%%", total_cov);
    $display("==================================================================");
    $display("");
  endfunction

endclass

`endif