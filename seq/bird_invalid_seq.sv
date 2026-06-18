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

    // Invalid 1: local packet with bad FRAG_NUM.
    tr = new("invalid_local_bad_frag");
    tr.is_remote = 1'b0;
    tr.seq_num   = 1;
    tr.frag_num  = 2;
    tr.set_payload(p);

    $display("[INVALID_SEQ] Sending invalid local bad FRAG_NUM");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // Invalid 2: reserved bits are non-zero.
    tr = new("invalid_reserved_bits");
    tr.is_remote = 1'b0;
    tr.seq_num   = 1;
    tr.frag_num  = 1;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;
    tr.raw_cfg[0]     = 1'b0;
    tr.raw_cfg[7:1]   = 7'b111_1111;
    tr.raw_cfg[15:8]  = 8'd1;
    tr.raw_cfg[20:16] = 5'd1;
    tr.raw_cfg[28:24] = 5'd1;

    $display("[INVALID_SEQ] Sending invalid reserved bits packet");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // Invalid 3: remote packet with SEQ_NUM = 0.
    tr = new("invalid_remote_seq_zero");
    tr.is_remote = 1'b1;
    tr.seq_num   = 0;
    tr.frag_num  = 1;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;
    tr.raw_cfg[0]     = 1'b1;
    tr.raw_cfg[15:8]  = 8'd1;
    tr.raw_cfg[20:16] = 5'd1;
    tr.raw_cfg[28:24] = 5'd0;

    $display("[INVALID_SEQ] Sending invalid remote SEQ_NUM zero");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // Invalid 4: remote packet with FRAG_NUM = 0.
    tr = new("invalid_remote_frag_zero");
    tr.is_remote = 1'b1;
    tr.seq_num   = 2;
    tr.frag_num  = 0;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;
    tr.raw_cfg[0]     = 1'b1;
    tr.raw_cfg[15:8]  = 8'd1;
    tr.raw_cfg[20:16] = 5'd0;
    tr.raw_cfg[28:24] = 5'd2;

    $display("[INVALID_SEQ] Sending invalid remote FRAG_NUM zero");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);
    
    // Invalid 5: mismatched SEQ_NUM while another packet is accumulating.
    // First send a valid fragment 1 of 2 to start accumulation...
    tr = new("mismatch_seq_start");
    tr.is_remote = 1'b1;
    tr.seq_num   = 1;   // fragment 1
    tr.frag_num  = 2;   // of 2
    p[0] = 8'hAA;
    tr.set_payload(p);
    $display("[INVALID_SEQ] Starting remote accumulation (frag 1 of 2)");
    drv_mbx.put(tr);

    // Now send a fragment with seq_num > frag_num (DUT interprets this as mismatch/new packet)
    tr = new("mismatch_seq_new");
    tr.is_remote = 1'b1;
    tr.seq_num   = 3;   // index 3 > total 2 => DUT will drop
    tr.frag_num  = 2;
    p[0] = 8'hBB;
    tr.set_payload(p);
    $display("[INVALID_SEQ] Sending mismatched SEQ (should cause drop of active packet)");
    drv_mbx.put(tr);

    // Invalid 6: PAYLOAD_LEN = 0 (out of range 1-255).
    tr = new("invalid_payload_len_zero");
    tr.is_remote   = 1'b0;
    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg     = 32'h0000_0000;
    tr.raw_cfg[0]      = 1'b0;   // local
    tr.raw_cfg[15:8]   = 8'd0;   // PAYLOAD_LEN = 0 => invalid
    tr.raw_cfg[20:16]  = 5'd1;
    tr.raw_cfg[28:24]  = 5'd1;
    p[0] = 8'hCC;
    tr.set_payload(p);
    $display("[INVALID_SEQ] Sending PAYLOAD_LEN=0 (invalid)");
    drv_mbx.put(tr);

    // Invalid 7: local packet with SEQ_NUM != 1 (spec says local SEQ_NUM has no functional
    // impact but the DUT cfg_invalid check requires SEQ_NUM==1 for local).
    tr = new("invalid_local_seq_not_one");
    tr.is_remote   = 1'b0;
    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg     = 32'h0000_0000;
    tr.raw_cfg[0]      = 1'b0;
    tr.raw_cfg[15:8]   = 8'd1;
    tr.raw_cfg[20:16]  = 5'd1;
    tr.raw_cfg[28:24]  = 5'd2;   // SEQ_NUM=2 for local => DUT drops
    p[0] = 8'hDD;
    tr.set_payload(p);
    $display("[INVALID_SEQ] Sending local packet with SEQ_NUM=2 (should drop)");
    drv_mbx.put(tr);

  endtask

endclass

`endif
