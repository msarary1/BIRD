`ifndef BIRD_LOCAL_SEQ_SV
`define BIRD_LOCAL_SEQ_SV

class bird_local_seq;

  mailbox #(bird_transaction) drv_mbx;

  function new(mailbox #(bird_transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction

  task body(int unsigned count = 1);
    bird_transaction tr;
    u8_t p[];

    for (int n = 0; n < count; n++) begin
      p = new[1];
      p[0] = 8'h10 + n;

      tr = new($sformatf("local_seq_pkt_%0d", n));
      tr.is_remote = 1'b0;
      tr.frag_num  = 1;
      tr.seq_num   = 1;
      tr.set_payload(p);

      $display("[LOCAL_SEQ] Sending local packet %0d", n);
      tr.display("[LOCAL_SEQ] ");

      drv_mbx.put(tr);
    end
  endtask

endclass

`endif
