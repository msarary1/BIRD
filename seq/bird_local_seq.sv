`ifndef BIRD_LOCAL_SEQ_SV
`define BIRD_LOCAL_SEQ_SV

class bird_local_seq;

  mailbox #(bird_transaction) drv_mbx;

  function new(mailbox #(bird_transaction) drv_mbx);
    this.drv_mbx = drv_mbx;
  endfunction

  task body(int unsigned count = 1,
            bit vary_seq = 0,
            int unsigned base_payload_len = 1);

    bird_transaction tr;
    u8_t p[];
    int unsigned len;

    for (int n = 0; n < count; n++) begin

      len = base_payload_len + n;

      if (len < 1) begin
        len = 1;
      end

      if (len > 8) begin
        len = 8;
      end

      p = new[len];

      foreach (p[i]) begin
        p[i] = 8'h10 + n + i;
      end

      tr = new($sformatf("local_seq_pkt_%0d", n));
      tr.is_remote = 1'b0;
      tr.frag_num  = 1;

      if (vary_seq) begin
        tr.seq_num = (n % 31) + 1;
      end
      else begin
        tr.seq_num = 1;
      end

      tr.set_payload(p);

      $display("[LOCAL_SEQ] Sending local packet %0d", n);
      tr.display("[LOCAL_SEQ] ");

      drv_mbx.put(tr);
    end
  endtask

endclass

`endif
