
package bird_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef byte unsigned u8_t;

  `include "bird_transaction.sv"

  function automatic logic [15:0] crc16_ccitt(input u8_t data[]);
    logic [15:0] crc;

    crc = 16'hFFFF;

    foreach (data[i]) begin
      crc ^= {data[i], 8'h00};
      for (int b = 0; b < 8; b++) begin
        if (crc[15]) begin
          crc = (crc << 1) ^ 16'h1021;
        end else begin
          crc = (crc << 1);
        end
      end
    end

    return crc;
  endfunction

  function automatic logic [31:0] make_local_cfg(int unsigned payload_len);
    logic [31:0] cfg;

    cfg = 32'd0;
    cfg[0]     = 1'b0;
    cfg[15:8]  = payload_len[7:0];
    cfg[20:16] = 5'd1;
    cfg[28:24] = 5'd1;

    return cfg;
  endfunction

  // For the current uploaded DUT behavior:
  // fragment_index goes into cfg[28:24]
  // total_fragments goes into cfg[20:16]
  function automatic logic [31:0] make_remote_cfg(
    int unsigned payload_len,
    int unsigned fragment_index,
    int unsigned total_fragments
  );
    logic [31:0] cfg;

    cfg = 32'd0;
    cfg[0]     = 1'b1;
    cfg[15:8]  = payload_len[7:0];
    cfg[20:16] = total_fragments[4:0];
    cfg[28:24] = fragment_index[4:0];

    return cfg;
  endfunction

endpackage
