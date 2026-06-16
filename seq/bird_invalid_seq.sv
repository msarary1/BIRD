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

    // Invalid 1: local packet with bad FRAG_NUM
    tr = new("invalid_local_bad_frag");
    tr.is_remote = 1'b0;
    tr.seq_num   = 1;
    tr.frag_num  = 2;
    tr.set_payload(p);

    $display("[INVALID_SEQ] Sending invalid local bad FRAG_NUM");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // Invalid 2: reserved bits are non-zero
    tr = new("invalid_reserved_bits");
    tr.is_remote = 1'b0;
    tr.seq_num   = 1;
    tr.frag_num  = 1;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;
    tr.raw_cfg[0]     = 1'b0;          // local
    tr.raw_cfg[7:1]   = 7'b111_1111;   // invalid reserved bits
    tr.raw_cfg[15:8]  = 8'd1;          // payload length
    tr.raw_cfg[20:16] = 5'd1;          // frag num
    tr.raw_cfg[28:24] = 5'd1;          // seq num

    $display("[INVALID_SEQ] Sending invalid reserved bits packet");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);


    // Invalid 3: remote packet with SEQ_NUM = 0
    tr = new("invalid_remote_seq_zero");
    tr.is_remote = 1'b1;
    tr.seq_num   = 0;
    tr.frag_num  = 1;
    tr.set_payload(p);

    tr.use_raw_cfg = 1'b1;
    tr.raw_cfg = 32'h0000_0000;
    tr.raw_cfg[0]     = 1'b1;          // remote
    tr.raw_cfg[15:8]  = 8'd1;          // payload length
    tr.raw_cfg[20:16] = 5'd1;          // frag num
    tr.raw_cfg[28:24] = 5'd0;          // invalid seq num

    $display("[INVALID_SEQ] Sending invalid remote SEQ_NUM zero");
    tr.display("[INVALID_SEQ] ");
    drv_mbx.put(tr);

  endtask

endclass

`endif  