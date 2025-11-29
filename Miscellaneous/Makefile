# Variables
GHDL = ghdl
VIEWER = surfer
FLAGS = --std=08 --ieee=synopsys
STOP_TIME = 100us

# Common Design File
DUT = pipelined_polyphase_filter.vhd

# --- CONFIGURATION 1: Single Pipelined Filter ---
TB1_FILE = tb_pipelined_polyphase_filter.vhd
TB1_ENTITY = tb_Pipelined_Polyphase_Filter
VCD1 = waveform_pipelined.vcd

# --- CONFIGURATION 2: Rational Resampler (Cascaded) ---
TB2_FILE = tb_rational_resampler.vhd
TB2_ENTITY = tb_Rational_Resampler
VCD2 = waveform_rational.vcd

.PHONY: all help clean pipelined rational view_pipelined view_rational

# Default Target
all: help

help:
	@echo "----------------------------------------------------------------"
	@echo "Available Commands:"
	@echo "  make view_pipelined   -> Run & View Single Filter (Upsampler)"
	@echo "  make view_rational    -> Run & View Rational Resampler (2/3)"
	@echo "  make clean            -> Delete all compiled files"
	@echo "----------------------------------------------------------------"

# ==============================================================================
# OPTION 1: Single Pipelined Filter
# ==============================================================================
pipelined: $(DUT) $(TB1_FILE)
	@echo "--- Analyzing Single Filter ---"
	$(GHDL) -a $(FLAGS) $(DUT) $(TB1_FILE)
	@echo "--- Elaborating Single Filter ---"
	$(GHDL) -e $(FLAGS) $(TB1_ENTITY)
	@echo "--- Running Single Filter Simulation ---"
	$(GHDL) -r $(FLAGS) $(TB1_ENTITY) --vcd=$(VCD1) --stop-time=$(STOP_TIME)

view_pipelined: pipelined
	@echo "--- Opening Surfer (Single) ---"
	$(VIEWER) $(VCD1)

# ==============================================================================
# OPTION 2: Rational Resampler (Cascaded)
# ==============================================================================
rational: $(DUT) $(TB2_FILE)
	@echo "--- Analyzing Rational Resampler ---"
	$(GHDL) -a $(FLAGS) $(DUT) $(TB2_FILE)
	@echo "--- Elaborating Rational Resampler ---"
	$(GHDL) -e $(FLAGS) $(TB2_ENTITY)
	@echo "--- Running Rational Simulation ---"
	$(GHDL) -r $(FLAGS) $(TB2_ENTITY) --vcd=$(VCD2) --stop-time=$(STOP_TIME)

view_rational: rational
	@echo "--- Opening Surfer (Rational) ---"
	$(VIEWER) $(VCD2)

# ==============================================================================
# Cleanup
# ==============================================================================
clean:
	@echo "--- Cleaning ---"
	$(GHDL) --clean
	rm -f *.cf *.vcd resampler_output.txt
	# The command below deletes everything except Makefile and .vhd files
	find . -maxdepth 1 -type f -not -name 'Makefile' -not -name '*.vhd' -delete


