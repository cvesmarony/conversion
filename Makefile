# Cadence flow for ConvertCore: Genus synthesis + Xcelium RTL sim
SHELL := /bin/bash
include config.mk

MODE       ?= A2B
SHARES     ?= 2
CLK_PERIOD ?= 2.0
EFFORT     ?= medium
SMOKE      ?= 0
ARITH_NAME ?= ARITHMETIC
TTABLE_SRC ?= rtl/TTable.sv

# SMOKE=1: tiny parameters (Q=61, 6-bit) to validate the flow in minutes
ifeq ($(SMOKE),1)
H_WIDTH ?= 6
Q       ?= 61
else
H_WIDTH ?= 12
Q       ?= 3329
endif

ifeq ($(MODE),A2B)
H_MODE_SV := BOOLEAN
else ifeq ($(MODE),B2A)
H_MODE_SV := $(ARITH_NAME)
else
$(error MODE must be A2B or B2A)
endif

IO_DELAY := $(shell awk 'BEGIN{printf "%.4f", $(CLK_PERIOD)*0.3}')
UNCERT   := $(shell awk 'BEGIN{printf "%.4f", $(CLK_PERIOD)*0.05}')

TAG := $(MODE)_n$(SHARES)_w$(H_WIDTH)_$(CLK_PERIOD)ns
RUN := build/$(TAG)

RTL_FILES := rtl/Convert_Defs.sv rtl/Refresh.sv rtl/PRNG.sv $(TTABLE_SRC) rtl/ConvertCore.sv
TOP_SV    := $(RUN)/convert_top.sv
SDC       := $(RUN)/constraints.sdc

.PHONY: all wrapper synth sim sweep clean FORCE
all: synth
FORCE:

wrapper: $(TOP_SV)

$(TOP_SV): FORCE
	@mkdir -p $(RUN)
	@echo "import Convert_Defs::*;"                                         >  $@
	@echo "module convert_top ("                                           >> $@
	@echo "    input  logic clk, rst_n, start,"                            >> $@
	@echo "    input  logic [$(SHARES)-1:0][$(H_WIDTH)-1:0] x,"            >> $@
	@echo "    output logic busy, done,"                                   >> $@
	@echo "    output logic [$(SHARES)-1:0][$(H_WIDTH)-1:0] y"             >> $@
	@echo ");"                                                             >> $@
	@echo "  ConvertCore #(.H_WIDTH($(H_WIDTH)), .SHARES($(SHARES)), .Q($(Q)), .H_MODE($(H_MODE_SV))) u_core ("   >> $@
	@echo "    .clk(clk), .rst_n(rst_n), .start(start), .x(x), .busy(busy), .done(done), .y(y));" >> $@
	@echo "endmodule"                                                      >> $@

$(SDC): scripts/constraints.sdc.in FORCE
	@mkdir -p $(RUN)
	@sed -e 's/@CLK_PERIOD@/$(CLK_PERIOD)/g' -e 's/@IO_DELAY@/$(IO_DELAY)/g' -e 's/@UNCERT@/$(UNCERT)/g' $< > $@

synth: $(TOP_SV) $(SDC)
	@mkdir -p $(RUN)/reports $(RUN)/out results
	SYN_TOP=convert_top SYN_RUN=$(RUN) SYN_RTL="$(RTL_FILES) $(TOP_SV)" \
	  SYN_LIBDIR="$(LIB_DIR)" SYN_LIBS="$(LIB_FILES) $(EXTRA_LIBS)" SYN_LEFS="$(LEF_FILES)" \
	  SYN_EFFORT=$(EFFORT) $(GENUS) -no_gui -f scripts/synth.tcl -log $(RUN)/genus.log
	python3 scripts/parse_reports.py $(RUN) MODE=$(MODE) SHARES=$(SHARES) H_WIDTH=$(H_WIDTH) \
	  Q=$(Q) CLK_PERIOD=$(CLK_PERIOD) TTABLE=$(notdir $(TTABLE_SRC))

# RTL simulation of the self-checking testbench
sim:
	@mkdir -p build
	$(XRUN) -64bit -sv -clean -timescale 1ns/1ps -access +r -top convert_core_tb \
	  -xmlibdirname build/xcelium.d -logfile build/xrun.log \
	  rtl/Convert_Defs.sv rtl/Refresh.sv rtl/PRNG.sv rtl/TTable.sv rtl/ConvertCore.sv tb/convert_core_tb.sv

sweep:
	scripts/sweep.sh

clean:
	rm -rf build xcelium.d INCA_libs *.log *.key
