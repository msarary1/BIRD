`ifndef BiRD_DRIODVER_SV

`define BIRD_DRIVER_SV

class bird_driver;

  virtual bird_if vif;
  mailbox #(bird_transaction) in_mbx;

  function new(virtual bird_if vif,
               mailbox #(bird_transaction) in_mbx);
    this.vif = vif;
    this.in_mbx = in_mbx;
  endfunction

  task reset_signals();
    vif.in_vld     <= 1'b0;
    vif.data_in    <= 8'h00;
    vif.cfg        <= 32'h0000_0000;
    vif.local_rdy  <= 1'b1;
    vif.remote_rdy <= 1'b1;
  endtask

  task run();
    bird_transaction tr;

    reset_signals();

    wait (vif.rst_n === 1'b1);

    $display("[DRV] Driver started at time %0t", $time);

    forever begin
      in_mbx.get(tr);
      tr.display("[DRV] Driving ");
      drive_transaction(tr);
    end
  endtask

  task drive_transaction(bird_transaction tr);
    u8_t stream[$];
    logic [31:0] c;

    tr.build_stream(stream);
    c = tr.pack_cfg();

    // cfg must remain stable during the whole fragment transfer.
    foreach (stream[i]) begin
      bit accepted;
      accepted = 0;

      while (!accepted) begin
        @(vif.drv_cb);

        vif.drv_cb.in_vld  <= 1'b1;
        vif.drv_cb.data_in <= stream[i];
        vif.drv_cb.cfg     <= c;

        if (vif.drv_cb.in_rdy) begin
          accepted = 1;
        end
      end
    end

    @(vif.drv_cb);
    vif.drv_cb.in_vld  <= 1'b0;
    vif.drv_cb.data_in <= 8'h00;
    vif.drv_cb.cfg     <= 32'h0000_0000;
  endtask

  task set_output_ready(bit local_ready, bit remote_ready);
    @(vif.drv_cb);
    vif.drv_cb.local_rdy  <= local_ready;
    vif.drv_cb.remote_rdy <= remote_ready;
  endtask

endclass

`endif
