`ifndef BIRD_SCOREBOARD_SV
`define BIRD_SCOREBOARD_SV

// Stronger BIRD scoreboard.
// Checks:
// 1. Local payload forwarding.
// 2. Local CRC forwarding unchanged.
// 3. No unexpected local/remote output for invalid packets.
// 4. Remote fragment merge by FRAG_NUM.
// 5. Remote CRC regeneration over merged payload.
// 6. End-of-test PASS/FAIL report.

class bird_scoreboard;

  mailbox #(bird_input_fragment) in_obs_mbx;
  mailbox #(bird_output_item)    local_mbx;
  mailbox #(bird_output_item)    remote_mbx;

  int unsigned input_frag_count;
  int unsigned valid_local_frag_count;
  int unsigned valid_remote_frag_count;
  int unsigned invalid_frag_count;

  int unsigned local_byte_count;
  int unsigned remote_word_count;

  int unsigned expected_drop_count;

  int unsigned checked_local_bytes;
  int unsigned checked_remote_words;

  int unsigned error_count;
  int unsigned warning_count;

  u8_t         exp_local_q[$];
  u8_t         got_local_q[$];

  logic [31:0] exp_remote_q[$];
  logic [31:0] got_remote_q[$];

  bit compared;

  // Remote expected model: one active remote packet at a time.
  bit          remote_active;
  int unsigned active_seq;
  int unsigned active_max_frag;
  bit          remote_frag_seen[0:31];
  u8_t         remote_frag_payload[0:31][$];

  function new(mailbox #(bird_input_fragment) in_obs_mbx,
               mailbox #(bird_output_item)    local_mbx,
               mailbox #(bird_output_item)    remote_mbx);

    this.in_obs_mbx = in_obs_mbx;
    this.local_mbx  = local_mbx;
    this.remote_mbx = remote_mbx;

    input_frag_count       = 0;
    valid_local_frag_count = 0;
    valid_remote_frag_count = 0;
    invalid_frag_count     = 0;

    local_byte_count       = 0;
    remote_word_count      = 0;

    expected_drop_count    = 0;

    checked_local_bytes    = 0;
    checked_remote_words   = 0;

    error_count            = 0;
    warning_count          = 0;

    compared               = 0;

    clear_remote_model();
  endfunction

  task run();
    fork
      collect_input();
      collect_local();
      collect_remote();
    join_none
  endtask

  // ============================================================
  // Small adapters for bird_output_item
  // If your bird_output_item field name is not "data",
  // change only these two functions.
  // Example alternatives:
  //   return item.byte_data;
  //   return item.data_byte;
  //   return item.word_data;
  // ============================================================

  function automatic u8_t get_local_byte(bird_output_item item);
  return item.data_byte;
endfunction

function automatic logic [31:0] get_remote_word(bird_output_item item);
  return item.data_word;
endfunction

  // ============================================================
  // Error / warning helpers
  // ============================================================

  function void sb_error(string msg);
    error_count++;
    $error("[SB][ERROR] %s", msg);
  endfunction

  function void sb_warning(string msg);
    warning_count++;
    $display("[SB][WARNING] %s", msg);
  endfunction

  // ============================================================
  // cfg rules, same rules expected from BIRD spec/DUT
  // ============================================================

  function automatic bit cfg_invalid(input logic [31:0] c);
    bit inv;

    inv = 0;

    // Reserved bits must be zero
    if (c[7:1]   != 7'd0) inv = 1;
    if (c[23:21] != 3'd0) inv = 1;
    if (c[31:29] != 3'd0) inv = 1;

    // PAYLOAD_LEN must not be zero
    if (c[15:8] == 8'd0) inv = 1;

    if (c[0] == 1'b0) begin
      // Local packet: SEQ_NUM and FRAG_NUM must both be 1
      if (c[28:24] != 5'd1) inv = 1;
      if (c[20:16] != 5'd1) inv = 1;
    end
    else begin
      // Remote packet: SEQ_NUM and FRAG_NUM must be non-zero
      if (c[28:24] == 5'd0) inv = 1;
      if (c[20:16] == 5'd0) inv = 1;
    end

    return inv;
  endfunction

  // ============================================================
  // CRC16-CCITT: poly 0x1021, init 0xFFFF
  // ============================================================

  function automatic logic [15:0] crc16_ccitt(input u8_t bytes[$]);
    logic [15:0] crc;

    crc = 16'hFFFF;

    foreach (bytes[i]) begin
      crc ^= {bytes[i], 8'h00};

      for (int b = 0; b < 8; b++) begin
        if (crc[15])
          crc = (crc << 1) ^ 16'h1021;
        else
          crc = (crc << 1);
      end
    end

    return crc;
  endfunction

  function automatic void pack_bytes_to_words(input u8_t bytes[$],
                                              inout logic [31:0] words[$]);
    int i;

    i = 0;

    while (i < bytes.size()) begin
      logic [31:0] w;

      w = 32'h0000_0000;

      for (int k = 0; k < 4; k++) begin
        if (i < bytes.size()) begin
          w[8*k +: 8] = bytes[i];
          i++;
        end
      end

      words.push_back(w);
    end
  endfunction

  // ============================================================
  // Input collector: builds expected behavior
  // ============================================================

  task collect_input();
    bird_input_fragment frag;

    forever begin
      in_obs_mbx.get(frag);
      input_frag_count++;

      $display("[SB] INPUT fragment %0d: remote=%0d cfg=0x%08h len=%0d frag=%0d seq=%0d crc=0x%04h",
               input_frag_count,
               frag.cfg[0],
               frag.cfg,
               frag.cfg[15:8],
               frag.cfg[20:16],
               frag.cfg[28:24],
               frag.input_crc);

      process_input_fragment(frag);
    end
  endtask

  function void process_input_fragment(bird_input_fragment frag);
    logic [15:0] calc_crc;

    if (cfg_invalid(frag.cfg)) begin
      invalid_frag_count++;
      expected_drop_count++;

      $display("[SB] Expected DROP for invalid cfg=0x%08h", frag.cfg);
      return;
    end

    calc_crc = crc16_ccitt(frag.payload);

    if (calc_crc !== frag.input_crc) begin
      sb_error($sformatf("Input CRC mismatch. cfg=0x%08h expected_crc=0x%04h observed_crc=0x%04h",
                         frag.cfg, calc_crc, frag.input_crc));
    end

    if (frag.cfg[0] == 1'b0) begin
      build_expected_local(frag);
    end
    else begin
      build_expected_remote_fragment(frag);
    end
  endfunction

  // ============================================================
  // Local expected model
  // Local output should be payload bytes then same input CRC bytes.
  // ============================================================

  function void build_expected_local(bird_input_fragment frag);
    valid_local_frag_count++;

    foreach (frag.payload[i]) begin
      exp_local_q.push_back(frag.payload[i]);
    end

    exp_local_q.push_back(frag.input_crc[15:8]);
    exp_local_q.push_back(frag.input_crc[7:0]);

    $display("[SB] Expected LOCAL packet added: payload_len=%0d total_expected_local_bytes=%0d",
             frag.payload.size(), exp_local_q.size());
  endfunction

  // ============================================================
  // Remote expected model
  // Remote fragments are collected by SEQ_NUM and FRAG_NUM.
  // At report time, fragments are merged in FRAG_NUM order.
  // Output expected format:
  //   merged payload packed into 32-bit words, little-endian byte order
  //   then one CRC word: {16'h0000, regenerated_crc}
  // ============================================================

  function void clear_remote_model();
    remote_active   = 0;
    active_seq      = 0;
    active_max_frag = 0;

    for (int f = 0; f < 32; f++) begin
      remote_frag_seen[f] = 0;
      remote_frag_payload[f].delete();
    end
  endfunction

  function void build_expected_remote_fragment(bird_input_fragment frag);
    int unsigned seq;
    int unsigned frag_num;

    seq      = frag.cfg[28:24];
    frag_num = frag.cfg[20:16];

    valid_remote_frag_count++;

    if (!remote_active) begin
      remote_active   = 1;
      active_seq      = seq;
      active_max_frag = 0;
    end
    else if (seq != active_seq) begin
      // New remote packet started. Finalize the previous one first.
      finalize_remote_packet();
      remote_active   = 1;
      active_seq      = seq;
      active_max_frag = 0;
    end

    if (frag_num < 1 || frag_num > 31) begin
      sb_error($sformatf("Illegal remote FRAG_NUM=%0d after cfg validation", frag_num));
      return;
    end

    if (remote_frag_seen[frag_num]) begin
      sb_error($sformatf("Duplicate remote fragment: SEQ_NUM=%0d FRAG_NUM=%0d",
                         seq, frag_num));
      remote_frag_payload[frag_num].delete();
    end

    remote_frag_seen[frag_num] = 1;

    foreach (frag.payload[i]) begin
      remote_frag_payload[frag_num].push_back(frag.payload[i]);
    end

    if (frag_num > active_max_frag) begin
      active_max_frag = frag_num;
    end

    $display("[SB] Stored expected REMOTE fragment: seq=%0d frag=%0d len=%0d",
             seq, frag_num, frag.payload.size());
  endfunction

  function void finalize_remote_packet();
    u8_t merged[$];
    logic [15:0] crc;
    bit complete;

    if (!remote_active) begin
      return;
    end

    complete = 1;
    merged.delete();

    for (int f = 1; f <= active_max_frag; f++) begin
      if (!remote_frag_seen[f]) begin
        complete = 0;
        sb_error($sformatf("Missing remote fragment: SEQ_NUM=%0d FRAG_NUM=%0d",
                           active_seq, f));
      end
    end

    if (complete) begin
      for (int f = 1; f <= active_max_frag; f++) begin
        for (int i = 0; i < remote_frag_payload[f].size(); i++) begin
          merged.push_back(remote_frag_payload[f][i]);
        end
      end

      crc = crc16_ccitt(merged);

      pack_bytes_to_words(merged, exp_remote_q);
      exp_remote_q.push_back({16'h0000, crc});

      $display("[SB] Expected REMOTE packet finalized: seq=%0d fragments=%0d merged_len=%0d crc=0x%04h expected_words=%0d",
               active_seq, active_max_frag, merged.size(), crc, exp_remote_q.size());
    end

    clear_remote_model();
  endfunction

  // ============================================================
  // Output collectors: collect actual DUT output
  // ============================================================

  task collect_local();
    bird_output_item item;
    u8_t b;

    forever begin
      local_mbx.get(item);

      b = get_local_byte(item);
      got_local_q.push_back(b);
      local_byte_count++;

      $display("[SB] Got LOCAL byte %0d = 0x%02h", local_byte_count, b);
    end
  endtask

  task collect_remote();
    bird_output_item item;
    logic [31:0] w;

    forever begin
      remote_mbx.get(item);

      w = get_remote_word(item);
      got_remote_q.push_back(w);
      remote_word_count++;

      $display("[SB] Got REMOTE word %0d = 0x%08h", remote_word_count, w);
    end
  endtask

  // ============================================================
  // Compare expected vs actual at end of test
  // ============================================================

  function void compare_local();
    int n;

    n = (exp_local_q.size() < got_local_q.size()) ? exp_local_q.size() : got_local_q.size();

    for (int i = 0; i < n; i++) begin
      checked_local_bytes++;

      if (got_local_q[i] !== exp_local_q[i]) begin
        sb_error($sformatf("LOCAL mismatch at byte %0d: expected=0x%02h got=0x%02h",
                           i, exp_local_q[i], got_local_q[i]));
      end
    end

    if (got_local_q.size() != exp_local_q.size()) begin
      sb_error($sformatf("LOCAL size mismatch: expected_bytes=%0d got_bytes=%0d",
                         exp_local_q.size(), got_local_q.size()));
    end
  endfunction

  function void compare_remote();
    int n;

    n = (exp_remote_q.size() < got_remote_q.size()) ? exp_remote_q.size() : got_remote_q.size();

    for (int i = 0; i < n; i++) begin
      checked_remote_words++;

      if (got_remote_q[i] !== exp_remote_q[i]) begin
        sb_error($sformatf("REMOTE mismatch at word %0d: expected=0x%08h got=0x%08h",
                           i, exp_remote_q[i], got_remote_q[i]));
      end
    end

    if (got_remote_q.size() != exp_remote_q.size()) begin
      sb_error($sformatf("REMOTE size mismatch: expected_words=%0d got_words=%0d",
                         exp_remote_q.size(), got_remote_q.size()));
    end
  endfunction

  function void compare_all();
    if (compared) begin
      return;
    end

    finalize_remote_packet();

    compare_local();
    compare_remote();

    compared = 1;
  endfunction

  // ============================================================
  // Final report
  // ============================================================

  function void report();
    compare_all();

    $display("");
    $display("==================== BIRD SCOREBOARD REPORT ====================");
    $display("Input fragments observed      : %0d", input_frag_count);
    $display("Valid local fragments         : %0d", valid_local_frag_count);
    $display("Valid remote fragments        : %0d", valid_remote_frag_count);
    $display("Invalid fragments expected drop: %0d", invalid_frag_count);
    $display("Expected drop count events    : %0d", expected_drop_count);
    $display("");
    $display("Expected local bytes          : %0d", exp_local_q.size());
    $display("Observed local bytes          : %0d", got_local_q.size());
    $display("Checked local bytes           : %0d", checked_local_bytes);
    $display("");
    $display("Expected remote words         : %0d", exp_remote_q.size());
    $display("Observed remote words         : %0d", got_remote_q.size());
    $display("Checked remote words          : %0d", checked_remote_words);
    $display("");
    $display("Warnings                      : %0d", warning_count);
    $display("Errors                        : %0d", error_count);

    if (error_count == 0) begin
      $display("SCOREBOARD RESULT             : PASS");
    end
    else begin
      $display("SCOREBOARD RESULT             : FAIL");
    end

    $display("================================================================");
    $display("");
  endfunction

endclass

`endif