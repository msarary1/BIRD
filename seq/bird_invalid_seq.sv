`ifndef BIRD_INVALID_SEQ_SV
`define BIRD_INVALID_SEQ_SV

class bird_invalid_seq;

  mailbox #(bird_transaction) drv_mbx;

  function new(mailbox #(bird_transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction

  task body();
    bird_transaction tr;
    u8_t p[];

    p = new[1];
    p[0] = 8'h55;

    // ------------------------------------------------------------
    // Invalid 1:
    // Local packet with bad FRAG_NUM.
    // Local traffic must have FRAG_NUM=1.
    // ------------------------------------------------------------
    tr = new("invalid_local_bad_frag");
    tr.is_remote = 1'b0;
    tr.seq_num   = 5'd1;
    tr.frag_num  = 5'd2;
    tr.set_payload(p);

    $display("[INVALID_SEQ] Sending invalid local packet with FRAG_NUM=2");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // ------------------------------------------------------------
    // Invalid 2:
    // Reserved bits are non-zero.
    // ------------------------------------------------------------
    tr = new("invalid_reserved_bits");
    tr.is_remote = 1'b0;
    tr.seq_num   = 5'd1;
    tr.frag_num  = 5'd1;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;

    tr.raw_cfg[0]      = 1'b0;        // local
    tr.raw_cfg[7:1]    = 7'b1111111;  // invalid reserved bits
    tr.raw_cfg[15:8]   = 8'd1;
    tr.raw_cfg[20:16]  = 5'd1;
    tr.raw_cfg[28:24]  = 5'd1;

    $display("[INVALID_SEQ] Sending invalid packet with reserved bits set");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // ------------------------------------------------------------
    // Invalid 3:
    // Remote packet with SEQ_NUM=0.
    // ------------------------------------------------------------
    tr = new("invalid_remote_seq_zero");
    tr.is_remote = 1'b1;
    tr.seq_num   = 5'd0;
    tr.frag_num  = 5'd1;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;

    tr.raw_cfg[0]      = 1'b1;   // remote
    tr.raw_cfg[15:8]   = 8'd1;
    tr.raw_cfg[20:16]  = 5'd1;
    tr.raw_cfg[28:24]  = 5'd0;   // invalid SEQ_NUM

    $display("[INVALID_SEQ] Sending invalid remote packet with SEQ_NUM=0");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // ------------------------------------------------------------
    // Invalid 4:
    // Remote packet with FRAG_NUM=0.
    // ------------------------------------------------------------
    tr = new("invalid_remote_frag_zero");
    tr.is_remote = 1'b1;
    tr.seq_num   = 5'd2;
    tr.frag_num  = 5'd0;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;

    tr.raw_cfg[0]      = 1'b1;   // remote
    tr.raw_cfg[15:8]   = 8'd1;
    tr.raw_cfg[20:16]  = 5'd0;   // invalid FRAG_NUM
    tr.raw_cfg[28:24]  = 5'd2;

    $display("[INVALID_SEQ] Sending invalid remote packet with FRAG_NUM=0");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // ------------------------------------------------------------
    // Invalid 5:
    // PAYLOAD_LEN=0.
    //
    // We still send one dummy byte plus CRC so the DUT/monitor do not
    // become misaligned. The cfg is invalid because cfg[15:8]=0.
    // ------------------------------------------------------------
    p[0] = 8'hCC;

    tr = new("invalid_payload_len_zero");
    tr.is_remote = 1'b0;
    tr.seq_num   = 5'd1;
    tr.frag_num  = 5'd1;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;

    tr.raw_cfg[0]      = 1'b0;   // local
    tr.raw_cfg[15:8]   = 8'd0;   // invalid PAYLOAD_LEN
    tr.raw_cfg[20:16]  = 5'd1;
    tr.raw_cfg[28:24]  = 5'd1;

    $display("[INVALID_SEQ] Sending invalid packet with PAYLOAD_LEN=0");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);

  endtask

endclass

`endif