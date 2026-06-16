`ifndef BIRD_PKG_SV
`define BIRD_PKG_SV

`timescale 1ns/1ps

package bird_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  typedef byte unsigned u8_t;

  // Student 1 environment files
  `include "tb/bird_transaction.sv"
  `include "tb/bird_driver.sv"
  `include "tb/bird_monitor.sv"
  `include "tb/bird_scoreboard.sv"
  `include "tb/bird_coverage.sv"
  `include "tb/bird_agent.sv"
  `include "tb/bird_env.sv"

  // Student 2 sequences
  `include "seq/bird_local_seq.sv"
  `include "seq/bird_remote_seq.sv"
  `include "seq/bird_invalid_seq.sv"
  `include "seq/bird_backpressure_seq.sv"
  `include "seq/bird_reset_seq.sv"

  // Tests
  `include "tests/bird_smoke_test.sv"
  `include "tests/bird_local_test.sv"
  `include "tests/bird_remote_test.sv"
  `include "tests/bird_invalid_drop_test.sv"
  `include "tests/bird_backpressure_test.sv"
  `include "tests/bird_reset_test.sv"

endpackage

`endif
