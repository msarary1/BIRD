`ifndef BIRD_PKG_SV
`define BIRD_PKG_SV

`timescale 1ns/1ps

package bird_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  typedef byte unsigned u8_t;

  `include "tb/bird_transaction.sv"
  `include "tb/bird_driver.sv"
  `include "tb/bird_monitor.sv"
  `include "tb/bird_scoreboard.sv"
  `include "tb/bird_agent.sv"
  `include "tb/bird_env.sv"
  `include "tests/bird_smoke_test.sv"

endpackage

`endif
