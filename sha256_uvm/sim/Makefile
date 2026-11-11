# =============================================================================
# SHA-256 UVM -- convenience wrapper around scripts/run_regression.py
# =============================================================================
# Examples:
#   make regression SIM=verilator UVM_HOME=$HOME/uvm/src SEEDS="1 2 3"
#   make regression SIM=questa   UVM_HOME=$HOME/uvm/src SEEDS="1 2"
#   make smoke
#   make eda
#   make clean
# =============================================================================

SIM      ?= verilator
SEEDS    ?= 1 2 3
UVM_HOME ?=
REG_ARGS ?=
PYTHON   ?= python3
ROOT     := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

UVM_ARG := $(if $(UVM_HOME),--uvm-home $(UVM_HOME),)

.PHONY: regression smoke selfcheck eda clean clean-all

regression:
	cd $(ROOT) && $(PYTHON) scripts/run_regression.py --sim $(SIM) $(UVM_ARG) \
		--seeds $(SEEDS) $(REG_ARGS)

smoke:
	cd $(ROOT) && $(PYTHON) scripts/run_regression.py --sim $(SIM) $(UVM_ARG) \
		--tests sha256_kat_test,sha256_closure_test --seeds 1

selfcheck:
	cd $(ROOT) && $(PYTHON) scripts/run_regression.py --sim $(SIM) $(UVM_ARG) \
		--tests sha256_kat_test --selfcheck --seeds 1

eda:
	cd $(ROOT) && $(PYTHON) scripts/make_eda_bundle.py

clean:
	cd $(ROOT) && rm -rf obj_dir sim/obj_dir sim/work_questa sim/simv sim/xcelium.d \
		sim/xrun.* sim/*.vcd sim/*.ucdb sim/*.log

clean-all: clean
	rm -rf $(ROOT)/results/*
