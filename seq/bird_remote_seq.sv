`ifndef BIRD_REMOTE_SEQ_SV
`define BIRD_REMOTE_SEQ_SV

class bird_remote_seq;

  mailbox #(bird_transaction) drv_mbx;

  function new(mailbox #(bird_transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction

  task body();
    bird_transaction tr;
    u8_t p1[];
    u8_t p2[];

    // Fragment 1
    p1 = new[1];
    p1[0] = 8'hA1;

    tr = new("remote_frag_1");
    tr.is_remote = 1'b1;
    tr.seq_num   = 3;
    tr.frag_num  = 1;
    tr.set_payload(p1);

    $display("[REMOTE_SEQ] Sending remote fragment 1");
    tr.display("[REMOTE_SEQ] ");
    drv_mbx.put(tr);

    // Fragment 2
    p2 = new[1];
    p2[0] = 8'hB2;

    tr = new("remote_frag_2");
    tr.is_remote = 1'b1;
    tr.seq_num   = 3;
    tr.frag_num  = 2;
    tr.set_payload(p2);

    $display("[REMOTE_SEQ] Sending remote fragment 2");
    tr.display("[REMOTE_SEQ] ");
    drv_mbx.put(tr);
  endtask

endclass

`endif
