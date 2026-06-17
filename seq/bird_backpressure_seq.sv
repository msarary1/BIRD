`ifndef BIRD_BACKPRESSURE_SEQ_SV
`define BIRD_BACKPRESSURE_SEQ_SV

class bird_backpressure_seq;

  virtual bird_if vif;

  function new(virtual bird_if vif);
    this.vif = vif;
  endfunction

  task body(int unsigned cycles = 50);
    $display("[BACKPRESSURE_SEQ] Starting output backpressure");

    repeat (cycles) begin
      @(vif.drv_cb);
      vif.drv_cb.local_rdy  <= $urandom_range(0, 1);
      vif.drv_cb.remote_rdy <= $urandom_range(0, 1);
    end

    @(vif.drv_cb);
    vif.drv_cb.local_rdy  <= 1'b1;
    vif.drv_cb.remote_rdy <= 1'b1;

    $display("[BACKPRESSURE_SEQ] Finished output backpressure");
  endtask

endclass

`endif
