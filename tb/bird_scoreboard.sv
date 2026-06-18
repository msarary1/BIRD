`ifndef BIRD_SCOREBOARD_SV
`define BIRD_SCOREBOARD_SV

class bird_scoreboard;

  mailbox #(bird_input_fragment) in_obs_mbx;
  mailbox #(bird_output_item)    local_mbx;
  mailbox #(bird_output_item)    remote_mbx;

  virtual bird_if vif;

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

  u8_t exp_local_q[$];
  u8_t got_local_q[$];

  logic [31:0] exp_remote_q[$];
  logic [31:0] got_remote_q[$];

  bit compared;

  // Remote expected model according to spec:
  // Same SEQ_NUM for one remote packet.
  // FRAG_NUM is the index/position of each fragment.
  bit          remote_active;
  int unsigned active_seq;
  int unsigned active_max_frag;
  bit          remote_frag_seen[0:31];
  u8_t         remote_frag_payload[0:31][$];

  function new(mailbox #(bird_input_fragment) in_obs_mbx,
               mailbox #(bird_output_item)    local_mbx,
               mailbox #(bird_output_item)    remote_mbx,
               virtual bird_if vif);

    this.in_obs_mbx = in_obs_mbx;
    this.local_mbx  = local_mbx;
    this.remote_mbx = remote_mbx;
    this.vif        = vif;

    input_frag_count        = 0;
    valid_local_frag_count  = 0;
    valid_remote_frag_count = 0;
    invalid_frag_count      = 0;

    local_byte_count        = 0;
    remote_word_count       = 0;

    expected_drop_count     = 0;

    checked_local_bytes     = 0;
    checked_remote_words    = 0;

    error_count             = 0;
    warning_count           = 0;

    compared                = 0;

    clear_remote_model();
  endfunction


  task run();
    fork
      collect_input();
      collect_local();
      collect_remote();
    join_none
  endtask


  function void sb_error(string msg);
    error_count++;
    $error("[SB][ERROR] %s", msg);
  endfunction


  function void sb_warning(string msg);
    warning_count++;
    $display("[SB][WARNING] %s", msg);
  endfunction


  function automatic bit cfg_invalid(input logic [31:0] c);
    bit inv;

    inv = 0;

    // Reserved fields must be zero.
    if (c[7:1]   != 7'd0) inv = 1;
    if (c[23:21] != 3'd0) inv = 1;
    if (c[31:29] != 3'd0) inv = 1;

    // PAYLOAD_LEN must be 1..255.
    if (c[15:8] == 8'd0) inv = 1;

    // SEQ_NUM and FRAG_NUM cannot be zero.
    if (c[28:24] == 5'd0) inv = 1;
    if (c[20:16] == 5'd0) inv = 1;

    // Local traffic is single-fragment only.
    // Do NOT require SEQ_NUM==1 for local traffic.
    if (c[0] == 1'b0) begin
      if (c[20:16] != 5'd1) inv = 1;
    end

    return inv;
  endfunction


  function automatic logic [15:0] crc16_ccitt(input u8_t bytes[$]);
    logic [15:0] crc;

    crc = 16'hFFFF;

    foreach (bytes[i]) begin
      crc ^= {bytes[i], 8'h00};

      for (int b = 0; b < 8; b++) begin
        if (crc[15]) begin
          crc = (crc << 1) ^ 16'h1021;
        end
        else begin
          crc = (crc << 1);
        end
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


  task collect_input();
    bird_input_fragment frag;

    forever begin
      in_obs_mbx.get(frag);

      input_frag_count++;

      $display("[SB] INPUT fragment %0d: remote=%0d cfg=0x%08h len=%0d frag=%0d seq=%0d crc=0x%04h",
               input_frag_count,
               frag.is_remote,
               frag.cfg,
               frag.payload_len,
               frag.frag_num,
               frag.seq_num,
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

      // If an invalid remote fragment arrives while a remote packet is active,
      // the affected active packet is discarded by the spec.
      if (frag.is_remote && remote_active) begin
        clear_remote_model();
      end

      return;
    end

    calc_crc = crc16_ccitt(frag.payload);

    if (calc_crc !== frag.input_crc) begin
      sb_error($sformatf("Input CRC mismatch. cfg=0x%08h expected_crc=0x%04h observed_crc=0x%04h",
                         frag.cfg, calc_crc, frag.input_crc));
    end

    if (!frag.is_remote) begin
      build_expected_local(frag);
    end
    else begin
      build_expected_remote_fragment(frag);
    end
  endfunction


  function void build_expected_local(bird_input_fragment frag);
    valid_local_frag_count++;

    foreach (frag.payload[i]) begin
      exp_local_q.push_back(frag.payload[i]);
    end

    // Local traffic forwards input CRC unchanged.
    exp_local_q.push_back(frag.input_crc[15:8]);
    exp_local_q.push_back(frag.input_crc[7:0]);

    $display("[SB] Expected LOCAL packet added: payload_len=%0d total_expected_local_bytes=%0d",
             frag.payload.size(),
             exp_local_q.size());
  endfunction


  function void clear_remote_model();
    remote_active   = 0;
    active_seq      = 0;
    active_max_frag = 0;

    for (int f = 0; f < 32; f++) begin
      remote_frag_seen[f] = 0;
      remote_frag_payload[f].delete();
    end
  endfunction


  function automatic bit all_expected_remote_frags_seen(input int unsigned max_frag);
    bit complete;

    complete = 1;

    if (max_frag == 0) begin
      complete = 0;
    end

    for (int f = 1; f <= max_frag; f++) begin
      if (!remote_frag_seen[f]) begin
        complete = 0;
      end
    end

    return complete;
  endfunction


  function void build_expected_remote_fragment(bird_input_fragment frag);
    int unsigned frag_idx;

    frag_idx = frag.frag_num;

    valid_remote_frag_count++;

    if (frag_idx < 1 || frag_idx > 31) begin
      invalid_frag_count++;
      expected_drop_count++;

      $display("[SB] Expected DROP: illegal remote FRAG_NUM=%0d", frag_idx);

      clear_remote_model();
      return;
    end

    if (!remote_active) begin
      remote_active   = 1;
      active_seq      = frag.seq_num;
      active_max_frag = frag_idx;
    end
    else begin
      // All fragments of one remote packet must share the same SEQ_NUM.
      if (frag.seq_num != active_seq) begin
        invalid_frag_count++;
        expected_drop_count++;

        $display("[SB] Expected DROP: mismatched remote SEQ_NUM active=%0d new=%0d",
                 active_seq,
                 frag.seq_num);

        clear_remote_model();
        return;
      end

      if (frag_idx > active_max_frag) begin
        active_max_frag = frag_idx;
      end
    end

    if (remote_frag_seen[frag_idx]) begin
      invalid_frag_count++;
      expected_drop_count++;

      $display("[SB] Expected DROP: duplicate remote FRAG_NUM=%0d", frag_idx);

      clear_remote_model();
      return;
    end

    remote_frag_seen[frag_idx] = 1;
    remote_frag_payload[frag_idx].delete();

    foreach (frag.payload[i]) begin
      remote_frag_payload[frag_idx].push_back(frag.payload[i]);
    end

    $display("[SB] Stored expected REMOTE fragment: seq=%0d frag=%0d len=%0d",
             frag.seq_num,
             frag.frag_num,
             frag.payload.size());

    // There is no explicit LAST signal in the spec.
    // Therefore, the scoreboard finalizes the remote packet at end-of-test.
  endfunction


  function void finalize_remote_packet();
    u8_t merged[$];
    logic [15:0] crc;

    if (!remote_active) begin
      return;
    end

    merged.delete();

    if (!all_expected_remote_frags_seen(active_max_frag)) begin
      invalid_frag_count++;
      expected_drop_count++;

      $display("[SB] Expected DROP: remote packet SEQ_NUM=%0d incomplete. max_frag=%0d",
               active_seq,
               active_max_frag);

      clear_remote_model();
      return;
    end

    for (int f = 1; f <= active_max_frag; f++) begin
      for (int i = 0; i < remote_frag_payload[f].size(); i++) begin
        merged.push_back(remote_frag_payload[f][i]);
      end
    end

    crc = crc16_ccitt(merged);

    // Remote output = merged payload packed into 32-bit words + regenerated CRC16.
    pack_bytes_to_words(merged, exp_remote_q);
    exp_remote_q.push_back({16'h0000, crc});

    $display("[SB] Expected REMOTE packet finalized: seq=%0d fragments=%0d merged_len=%0d crc=0x%04h expected_words=%0d",
             active_seq,
             active_max_frag,
             merged.size(),
             crc,
             exp_remote_q.size());

    clear_remote_model();
  endfunction


  task collect_local();
    bird_output_item item;

    forever begin
      local_mbx.get(item);

      got_local_q.push_back(item.data_byte);
      local_byte_count++;

      $display("[SB] Got LOCAL byte %0d = 0x%02h",
               local_byte_count,
               item.data_byte);
    end
  endtask


  task collect_remote();
    bird_output_item item;

    forever begin
      remote_mbx.get(item);

      got_remote_q.push_back(item.data_word);
      remote_word_count++;

      $display("[SB] Got REMOTE word %0d = 0x%08h",
               remote_word_count,
               item.data_word);
    end
  endtask


  function void compare_local();
    int n;

    n = (exp_local_q.size() < got_local_q.size()) ?
        exp_local_q.size() :
        got_local_q.size();

    for (int i = 0; i < n; i++) begin
      checked_local_bytes++;

      if (got_local_q[i] !== exp_local_q[i]) begin
        sb_error($sformatf("LOCAL mismatch at byte %0d: expected=0x%02h got=0x%02h",
                           i,
                           exp_local_q[i],
                           got_local_q[i]));
      end
    end

    if (got_local_q.size() != exp_local_q.size()) begin
      sb_error($sformatf("LOCAL size mismatch: expected_bytes=%0d got_bytes=%0d",
                         exp_local_q.size(),
                         got_local_q.size()));
    end
  endfunction


  function void compare_remote();
    int n;

    n = (exp_remote_q.size() < got_remote_q.size()) ?
        exp_remote_q.size() :
        got_remote_q.size();

    for (int i = 0; i < n; i++) begin
      checked_remote_words++;

      if (got_remote_q[i] !== exp_remote_q[i]) begin
        sb_error($sformatf("REMOTE mismatch at word %0d: expected=0x%08h got=0x%08h",
                           i,
                           exp_remote_q[i],
                           got_remote_q[i]));
      end
    end

    if (got_remote_q.size() != exp_remote_q.size()) begin
      sb_error($sformatf("REMOTE size mismatch: expected_words=%0d got_words=%0d",
                         exp_remote_q.size(),
                         got_remote_q.size()));
    end
  endfunction


  function void compare_drop_count();
    logic [15:0] observed_drop_count;
    logic [15:0] expected_drop_count_16;

    observed_drop_count   = vif.drop_cnt;
    expected_drop_count_16 = expected_drop_count[15:0];

    if (observed_drop_count !== expected_drop_count_16) begin
      sb_error($sformatf("DROP count mismatch: expected=%0d observed=%0d",
                         expected_drop_count_16,
                         observed_drop_count));
    end
  endfunction


  function void compare_all();
    if (compared) begin
      return;
    end

    finalize_remote_packet();

    compare_local();
    compare_remote();
    compare_drop_count();

    compared = 1;
  endfunction


  function void report();
    compare_all();

    $display("");
    $display("==================== BIRD SCOREBOARD REPORT ====================");
    $display("Input fragments observed      : %0d", input_frag_count);
    $display("Valid local fragments         : %0d", valid_local_frag_count);
    $display("Valid remote fragments        : %0d", valid_remote_frag_count);
    $display("Invalid fragments expected    : %0d", invalid_frag_count);
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
      $display("SCOREBOARD RESULT : PASS");
    end
    else begin
      $display("SCOREBOARD RESULT : FAIL");
    end

    $display("================================================================");
    $display("");
  endfunction

endclass

`endif