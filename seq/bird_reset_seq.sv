`ifndef BIRD_RESET_SEQ_SV
`define BIRD_RESET_SEQ_SV

class bird_reset_seq;

  virtual bird_if vif;

  function new(virtual bird_if vif);
    this.vif = vif;
  endfunction

  task apply_reset(int unsigned cycles = 5);
    $display("[RESET_SEQ] Applying reset at time %0t", $time);

    vif.rst_n      <= 1'b0;
    vif.in_vld     <= 1'b0;
    vif.data_in    <= 8'h00;
    vif.cfg        <= 32'h0000_0000;
    vif.local_rdy  <= 1'b1;
    vif.remote_rdy <= 1'b1;

    repeat (cycles) @(posedge vif.clk);

    vif.rst_n <= 1'b1;

    repeat (2) @(posedge vif.clk);

    $display("[RESET_SEQ] Reset released at time %0t", $time);
  endtask

endclass

`endif
