`ifndef BIRD_REMOTE_SEQ_SV
`define BIRD_REMOTE_SEQ_SV

class bird_remote_seq;

  mailbox #(bird_transaction) drv_mbx;

  function new(mailbox #(bird_transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction

  // Normal in-order remote packet.
  // Official spec interpretation:
  //   SEQ_NUM  = packet ID, same for all fragments of the same packet
  //   FRAG_NUM = fragment position/order inside that packet
  task body();
    bird_transaction tr;
    u8_t p1[];
    u8_t p2[];

    p1 = new[1];
    p1[0] = 8'hA1;

    tr = new("remote_frag_1");
    tr.is_remote = 1'b1;
    tr.seq_num   = 3;
    tr.frag_num  = 1;
    tr.set_payload(p1);

    $display("[REMOTE_SEQ] Sending remote fragment 1, SEQ=3, FRAG=1");
    tr.display("[REMOTE_SEQ] ");
    drv_mbx.put(tr);

    p2 = new[1];
    p2[0] = 8'hB2;

    tr = new("remote_frag_2");
    tr.is_remote = 1'b1;
    tr.seq_num   = 3;
    tr.frag_num  = 2;
    tr.set_payload(p2);

    $display("[REMOTE_SEQ] Sending remote fragment 2, SEQ=3, FRAG=2");
    tr.display("[REMOTE_SEQ] ");
    drv_mbx.put(tr);
  endtask

  // Out-of-order remote packet.
  // Fragment 2 arrives before fragment 1, but both belong to SEQ=4.
  // Expected merged payload order is still FRAG=1 then FRAG=2.
  task body_out_of_order();
    bird_transaction tr;
    u8_t p1[];
    u8_t p2[];

    p2 = new[1];
    p2[0] = 8'hB2;

    tr = new("remote_oo_frag_2");
    tr.is_remote = 1'b1;
    tr.seq_num   = 4;
    tr.frag_num  = 2;
    tr.set_payload(p2);

    $display("[REMOTE_SEQ] Sending OUT-OF-ORDER remote fragment 2, SEQ=4, FRAG=2");
    tr.display("[REMOTE_SEQ] ");
    drv_mbx.put(tr);

    p1 = new[1];
    p1[0] = 8'hA1;

    tr = new("remote_oo_frag_1");
    tr.is_remote = 1'b1;
    tr.seq_num   = 4;
    tr.frag_num  = 1;
    tr.set_payload(p1);

    $display("[REMOTE_SEQ] Sending OUT-OF-ORDER remote fragment 1, SEQ=4, FRAG=1");
    tr.display("[REMOTE_SEQ] ");
    drv_mbx.put(tr);
  endtask

endclass

`endif
