`ifndef BIRD_BACKPRESSURE_SEQ_SV
`define BIRD_BACKPRESSURE_SEQ_SV

class bird_backpressure_seq;

  virtual bird_if vif;

  function new(virtual bird_if vif);
    this.vif = vif;
  endfunction

  task body(int unsigned cycles = 80);
    $display("[BACKPRESSURE_SEQ] Starting output backpressure for %0d cycles", cycles);

    for (int i = 0; i < cycles; i++) begin
      @(vif.drv_cb);

      if ((i % 10) < 4) begin
        vif.drv_cb.local_rdy  <= 1'b0;
        vif.drv_cb.remote_rdy <= 1'b1;
      end
      else if ((i % 10) < 7) begin
        vif.drv_cb.local_rdy  <= 1'b1;
        vif.drv_cb.remote_rdy <= 1'b0;
      end
      else begin
        vif.drv_cb.local_rdy  <= 1'b1;
        vif.drv_cb.remote_rdy <= 1'b1;
      end
    end

    @(vif.drv_cb);
    vif.drv_cb.local_rdy  <= 1'b1;
    vif.drv_cb.remote_rdy <= 1'b1;

    $display("[BACKPRESSURE_SEQ] Finished output backpressure");
  endtask

endclass

`endif
