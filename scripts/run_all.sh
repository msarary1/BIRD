#!/usr/bin/env bash
set -e

mkdir -p reports/student2_fixed

vcs -full64 -sverilog -f flist.f -l reports/student2_fixed/comp.log

./simv +TEST=smoke        -l reports/student2_fixed/sim_smoke.log
./simv +TEST=local        -l reports/student2_fixed/sim_local.log
./simv +TEST=remote       -l reports/student2_fixed/sim_remote.log
./simv +TEST=invalid      -l reports/student2_fixed/sim_invalid.log
./simv +TEST=backpressure -l reports/student2_fixed/sim_backpressure.log
./simv +TEST=reset        -l reports/student2_fixed/sim_reset.log

grep -i "ERROR\|FAIL\|PASS" reports/student2_fixed/sim_*.log || true
