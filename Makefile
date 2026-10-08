SYNOPSYS = licenses/synopsys
CADENCE = licenses/cadence

MODULE = . /usr/share/Modules/init/sh; module load $(SYNOPSYS) $(CADENCE)

GENUS   = tools/genus/21.18
INNOVUS = tools/innovus/21.18

XCELIUM   = tools/xcelium/23.03
VERISIUM  = tools/verisium/24.09
#####################################
#          INVOKE TOOLS             #
#####################################

#####################################
#COMPILE = cd work; $(MODULE) $(DC); time dc_shell-xg-t -64bit
COMPILE = cd work; $(MODULE) $(GENUS); time genus
PNR     = cd work; $(MODULE) $(INNOVUS); time innovus
XRUN    = cd work; $(MODULE) $(XCELIUM) $(VERISIUM); time xrun
#####################################
#              SETUP                #
#####################################
RUNDIR  = $(PWD)
LOGS    = $(RUNDIR)/logs
SCRIPTS = $(RUNDIR)/scripts
DATE    = "`date '+%m_%d_%H_%M'`"

MODE        ?= A2B
SHARES      ?= 2
CLK_PERIOD  ?= 1.0
SYN_OPT     ?= 1
CG          ?= 0
SMOKE       ?= 0
ARITH_NAME  ?= ZQ

CORE_MODULE ?= Convert_Core
CORE_FILE   ?= Convert_Core.sv
CORE_RST    ?= rst_n
TTABLE_FILE ?= TTable.sv

SRAM        ?= 0
SRAM_CELL   ?=
SRAM_DEPTH  ?= 4096
SRAM_WIDTH  ?= 24

# SMOKE=1: tiny parameters (Q=61, 6-bit) to validate the flow in minutes
ifeq ($(SMOKE),1)
H_WIDTH ?= 6
Q       ?= 61
else
H_WIDTH ?= 12
Q       ?= 3329
endif

ifeq ($(MODE),A2B)
H_MODE_SV = BOOLEAN
else ifeq ($(MODE),B2A)
H_MODE_SV = $(ARITH_NAME)
else
$(error MODE must be A2B or B2A)
endif

ifeq ($(SRAM),1)
ifeq ($(strip $(SRAM_CELL)),)
$(error SRAM=1 needs SRAM_CELL=<macro cell name>; see README)
endif
TTABLE_FILE = TTable_macro.sv
SRAM_FILES  = sram_1rw.sv
VC_DEFS     = +define+USE_SRAM_MACRO +define+SRAM_CELL=$(SRAM_CELL) +define+SRAM_DEPTH=$(SRAM_DEPTH) +define+SRAM_WIDTH=$(SRAM_WIDTH)
SRAM_TAG    = _sram
endif

TAG     = $(MODE)_n$(SHARES)_w$(H_WIDTH)_$(CLK_PERIOD)ns
DATA    = $(RUNDIR)/data/$(TAG)
REPORTS = $(RUNDIR)/reports/sweep/$(TAG)
TOP_SV  = $(DATA)/convert_top.sv
VC      = $(DATA)/sweep.vc
RTL_SRC = Convert_Defs.sv Refresh.sv PRNG.sv $(TTABLE_FILE) $(CORE_FILE)

.PHONY: tell_date sim sim_conv sim_conv_gui compile synth wrapper sweep dirs clean genus FORCE
FORCE:

#####################################
#              FRONT                #
#####################################
tell_date:
	echo $(DATE)

sim: dirs
	$(XRUN) -sv -gui -64bit -lwdgen -access rwc -verisium +incdir+../rtl -top Convert_Core_tb -f ../rtl/convert.vc -l ./simulation.log

sim_conv: dirs
	$(XRUN) -sv -64bit -access +r -timescale 1ns/1ps +define+CORE_MODULE=$(CORE_MODULE)+CORE_RST=$(CORE_RST) -top Convert_Core_tb -f ../rtl/convert.vc -l ./simulation.log

sim_conv_sram: dirs
	$(XRUN) -sv -64bit -access +r -timescale 1ns/1ps +nospecify +notimingchecks +define+USE_SRAM_MACRO+SRAM_CELL=$(SRAM_CELL)+SRAM_DEPTH=$(SRAM_DEPTH)+SRAM_WIDTH=$(SRAM_WIDTH)+SRAM_RTSEL_V=$(SRAM_RTSEL_V)+SRAM_WTSEL_V=$(SRAM_WTSEL_V)+CORE_MODULE=$(CORE_MODULE)+CORE_RST=$(CORE_RST) -top Convert_Core_tb -f ../rtl/convert_sram.vc $(SRAM_VMODEL) -l ./simulation.log

sim_conv_gui: dirs
	$(XRUN) -sv -gui -64bit -lwdgen -access rwc -verisium -timescale 1ns/1ps +define+CORE_MODULE=$(CORE_MODULE)+CORE_RST=$(CORE_RST) -top Convert_Core_tb -f ../rtl/convert.vc -l ./simulation.log

compile: dirs
	$(COMPILE) -files $(SCRIPTS)/compile.tcl -log compile | tee $(LOGS)/compile.log

# Parameterised synthesis:  make synth MODE=B2A SHARES=3 CLK_PERIOD=1.0 [SMOKE=1] [SYN_OPT=0]
# Uses the same tech/mmmc setup as compile.tcl (scripts/sweep_compile.tcl).
synth: dirs $(TOP_SV) $(VC)
	@mkdir -p $(REPORTS) $(RUNDIR)/results
	export SYN_TOP=convert_top SYN_RST=rst_n SYN_VC=../data/$(TAG)/sweep.vc SYN_DATA=../data/$(TAG) \
	       SYN_REPORTS=../reports/sweep/$(TAG) SYN_CLK_NS=$(CLK_PERIOD) SYN_OPT=$(SYN_OPT); \
	  $(COMPILE) -files $(SCRIPTS)/sweep_compile.tcl -log synth_$(TAG) | tee $(LOGS)/synth_$(TAG).log
	python3 $(SCRIPTS)/parse_reports.py $(REPORTS) MODE=$(MODE) SHARES=$(SHARES) H_WIDTH=$(H_WIDTH) \
	  Q=$(Q) CLK_PERIOD=$(CLK_PERIOD) TTABLE=$(TTABLE_FILE)

wrapper: dirs $(TOP_SV) $(VC)

# thin top that fixes the parameters and exposes clk / rst_n / start / x / busy / done / y
$(TOP_SV): FORCE
	@mkdir -p $(DATA)
	@echo "import Convert_Defs::*;"                                         >  $@
	@echo "module convert_top ("                                           >> $@
	@echo "    input  logic clk, rst_n, start,"                            >> $@
	@echo "    input  logic [$(SHARES)-1:0][$(H_WIDTH)-1:0] x,"            >> $@
	@echo "    output logic busy, done,"                                   >> $@
	@echo "    output logic [$(SHARES)-1:0][$(H_WIDTH)-1:0] y"             >> $@
	@echo ");"                                                             >> $@
	@echo "  $(CORE_MODULE) #(.H_WIDTH($(H_WIDTH)), .SHARES($(SHARES)), .Q($(Q)), .H_MODE($(H_MODE_SV))) u_core ("   >> $@
	@echo "    .clk(clk), .$(CORE_RST)(rst_n), .start(start), .x(x), .busy(busy), .done(done), .y(y));" >> $@
	@echo "endmodule"                                                      >> $@

# generated file list, same header as scripts/rtl_src/macro.vc; paths relative to work/
$(VC): FORCE
	@mkdir -p $(DATA)
	@echo "+libext+.v+.sv"                          >  $@
	@echo "+define+SYNTHESIS"                       >> $@
	@for f in $(RTL_SRC); do echo "../rtl/$$f" >> $@; done
	@echo "../data/$(TAG)/convert_top.sv"           >> $@
	@echo "+incdir+/ee/166/CHIPKIT/ip/rtl_inc/"     >> $@

sweep:
	$(SCRIPTS)/sweep.sh

#####################################
#         CREATE DIRECTORIES        #
#####################################
dirs:
	@mkdir -p work/
	@mkdir -p $(LOGS)
	@mkdir -p data/
	@mkdir -p reports/
	@mkdir -p reports/compile
	@mkdir -p reports/sweep

clean:
	@echo "Cleaning example directory ..."
	@/bin/rm -rf work/.[a-zA-Z]*
	@/bin/rm -rf work*
	@/bin/rm -rf $(LOGS)
	@/bin/rm -rf data
	@/bin/rm -rf reports
genus:
	$(COMPILE)
