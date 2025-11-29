# ==============================================================================
# Makefile for Rational Resampler Simulation
# Tools: Icarus Verilog (iverilog), VVP, Surfer/GTKWave
# ==============================================================================

SRC_DIR = ./Sources
SIM_DIR = ./Sim
PY_DIR  = ./python_scripts
MEM_DIR = ./Mem_files
# ----------------------------------------------------------------------
# Tools
# ----------------------------------------------------------------------
CC = iverilog
SIM = vvp
VIEWER = surfer
PYTHON = python3

# Flags (-g2012 is required for SystemVerilog)
FLAGS = -g2012 -Wall

# Files
DUT = polyphase_filter.sv
TB  = tb_rational_resampler.sv
OUT = rational.vvp
VCD = waveform_rational.vcd
SCRIPT = plot_resampler.py

.PHONY: all COPY_FILES compile run view plot clean help

# ----------------------------------------------------------------------
# Default Target: copy, compile, run, view, plot
# ----------------------------------------------------------------------
all: COPY_FILES compile run view plot

# ----------------------------------------------------------------------
# Help
# ----------------------------------------------------------------------
help:
	@echo "----------------------------------------------------------------"
	@echo "Available Commands:"
	@echo "  make compile   -> Compile SystemVerilog files"
	@echo "  make run       -> Run Simulation (generates .vvp and .vcd)"
	@echo "  make view      -> Open waveform viewer"
	@echo "  make plot      -> Run Python analysis script"
	@echo "  make clean     -> Remove generated files"
	@echo "----------------------------------------------------------------"

# ----------------------------------------------------------------------
# Copy source files and memory files from new directories
# ----------------------------------------------------------------------
COPY_FILES:
	@echo "Copying SystemVerilog, memory, and Python files..."
	cp $(SRC_DIR)/polyphase_filter.sv ./
	cp $(SRC_DIR)/polyphase_resampler.sv ./
	cp $(SIM_DIR)/tb_rational_resampler.sv ./
	cp "$(PY_DIR)/plot_resampler.py" ./
	# Copy all memory files
	cp $(MEM_DIR)/*.mem ./
# ----------------------------------------------------------------------
# 1. Compile
# ----------------------------------------------------------------------
compile: COPY_FILES
	@echo "--- Compiling Rational Resampler ---"
	$(CC) $(FLAGS) -o $(OUT) polyphase_filter.sv polyphase_resampler.sv $(TB)
# ----------------------------------------------------------------------
# 2. Run Simulation
# ----------------------------------------------------------------------
run: compile
	@echo "--- Running Rational Simulation ---"
	$(SIM) $(OUT)

# ----------------------------------------------------------------------
# 3. View Waveform
# ----------------------------------------------------------------------
view: run
	@echo "--- Opening Waveform Viewer ---"
	@if [ -f $(VCD) ]; then \
		$(VIEWER) $(VCD) & \
	else \
		echo "Error: $(VCD) not found. Did you add \$dumpfile in your testbench?"; \
	fi

# ----------------------------------------------------------------------
# 4. Plot Data
# ----------------------------------------------------------------------
plot: run
	@echo "--- Running Python Analysis ---"
	$(PYTHON) $(SCRIPT)

clean:
	@echo "--- Cleaning ---"
	rm -f $(OUT) $(VCD) *.vvp *.out *.txt *.png
	rm -f polyphase_filter.sv polyphase_resampler.sv $(TB) $(SCRIPT)
	rm -f *.mem