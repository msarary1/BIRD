#!/usr/bin/env bash
set -e

mkdir -p reports/student2_coverage

rm -rf reports/student2_coverage/code_coverage.vdb
rm -rf reports/student2_coverage/code_coverage_report

vcs -full64 -sverilog \
  -cm line+cond+fsm+tgl+branch \
  -f flist.f \
  -l reports/student2_coverage/comp_cov.log

./simv +TEST=smoke        -cm line+cond+fsm+tgl+branch -cm_dir reports/student2_coverage/code_coverage.vdb -cm_name smoke        -l reports/student2_coverage/sim_cov_smoke.log
./simv +TEST=local        -cm line+cond+fsm+tgl+branch -cm_dir reports/student2_coverage/code_coverage.vdb -cm_name local        -l reports/student2_coverage/sim_cov_local.log
./simv +TEST=remote       -cm line+cond+fsm+tgl+branch -cm_dir reports/student2_coverage/code_coverage.vdb -cm_name remote       -l reports/student2_coverage/sim_cov_remote.log
./simv +TEST=invalid      -cm line+cond+fsm+tgl+branch -cm_dir reports/student2_coverage/code_coverage.vdb -cm_name invalid      -l reports/student2_coverage/sim_cov_invalid.log
./simv +TEST=backpressure -cm line+cond+fsm+tgl+branch -cm_dir reports/student2_coverage/code_coverage.vdb -cm_name backpressure -l reports/student2_coverage/sim_cov_backpressure.log
./simv +TEST=reset        -cm line+cond+fsm+tgl+branch -cm_dir reports/student2_coverage/code_coverage.vdb -cm_name reset        -l reports/student2_coverage/sim_cov_reset.log

urg -dir reports/student2_coverage/code_coverage.vdb \
    -format both \
    -report reports/student2_coverage/code_coverage_report \
    -l reports/student2_coverage/urg.log
