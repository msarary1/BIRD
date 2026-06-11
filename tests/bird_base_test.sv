import uvm_pkg::*;
`include "uvm_macros.svh"
import bird_pkg::*;

class bird_base_test extends uvm_test;

  `uvm_component_utils(bird_base_test)

  virtual bird_if vif;

  function new(string name = "bird_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual bird_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "virtual interface vif was not found")
    end
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    init_signals();
    apply_reset();
    check_reset_outputs();

    `uvm_info("BASE_TEST", "Reset-only smoke test passed", UVM_LOW)

    repeat (5) @(posedge vif.clk);
    phase.drop_objection(this);
  endtask

  task init_signals();
    vif.rst_n      <= 1'b1;
    vif.in_vld     <= 1'b0;
    vif.data_in    <= 8'h00;
    vif.cfg        <= 32'h0000_0000;
    vif.local_rdy  <= 1'b1;
    vif.remote_rdy <= 1'b1;
  endtask

  task apply_reset();
    @(posedge vif.clk);
    vif.rst_n <= 1'b0;

    repeat (4) @(posedge vif.clk);
    vif.rst_n <= 1'b1;

    repeat (2) @(posedge vif.clk);
  endtask

  task check_reset_outputs();
    if (vif.drop_cnt !== 16'd0) begin
      `uvm_error("RESET", $sformatf("drop_cnt should be 0 after reset, got %0d", vif.drop_cnt))
    end

    if (vif.local_vld !== 1'b0) begin
      `uvm_error("RESET", "local_vld should be 0 after reset")
    end

    if (vif.remote_vld !== 1'b0) begin
      `uvm_error("RESET", "remote_vld should be 0 after reset")
    end
  endtask

  task send_byte(logic [7:0] data, logic [31:0] cfg_value);
    vif.in_vld  <= 1'b1;
    vif.data_in <= data;
    vif.cfg     <= cfg_value;

    do begin
      @(posedge vif.clk);
    end while (vif.in_rdy !== 1'b1);

    vif.in_vld  <= 1'b0;
    vif.data_in <= 8'h00;
  endtask

  task send_local_fragment(u8_t payload[], logic [15:0] crc_value);
    logic [31:0] cfg_value;

    cfg_value = make_local_cfg(payload.size());

    foreach (payload[i]) begin
      send_byte(payload[i], cfg_value);
    end

    send_byte(crc_value[15:8], cfg_value);
    send_byte(crc_value[7:0],  cfg_value);
  endtask

  task send_remote_fragment(
    u8_t         payload[],
    logic [15:0] crc_value,
    int unsigned fragment_index,
    int unsigned total_fragments
  );
    logic [31:0] cfg_value;

    cfg_value = make_remote_cfg(payload.size(), fragment_index, total_fragments);

    foreach (payload[i]) begin
      send_byte(payload[i], cfg_value);
    end

    send_byte(crc_value[15:8], cfg_value);
    send_byte(crc_value[7:0],  cfg_value);
  endtask

endclass
