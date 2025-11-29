`timescale 1ns / 1ps

module polyphase_resampler (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        i_valid,
    input  logic signed [15:0] i_data,
    output logic        o_valid,
    output logic signed [15:0] o_data
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int DATA_WIDTH = 16;
    localparam int COEFF_WIDTH = 16;
    
    // Stage 1: Upsampler (Interpolate by 2)
    localparam int L_FACTOR = 2;
    localparam int L_TAPS_TOTAL = 226;
    localparam int L_TAPS_PER_PHASE = L_TAPS_TOTAL / L_FACTOR; // 64

    // Stage 2: Downsampler (Decimate by 3)
    localparam int M_FACTOR = 3;
    localparam int M_TAPS_TOTAL = 3;
    localparam int M_TAPS_PER_PHASE = M_TAPS_TOTAL / M_FACTOR; // 5

    // =========================================================================
    // Interconnect Signals
    // =========================================================================
    logic signed [DATA_WIDTH-1:0] s1_data;
    logic                         s1_valid;

    // =========================================================================
    // 1. Upsampler (x2)
    //    Input: 9 MHz -> Output: 18 MHz
    //    Uses 128 Coeffs (64 taps per phase)
    // =========================================================================
    polyphase_filter #(
        .COEFF_FILE     ("interp_l2_226.mem"),
        .DATA_WIDTH     (DATA_WIDTH),
        .COEFF_WIDTH    (COEFF_WIDTH),
        .PHASES         (L_FACTOR),        // 2
        .TAPS_PER_PHASE (L_TAPS_PER_PHASE),// 64
        .IS_DECIMATION  (0)                // Interpolation
    ) u_upsampler (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_i    (i_valid),
        .data_i     (i_data),
        .valid_o    (s1_valid),
        .data_o     (s1_data)
    );

    // =========================================================================
    // 2. Downsampler (/3)
    //    Input: 18 MHz -> Output: 6 MHz
    //    Uses 15 Coeffs (5 taps per phase), Full Pass
    // =========================================================================
    polyphase_filter #(
        .COEFF_FILE     ("decim_m3_pass.mem"),
        .DATA_WIDTH     (DATA_WIDTH),
        .COEFF_WIDTH    (COEFF_WIDTH),
        .PHASES         (M_FACTOR),        // 3
        .TAPS_PER_PHASE (M_TAPS_PER_PHASE),// 5
        .IS_DECIMATION  (1)                // Decimation
    ) u_downsampler (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_i    (s1_valid), // Chained from Stage 1
        .data_i     (s1_data),
        .valid_o    (o_valid),
        .data_o     (o_data)
    );

endmodule


