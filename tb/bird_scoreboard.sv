`ifndef BIRD_SCOREBOARD_SV
`define BIRD_SCOREBOARD_SV

// Starter scoreboard.
// Later all 3 students should extend this with:
// local expected model,
// remote reassembly model,
// CRC checking,
// drop counter checking.

class bird_scoreboard;

  mailbox #(bird_input_fragment) in_obs_mbx;
  mailbox #(bird_output_item)    local_mbx;
  mailbox #(bird_output_item)    remote_mbx;

  int unsigned input_frag_count;
  int unsigned local_byte_count;
  int unsigned remote_word_count;

  function new(mailbox #(bird_input_fragment) in_obs_mbx,
               mailbox #(bird_output_item)    local_mbx,
               mailbox #(bird_output_item)    remote_mbx);

    this.in_obs_mbx = in_obs_mbx;
    this.local_mbx  = local_mbx;
    this.remote_mbx = remote_mbx;

    input_frag_count = 0;
    local_byte_count = 0;
    remote_word_count = 0;
  endfunction

  task run();
    fork
      collect_input();
      collect_local();
      collect_remote();
    join_none
  endtask

  task collect_input();
    bird_input_fragment frag;

    forever begin
      in_obs_mbx.get(frag);
      input_frag_count++;
      $display("[SB] Observed input fragment count = %0d", input_frag_count);
    end
  endtask

  task collect_local();
    bird_output_item item;

    forever begin
      local_mbx.get(item);
      local_byte_count++;
      $display("[SB] Observed local byte count = %0d", local_byte_count);
    end
  endtask

  task collect_remote();
    bird_output_item item;

    forever begin
      remote_mbx.get(item);
      remote_word_count++;
      $display("[SB] Observed remote word count = %0d", remote_word_count);
    end
  endtask

  function void report();
    $display("");
    $display("================ BIRD STARTER SCOREBOARD REPORT ================");
    $display("Input fragments observed : %0d", input_frag_count);
    $display("Local bytes observed     : %0d", local_byte_count);
    $display("Remote words observed    : %0d", remote_word_count);
    $display("NOTE: This is a starter scoreboard only.");
    $display("Next step: add real expected-vs-actual checking.");
    $display("================================================================");
    $display("");
  endfunction

endclass

`endif
