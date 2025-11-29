# Polyphase Rational Resampler (SystemVerilog + Python)

  

This repository contains a fully working polyphase rational resampler, implemented in

SystemVerilog (RTL) + Icarus Verilog + Python (NumPy/Matplotlib).

  

The design performs multi-rate DSP using a polyphase FIR resampling structure with

interpolation L = 2 and decimation M = 3, including automated simulation, waveform

generation, and Python-based analysis.

---

# 📁 Repository Structure

  

The project is organized into clean subdirectories, but the Makefile requires all essential RTL, memory, and Python files to also exist in the top-level directory.

  

This is intentional and allows simple commands like:

```
make all
make view
make plot
make clean
```

### ✔ Top-Level Directory (Used by Makefile)

  

Contains the files required directly by simulation:

```
polyphase_resampler/
├── Makefile
├── polyphase_filter.sv
├── polyphase_resampler.sv
├── tb_rational_resampler.sv
├── plot_resampler.py
├── decim_m3_pass.mem
├── interp_l2_128.mem
├── interp_l2_226.mem
└── (simulation outputs appear here)
```

These files must remain in the root directory because the Makefile copies them from the subdirectories and uses no explicit file paths during compilation, ensuring simple and reproducible simulation.

---

# 📂 Clean Subdirectory Layout

  

To keep the project organized:

```
Sources/          # RTL design files (.sv)
Sim/              # Testbenches (.sv)
Mem_files/        # Memory coefficient files (.mem)
results/          # Plots, VCDs, and text outputs
python_scripts/   # Python utilities
Miscellaneous/    # Old VHDL versions, notebooks, archived files
```

Benefits of this hybrid structure:

- Clean, professional organization
    
- Zero breakage of the Makefile
    
- Easy scaling for larger DSP/RTL projects
    

---

# ⚙️ Makefile Workflow

  

The Makefile supports the full simulation + analysis pipeline:

  

### 1️⃣ Copy, Compile, and Run Simulation

```
make all
```

This automatically:

- Copies polyphase_filter.sv, polyphase_resampler.sv, testbench, Python script, and all .mem files to the working directory.
    
- Compiles the SV design and testbench.
    
- Runs the simulation and generates waveform and output text files.
    

  

### 2️⃣ View Waveforms (Surfer / GTKWave)

```
make view
```

Opens waveform_rational.vcd.

  

### 3️⃣ Generate Python Plots (Time + Frequency Domain)

```
make plot
```

Runs plot_resampler.py to generate plots from resampler_output.txt.

  

### 4️⃣ Clean All Generated Files

```
make clean
```

Removes compiled outputs, VCDs, PNG plots, copied .sv, .py, and .mem files.

---

# 🚀 Features

- Polyphase FIR structure for efficient L/M resampling
    
- Rational resampling L = 2, M = 3
    
- Bit-true simulation using Icarus Verilog
    
- Automatic output file generation:
    
    - resampler_output.txt
        
    - waveform_rational.vcd
        
    - freq_domain.png
        
    - time_domain.png
        
    
- Python post-processing integrated with Makefile
    
- Organized directory hierarchy without breaking the build flow
    

---

# 📊 Output Files

  

Simulation and Python scripts generate:

```
results/
├── waveform_rational.vcd  # waveform dump
├── freq_domain.png         # FFT plot
├── time_domain.png         # time-domain plot
└── resampler_output.txt    # filtered + resampled samples
```

---

# 🧰 Requirements

- Icarus Verilog (iverilog)
    
- vvp
    
- Python 3
    
    - numpy
        
    - matplotlib
        
    
- Surfer / GTKWave (optional waveform viewer)
    

---

# 📚 Notes

- The Miscellaneous/ folder contains previous VHDL implementations (for comparison).
    
- Copying RTL, memory, and Python files to the top-level directory is intentional for Makefile compatibility.
    
- Subdirectories contain a maintainable, scalable project structure for long-term use.
    

---

# 📄 License

  

This project is for educational and research purposes.
