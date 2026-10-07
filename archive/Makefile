# Makefile for SystemVerilog simulation
# Simulator: Verilator
# Waveform viewer: GTKWave
#
# Weston Nguyen

VERILATOR = verilator
GTKWAVE   = gtkwave
VERILATOR_FLAGS = --binary --trace --timing --Wall

RTL_DIR  = rtl
TB_DIR   = tb
OBJ_DIR  = obj_dir
WAVE_DIR = waves

# Create directories if they don't exist
$(shell mkdir -p $(WAVE_DIR))

# Common RTL files
CONVERT_DEFS = $(RTL_DIR)/Convert_Defs.sv
REFRESH_RTL = $(CONVERT_DEFS) $(RTL_DIR)/Refresh.sv
PRNG_RTL = $(CONVERT_DEFS) $(RTL_DIR)/PRNG.sv
REFRESH_PRNG_RTL = $(PRNG_RTL) $(RTL_DIR)/Refresh.sv
TTABLE_RTL = $(CONVERT_DEFS) $(RTL_DIR)/TTable.sv
MINI_REFRESH_RTL = $(CONVERT_DEFS) $(RTL_DIR)/TTable.sv $(RTL_DIR)/Refresh.sv $(RTL_DIR)/PRNG.sv $(RTL_DIR)/Mini_Refresh.sv
CORE_RTL = $(CONVERT_DEFS) $(RTL_DIR)/TTable.sv $(RTL_DIR)/Refresh.sv $(RTL_DIR)/PRNG.sv $(RTL_DIR)/Convert_Core.sv

# Testbenches
REFRESH_TB = $(TB_DIR)/Refresh_tb.sv
PRNG_TB = $(TB_DIR)/PRNG_tb.sv
REFRESH_PRNG_TB = $(TB_DIR)/Refresh_PRNG_tb.sv
TTABLE_TB = $(TB_DIR)/TTable_tb.sv
MINI_REFRESH_TB = $(TB_DIR)/Mini_Refresh_tb.sv
CORE_TB = $(TB_DIR)/Convert_Core_tb

# Targets
.PHONY: refresh prng refresh-prng ttable mini_refresh core clean clean-all help

# Refresh Tests
REFRESH_TOP = Refresh_tb
REFRESH_SIM = refresh_sim

refresh:
	@echo "\nRunning Refresh Tests"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(REFRESH_TOP) \
		$(REFRESH_RTL) \
		$(REFRESH_TB) \
		-o $(REFRESH_SIM)
	./$(OBJ_DIR)/$(REFRESH_SIM)

refresh-wave: refresh
	$(GTKWAVE) $(WAVE_DIR)/refresh.vcd

# PRNG Tests
PRNG_TOP = PRNG_tb
PRNG_SIM = prng_sim
REFRESH_PRNG_TOP = Refresh_PRNG_tb
REFRESH_PRNG_SIM = refresh_prng_sim

prng:
	@echo "\nRunning PRNG Tests"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(PRNG_TOP) \
		$(PRNG_RTL) \
		$(PRNG_TB) \
		-o $(PRNG_SIM)
	./$(OBJ_DIR)/$(PRNG_SIM)

prng-wave: prng
	$(GTKWAVE) $(WAVE_DIR)/prng.vcd

refresh-prng:
	@echo "\nRunning Refresh + PRNG Tests"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(REFRESH_PRNG_TOP) \
		$(REFRESH_PRNG_RTL) \
		$(REFRESH_PRNG_TB) \
		-o $(REFRESH_PRNG_SIM)
	./$(OBJ_DIR)/$(REFRESH_PRNG_SIM)

refresh-prng-wave: refresh-prng
	$(GTKWAVE) $(WAVE_DIR)/refresh_prng.vcd

# TTable Tests
TTABLE_TOP = TTable_tb
TTABLE_SIM = ttable_sim

ttable:
	@echo "\nRunning TTable Tests"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(TTABLE_TOP) \
		$(TTABLE_RTL) \
		$(TTABLE_TB) \
		-o $(TTABLE_SIM)
	./$(OBJ_DIR)/$(TTABLE_SIM)

ttable-wave: ttable
	$(GTKWAVE) $(WAVE_DIR)/ttable_tb.vcd

# Mini Refresh Tests
MINI_REFRESH_TOP = Mini_Refresh_tb
MINI_REFRESH_SIM = mini_refresh_sim

mini-refresh:
	@echo "\nRunning Mini_Refresh Tests"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(MINI_REFRESH_TOP) \
		$(MINI_REFRESH_RTL) \
		$(MINI_REFRESH_TB) \
		-o $(MINI_REFRESH_SIM)
	./$(OBJ_DIR)/$(MINI_REFRESH_SIM)

mini-refresh-wave: mini-refresh
	$(GTKWAVE) $(WAVE_DIR)/mini_refresh_core.vcd

# Core Tests
CORE_TOP = Convert_Core_tb
CORE_SIM = convert_core_sim

core:
	@echo "\nRunning Mini_Refresh Tests"
	$(VERILATOR) $(VERILATOR_FLAGS) \
		--top-module $(CORE_TOP) \
		$(CORE_RTL) \
		$(CORE_TB) \
		-o $(CORE_SIM)
	./$(OBJ_DIR)/$(CORE_SIM)

core-wave: core
	$(GTKWAVE) $(WAVE_DIR)/convert_core.vcd

# Clean targets
clean:
	@echo "Cleaning simulation files..."
	rm -rf $(OBJ_DIR)
	rm -f *.vcd
	rm -f *.fst
	rm -f $(WAVE_DIR)/*.vcd
	rm -f $(WAVE_DIR)/*.fst
	rm -f verilator_*.log

clean-all: clean
	@echo "Cleaning all generated files..."
	rm -f $(RTL_DIR)/*~
	rm -f $(TB_DIR)/*~
	rm -f *~

# Help
help:
	@echo "\nAvailable Targets"
	@echo "  make refresh       	- Run refresh testbench"
	@echo "  make refresh-wave  	- Run refresh and open GTKWave"
	@echo "  make prng       		- Run prng testbench"
	@echo "  make prng-wave  		- Run prng and open GTKWave"
	@echo "  make refresh-prng      - Run refresh-prng testbench"
	@echo "  make refresh-prng-wave - Run refresh-prng and open GTKWave"
	@echo "  make ttable       		- Run ttable testbench"
	@echo "  make ttable-wave  		- Run ttable and open GTKWave"
	@echo "  make mini       		- Run mini core testbench"
	@echo "  make mini-wave  		- Run mini core and open GTKWave"
	@echo "  make clean         	- Remove simulation files"
	@echo "  make clean-all     	- Remove all generated files"
	@echo "  make help          	- Show this help message"
	@echo ""


VERILATOR_FLAGS = --binary --trace --timing --Wall \
				-Wno-IMPORTSTAR \
				-Wno-UNUSEDSIGNAL \
				-Wno-IMPLICITSTATIC \
				-Wno-EOFNEWLINE