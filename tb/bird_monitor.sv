`ifndef BIRD_MONITOR_SV
`define BIRD_MONITOR_SV

class bird_input_monitor;

  virtual bird_if vif;
  mailbox #(bird_input_fragment) in_obs_mbx;

  function new(virtual bird_if vif,
               mailbox #(bird_input_fragment) in_obs_mbx);
    this.vif = vif;
    this.in_obs_mbx = in_obs_mbx;
  endfunction

  task run();
    bird_input_fragment cur;
    int unsigned bytes_left;

    cur = null;
    bytes_left = 0;

    forever begin
      @(vif.mon_cb);

      if (!vif.mon_cb.rst_n) begin
        cur = null;
        bytes_left = 0;
      end else if (vif.mon_cb.in_vld && vif.mon_cb.in_rdy) begin

        if (bytes_left == 0) begin
          cur = new();
          cur.cfg = vif.mon_cb.cfg;
          cur.decode_cfg();
          cur.start_time = $time;

          // payload + 2 CRC bytes
          bytes_left = cur.payload_len + 2;
        end

        cur.stream.push_back(vif.mon_cb.data_in);

        if (bytes_left > 0) begin
          bytes_left--;
        end

        if (bytes_left == 0) begin
          cur.end_time = $time;
          cur.finalize();
          cur.display("[IN_MON] ");
          in_obs_mbx.put(cur);
          cur = null;
        end
      end
    end
  endtask

endclass


class bird_local_monitor;

  virtual bird_if vif;
  mailbox #(bird_output_item) local_mbx;

  function new(virtual bird_if vif,
               mailbox #(bird_output_item) local_mbx);
    this.vif = vif;
    this.local_mbx = local_mbx;
  endfunction

  task run();
    bird_output_item item;

    forever begin
      @(vif.mon_cb);

      if (vif.mon_cb.rst_n &&
          vif.mon_cb.local_vld &&
          vif.mon_cb.local_rdy) begin

        item = new(BIRD_OUT_LOCAL);
        item.data_byte = vif.mon_cb.data_local;
        item.drop_cnt = vif.mon_cb.drop_cnt;
        item.sample_time = $time;

        item.display("[LOCAL_MON] ");
        local_mbx.put(item);
      end
    end
  endtask

endclass


class bird_remote_monitor;

  virtual bird_if vif;
  mailbox #(bird_output_item) remote_mbx;

  function new(virtual bird_if vif,
               mailbox #(bird_output_item) remote_mbx);
    this.vif = vif;
    this.remote_mbx = remote_mbx;
  endfunction

  task run();
    bird_output_item item;

    forever begin
      @(vif.mon_cb);

      if (vif.mon_cb.rst_n &&
          vif.mon_cb.remote_vld &&
          vif.mon_cb.remote_rdy) begin

        item = new(BIRD_OUT_REMOTE);
        item.data_word = vif.mon_cb.data_remote;
        item.drop_cnt = vif.mon_cb.drop_cnt;
        item.sample_time = $time;

        item.display("[REMOTE_MON] ");
        remote_mbx.put(item);
      end
    end
  endtask

endclass

`endif
