`timescale 1ns / 1ps

module tb_rational_resampler;

    // =========================================================================
    // PARAMETERS & CONSTANTS
    // =========================================================================
    localparam int DATA_WIDTH = 16;
    localparam time CLK_PERIOD = 10ns; // 100 MHz Clock

    // Rational Resampling Config: 2/3
    // Stage 1: Interpolation (L=2)
    localparam int L_FACTOR = 2;
    localparam int L_TAPS_TOTAL = 226; 
    localparam int L_TAPS_PER_PHASE = L_TAPS_TOTAL / L_FACTOR; // 64
    
    // Stage 2: Decimation (M=3)
    localparam int M_FACTOR = 3;
    localparam int M_TAPS_TOTAL = 3;
    localparam int M_TAPS_PER_PHASE = M_TAPS_TOTAL / M_FACTOR; // 5

    // =========================================================================
    // SIGNALS
    // =========================================================================
    logic                        clk;
    logic                        rst_n;
    
    // Stage 0: Input
    logic                        s0_valid_i;
    logic signed [DATA_WIDTH-1:0] s0_data_i;

    // Stage 1: Intermediate (Output of x2 Upsampler)
    logic                        s1_valid;
    logic signed [DATA_WIDTH-1:0] s1_data;

    // Stage 2: Final Output (Output of /3 Downsampler)
    logic                        s2_valid;
    logic signed [DATA_WIDTH-1:0] s2_data;

    // File Handle
    integer fd;

    // =========================================================================
    // COMPONENT INSTANTIATION
    // =========================================================================

    // 1. Upsampler (x2) -> Uses 128 Coeffs (64 per phase)
    polyphase_filter #(
        .COEFF_FILE     ("interp_l2_226.mem"),
        .DATA_WIDTH     (DATA_WIDTH),
        .PHASES         (L_FACTOR),        // 2
        .TAPS_PER_PHASE (L_TAPS_PER_PHASE),// 64
        .IS_DECIMATION  (0)                // Interpolation
    ) u_upsampler (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(s0_valid_i),
        .data_i(s0_data_i),
        .valid_o(s1_valid),
        .data_o(s1_data)
    );

    // 2. Downsampler (/3) -> Uses 15 Coeffs (5 per phase), Full Pass
    polyphase_filter #(
        .COEFF_FILE     ("decim_m3_pass.mem"),
        .DATA_WIDTH     (DATA_WIDTH),
        .PHASES         (M_FACTOR),        // 3
        .TAPS_PER_PHASE (M_TAPS_PER_PHASE),// 5
        .IS_DECIMATION  (1)                // Decimation
    ) u_downsampler (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(s1_valid), // Chained from Stage 1
        .data_i(s1_data),
        .valid_o(s2_valid),
        .data_o(s2_data)
    );

    // =========================================================================
    // CLOCK GENERATION
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =========================================================================
    // STIMULUS GENERATION
    // =========================================================================
    initial begin
        // Simulation Constants
        real FS_IN = 9.0e6;      // 9 MHz
        real F1    = 1.0e6;      // 1 MHz Tone
        real F2    = 4.0e6;      // 4 MHz Tone (Near Nyquist)
        real SCALE_FACTOR = 15000.0;
        int  N_SAMPLES = 200;    // Number of input samples to generate

        real theta1 = 0.0;
        real theta2 = 0.0;
        real step1;
        real step2;
        real val_raw;
        int  val_int;
        real PI = 3.141592653589793;

        // Reset Sequence
        rst_n = 0;
        s0_valid_i = 0;
        s0_data_i = 0;
        #100;
        rst_n = 1;
        @(posedge clk);

        $display("------------------------------------------------");
        $display("Generating Two-Tone Signal");
        $display("Tone 1: 1 MHz");
        $display("Tone 2: 4 MHz");
        $display("Fs In : 9 MHz");
        $display("L=2 (128 Taps), M=3 (15 Taps Pass)");
        $display("------------------------------------------------");

        // Open Log File
        fd = $fopen("resampler_output.txt", "w");

        // Calculate Steps
        step1 = 2.0 * PI * F1 / FS_IN;
        step2 = 2.0 * PI * F2 / FS_IN;

        // Main Loop
        for (int i = 0; i < N_SAMPLES; i++) begin
            
            // 1. Math Generation
            val_raw = $sin(theta1) + $sin(theta2);
            val_int = int'(val_raw * SCALE_FACTOR);

            // Saturation
            if (val_int > 32767) val_int = 32767;
            if (val_int < -32768) val_int = -32768;

            // 2. Drive Input
            s0_valid_i <= 1'b1;
            s0_data_i  <= val_int[15:0];
            
            @(posedge clk);
            // 3. Pipeline Gaps (Matching VHDL "wait for k in 1 to 15")
            // This slows down data input to allow processing time
            s0_valid_i <= 1'b0;
            // s0_data_i  <= '0;  // if you remove it . it will cause like zero hold          
            repeat(15) @(posedge clk);

            // 4. Update Phase
            theta1 = theta1 + step1;
            if (theta1 > 2.0*PI) theta1 = theta1 - 2.0*PI;

            theta2 = theta2 + step2;
            if (theta2 > 2.0*PI) theta2 = theta2 - 2.0*PI;
        end

        // End Simulation
        #2000;
        $fclose(fd);
        $display("Simulation Finished.");
        $finish;
    end

    // =========================================================================
    // LOGGING PROCESS
    // =========================================================================
    always @(posedge clk) begin
        if (rst_n) begin
            // Log INPUT
            if (s0_valid_i) begin
                $fdisplay(fd, "IN:  %d", $signed(s0_data_i));
            end
            
            // Log INTERMEDIATE
            if (s1_valid) begin
                $fdisplay(fd, "MID: %d", $signed(s1_data));
            end

            // Log OUTPUT
            if (s2_valid) begin
                $fdisplay(fd, "OUT: %d", $signed(s2_data));
            end
        end
    end
        // =========================================================================
    // WAVEFORM DUMPING (Required for Icarus Verilog)
    // =========================================================================
    initial begin
        $dumpfile("waveform_rational.vcd"); // Must match Makefile VCD2 variable
        $dumpvars(0, tb_rational_resampler);
    end


endmodule

