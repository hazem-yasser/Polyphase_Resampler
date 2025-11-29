`timescale 1ns / 1ps

module polyphase_filter #(
    parameter  COEFF_FILE     = "decim_coeffs.mem", // File path for coefficients
    parameter int DATA_WIDTH        = 16,
    parameter int COEFF_WIDTH       = 16,
    parameter int PHASES            = 8,   // Previously CONVERSION_FACTOR
    parameter int TAPS_PER_PHASE    = 16,
    parameter bit IS_DECIMATION     = 0    // 0 for Interpolation, 1 for Decimation
)(
    input  logic                        clk,
    input  logic                        rst_n, // Added Reset
    input  logic                        valid_i,
    input  logic [DATA_WIDTH-1:0]       data_i,
    
    output logic                        valid_o,
    output logic [DATA_WIDTH-1:0]       data_o
);

    // Calculate gain shift based on phases (ceil(log2(phases)))
    localparam int GAIN_BITS = $clog2(PHASES);
    localparam int TOTAL_TAPS = PHASES * TAPS_PER_PHASE;

    // -------------------------------------------------------------
    // Coefficient Memory
    // -------------------------------------------------------------
    logic signed [COEFF_WIDTH-1:0] coeff_rom [0:TOTAL_TAPS-1];

    initial begin
        $readmemh(COEFF_FILE, coeff_rom);
    end

    // -------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------
    // Phase Counters
    int phase_counter;
    
    // Registers
    logic signed [DATA_WIDTH-1:0]       a_reg [0:TAPS_PER_PHASE-1]; // Input Pipeline
    logic signed [COEFF_WIDTH-1:0]      b_reg [0:TAPS_PER_PHASE-1]; // Coeff Latch
    
    // Pipeline Registers (MAC chain)
    // Size matches VHDL: CONVERSION_FACTOR * TAPS_PER_PHASE
    logic signed [2*DATA_WIDTH-1:0]     p_reg [0:TOTAL_TAPS-1];
    
    // Accumulator for Decimation
    logic signed [2*DATA_WIDTH-1:0]     product_sum;
    
    // FSM State for Interpolation
    typedef enum logic [1:0] {IDLE, GAP, PULSE} state_t;
    state_t state;
    
    logic active_cycle;

    // -------------------------------------------------------------
    // Main Process
    // -------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_o         <= 1'b0;
            data_o          <= '0;
            phase_counter   <= 0;
            state           <= IDLE;
            product_sum     <= '0;
            active_cycle    <= 1'b0;
            
            // Reset Arrays
            for (int i = 0; i < TAPS_PER_PHASE; i++) a_reg[i] <= '0;
            for (int i = 0; i < TAPS_PER_PHASE; i++) b_reg[i] <= '0;
            for (int i = 0; i < TOTAL_TAPS; i++)     p_reg[i] <= '0;
            
        end else begin
            
            // Default Assignments
            valid_o <= 1'b0;
            active_cycle <= 1'b0;

            // =========================================================
            // MODE 1: INTERPOLATION (IS_DECIMATION = 0)
            // =========================================================
            if (!IS_DECIMATION) begin
                
                // --- FSM Control ---
                case (state)
                    IDLE: begin
                        phase_counter <= 0;
                        if (valid_i) begin
                            active_cycle    <= 1'b1; // Process Phase 0 immediately
                            phase_counter   <= 1;    // Next is Phase 1
                            state           <= GAP;
                        end
                    end

                    GAP: begin
                        active_cycle <= 1'b0; // Wait state
                        state        <= PULSE;
                    end

                    PULSE: begin
                        active_cycle <= 1'b1;
                        if (phase_counter == PHASES - 1) begin
                            state           <= IDLE;
                            phase_counter   <= 0;
                        end else begin
                            phase_counter   <= phase_counter + 1;
                            state           <= GAP;
                        end
                    end
                endcase

                // --- Processing Logic ---
                if (active_cycle) begin
                    valid_o <= 1'b1;
                    
                    // Filter Structure
                    for (int m = 0; m < PHASES; m++) begin
                        for (int t = 0; t < TAPS_PER_PHASE; t++) begin
                            
                            // 1. Input Latching (Only on Phase 0)
                            // Note: Logic logic uses current_phase derived from FSM previous state, 
                            // simpler to use the 'active_cycle' trigger logic implied by VHDL.
                            // If we are starting IDLE->GAP, phase is effectively 0 for math.
                            // If we are in PULSE, use current phase_counter.
                            
                            // We use temporary variable for current processing phase for clarity
                            int current_p;
                            if (state == IDLE) current_p = 0; 
                            else current_p = phase_counter; // In PULSE state

                            if (current_p == 0) begin
                                a_reg[t] <= $signed(data_i);
                            end
                            
                            // 2. Load Coefficient
                            // Index = t * PHASES + current_p
                            b_reg[t] <= coeff_rom[t*PHASES + current_p];

                            // 3. MAC Operation
                            // Index Mapping: t*PHASES + (PHASES-1) is the "Top" of the column for tap 't'
                            if (t == TAPS_PER_PHASE - 1) begin
                                p_reg[t*PHASES + (PHASES-1)] <= a_reg[t] * b_reg[t];
                            end else begin
                                p_reg[t*PHASES + (PHASES-1)] <= (a_reg[t] * b_reg[t]) + p_reg[(t+1)*PHASES];
                            end

                            // 4. Shift Pipeline
                            if (m < PHASES - 1) begin
                                p_reg[t*PHASES + m] <= p_reg[t*PHASES + m + 1];
                            end
                        end
                    end
                    
                    // Output Scaling
                    data_o <= p_reg[0][2*DATA_WIDTH-2-GAIN_BITS -: DATA_WIDTH];
                end
            end 

            // =========================================================
            // MODE 2: DECIMATION (IS_DECIMATION = 1)
            // =========================================================
            else begin 
                
                // --- Control Logic ---
                if (valid_i) begin
                    active_cycle <= 1'b1;
                    if (phase_counter > 0) 
                        phase_counter <= phase_counter - 1;
                    else 
                        phase_counter <= PHASES - 1;
                end

                // --- Processing Logic ---
                if (active_cycle) begin
                    // Note: In decimation, we use the phase_counter state *before* the update 
                    // inside the math loop effectively, but since we updated it above non-blocking,
                    // we need the logic to align. 
                    // The VHDL used variables to use "current" value before update. 
                    // To match VHDL: if phase was 0, it wraps to 7. 
                    
                    // We need the value BEFORE the decrement above took effect? 
                    // No, standard coding: use a temporary or derived logic.
                    // Let's rely on the previous cycle value logic by using immediate logic if needed.
                    // Actually, simpler: Recalculate 'current' conceptually.
                    
                    int current_p;
                    // Reverse the decrement logic to find what the phase IS for this data
                    if (phase_counter == PHASES - 1) current_p = 0; 
                    else current_p = phase_counter + 1;
                    
                    // Wait, simpler approach:
                    // If we just entered valid_i, the 'phase_counter' register holds the CURRENT phase.
                    // We decrement it for the NEXT cycle.
                    // So we use 'phase_counter' (the value before the clock edge update).
                    
                    // But in non-blocking assignments, reading 'phase_counter' reads the OLD value.
                    // So simply using phase_counter here works perfectly.
                    
                    for (int m = 0; m < PHASES; m++) begin
                        for (int t = 0; t < TAPS_PER_PHASE; t++) begin
                            
                            // 1. Always latch input
                            a_reg[t] <= $signed(data_i);
                            
                            // 2. Load Coefficient
                            b_reg[t] <= coeff_rom[t*PHASES + phase_counter];

                            // 3. MAC
                            if (t == TAPS_PER_PHASE - 1) begin
                                p_reg[t*PHASES + (PHASES-1)] <= a_reg[t] * b_reg[t];
                            end else begin
                                p_reg[t*PHASES + (PHASES-1)] <= (a_reg[t] * b_reg[t]) + p_reg[(t+1)*PHASES];
                            end

                            // 4. Shift
                            if (m < PHASES - 1) begin
                                p_reg[t*PHASES + m] <= p_reg[t*PHASES + m + 1];
                            end
                        end
                    end

                    // Accumulator Logic
                    if (phase_counter > 0) begin
                        product_sum <= p_reg[0] + product_sum;
                    end else begin
                        // Phase 0 reached (End of Block)
                        // Output Result
                        // (p_reg[0] + product_sum)
                        logic signed [2*DATA_WIDTH-1:0] final_val;
                        final_val = p_reg[0] + product_sum;
                        
                        data_o <= final_val[2*DATA_WIDTH-2 -: DATA_WIDTH];
                        valid_o <= 1'b1;
                        product_sum <= '0;
                    end
                end
            end 
        end
    end

endmodule

