`ifndef BIRD_TRANSACTION_SV
`define BIRD_TRANSACTION_SV

// Basic packet/fragment transaction for BIRD.
// Pure SystemVerilog, not UVM.

class bird_transaction;

  string name;

  // cfg fields
  rand bit          is_remote;    // cfg[0], 0 = local, 1 = remote
  rand int unsigned payload_len;  // cfg[15:8]
  rand int unsigned frag_num;     // cfg[20:16]
  rand int unsigned seq_num;      // cfg[28:24]

  // Payload only. CRC is generated automatically.
  rand u8_t payload[];

  // For future negative/drop tests
  bit        use_raw_cfg;
  logic [31:0] raw_cfg;

  constraint legal_length_c {
    payload_len inside {[1:255]};
    payload.size() == payload_len;
  }

  constraint legal_cfg_c {
    frag_num inside {[1:31]};
    seq_num  inside {[1:31]};

    if (!is_remote) {
      frag_num == 1;
      seq_num  == 1;
    }
  }

  function new(string name = "bird_transaction");
    this.name = name;

    is_remote   = 0;
    payload_len = 1;
    frag_num    = 1;
    seq_num     = 1;

    payload = new[1];
    payload[0] = 8'h00;

    use_raw_cfg = 0;
    raw_cfg = 32'h0000_0000;
  endfunction

  function void set_payload(input u8_t data[]);
    payload = new[data.size()];
    foreach (data[i]) begin
      payload[i] = data[i];
    end
    payload_len = data.size();
  endfunction

  function logic [31:0] pack_cfg();
    logic [31:0] c;

    if (use_raw_cfg) begin
      return raw_cfg;
    end

    c = 32'h0000_0000;
    c[0]     = is_remote;
    c[15:8]  = payload_len[7:0];
    c[20:16] = frag_num[4:0];
    c[28:24] = seq_num[4:0];

    return c;
  endfunction

  // CRC16-CCITT
  // Polynomial = 0x1021
  // Initial value = 0xFFFF
  // This matches the CRC function inside your DUT.
  function logic [15:0] calc_crc16_ccitt();
    logic [15:0] crc;

    crc = 16'hFFFF;

    foreach (payload[i]) begin
      crc ^= {payload[i], 8'h00};

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

  function void build_stream(ref u8_t stream[$]);
    logic [15:0] crc;

    stream.delete();

    foreach (payload[i]) begin
      stream.push_back(payload[i]);
    end

    crc = calc_crc16_ccitt();

    // Send CRC after payload.
    stream.push_back(crc[15:8]);
    stream.push_back(crc[7:0]);
  endfunction

  function void display(string prefix = "");
    $display("%s%s: remote=%0b len=%0d frag=%0d seq=%0d cfg=0x%08h payload=%p crc=0x%04h",
             prefix,
             name,
             is_remote,
             payload_len,
             frag_num,
             seq_num,
             pack_cfg(),
             payload,
             calc_crc16_ccitt());
  endfunction

endclass


// Reconstructed input fragment from input monitor
class bird_input_fragment;

  logic [31:0] cfg;

  bit          is_remote;
  int unsigned payload_len;
  int unsigned frag_num;
  int unsigned seq_num;

  u8_t stream[$];
  u8_t payload[$];

  logic [15:0] input_crc;

  time start_time;
  time end_time;

  function new();
    cfg = 32'h0000_0000;
    is_remote = 0;
    payload_len = 0;
    frag_num = 0;
    seq_num = 0;
    input_crc = 16'h0000;
    start_time = 0;
    end_time = 0;
  endfunction

  function void decode_cfg();
    is_remote   = cfg[0];
    payload_len = cfg[15:8];
    frag_num    = cfg[20:16];
    seq_num     = cfg[28:24];
  endfunction

  function void finalize();
    payload.delete();
    decode_cfg();

    for (int i = 0; i < payload_len && i < stream.size(); i++) begin
      payload.push_back(stream[i]);
    end

    if (stream.size() >= payload_len + 2) begin
      input_crc = {stream[payload_len], stream[payload_len + 1]};
    end else begin
      input_crc = 16'hxxxx;
    end
  endfunction

  function void display(string prefix = "");
    $display("%sINPUT_FRAGMENT: remote=%0b len=%0d frag=%0d seq=%0d cfg=0x%08h payload=%p input_crc=0x%04h time=%0t..%0t",
             prefix,
             is_remote,
             payload_len,
             frag_num,
             seq_num,
             cfg,
             payload,
             input_crc,
             start_time,
             end_time);
  endfunction

endclass


typedef enum int {
  BIRD_OUT_LOCAL,
  BIRD_OUT_REMOTE
} bird_output_kind_e;


class bird_output_item;

  bird_output_kind_e kind;

  u8_t data_byte;
  logic [31:0] data_word;
  logic [15:0] drop_cnt;

  time sample_time;

  function new(bird_output_kind_e kind = BIRD_OUT_LOCAL);
    this.kind = kind;
    data_byte = 8'h00;
    data_word = 32'h0000_0000;
    drop_cnt = 16'h0000;
    sample_time = 0;
  endfunction

  function void display(string prefix = "");
    if (kind == BIRD_OUT_LOCAL) begin
      $display("%sLOCAL_OUT: byte=0x%02h drop_cnt=%0d time=%0t",
               prefix, data_byte, drop_cnt, sample_time);
    end else begin
      $display("%sREMOTE_OUT: word=0x%08h drop_cnt=%0d time=%0t",
               prefix, data_word, drop_cnt, sample_time);
    end
  endfunction

endclass

`endif
