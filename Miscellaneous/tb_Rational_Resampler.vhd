library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.textio.all;

entity tb_Rational_Resampler is
end tb_Rational_Resampler;

architecture Behavioral of tb_Rational_Resampler is

    -- =========================================================================
    -- COMPONENT DECLARATION
    -- =========================================================================
    component Pipelined_Polyphase_Filter is
        Generic(
            DATA_WIDTH          : integer := 16;
            CONVERSION_FACTOR   : integer := 8;
            TAPS_PER_PHASE      : integer := 16;
            DECIMATION_ARCH     : boolean := false
        );
        Port (
            clk     : in STD_LOGIC;
            valid_i : in STD_LOGIC;
            valid_o : out STD_LOGIC;
            data_i  : in std_logic_vector(DATA_WIDTH-1 downto 0);
            data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    -- =========================================================================
    -- CONFIGURATION CONSTANTS
    -- =========================================================================
    constant CLK_PERIOD   : time := 10 ns;
    constant DATA_WIDTH   : integer := 16;
    
    -- Rational Resampling Config: 2/3
    constant L_FACTOR : integer := 2; -- Upsample
    constant M_FACTOR : integer := 3; -- Downsample
    
    constant L_TAPS : integer := 64; 
    constant M_TAPS : integer := 42; 

    -- =========================================================================
    -- SIGNALS
    -- =========================================================================
    signal clk          : std_logic := '0';
    signal sim_running  : boolean := true;

    -- Stage 0: Input
    signal s0_valid_i   : std_logic := '0';
    signal s0_data_i    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Stage 1: Intermediate (Output of x2 Upsampler)
    signal s1_valid     : std_logic; 
    signal s1_data      : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Stage 2: Final Output (Output of /3 Downsampler)
    signal s2_valid     : std_logic; 
    signal s2_data      : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Counters
    signal sample_idx   : integer := 0;

begin

    -- =========================================================================
    -- INSTANTIATION: CASCADED FILTERS
    -- =========================================================================

    -- 1. Upsampler (x2)
    U_UPSAMPLER: Pipelined_Polyphase_Filter
        Generic Map (
            DATA_WIDTH        => DATA_WIDTH,
            CONVERSION_FACTOR => L_FACTOR, 
            TAPS_PER_PHASE    => L_TAPS,   
            DECIMATION_ARCH   => false -- Interpolation
        )
        Port Map (
            clk     => clk,
            valid_i => s0_valid_i,
            valid_o => s1_valid,
            data_i  => s0_data_i,
            data_o  => s1_data
        );

    -- 2. Downsampler (/3)
    U_DOWNSAMPLER: Pipelined_Polyphase_Filter
        Generic Map (
            DATA_WIDTH        => DATA_WIDTH,
            CONVERSION_FACTOR => M_FACTOR, 
            TAPS_PER_PHASE    => M_TAPS,   
            DECIMATION_ARCH   => true  -- Decimation
        )
        Port Map (
            clk     => clk,
            valid_i => s1_valid, -- Connects to s1
            valid_o => s2_valid,
            data_i  => s1_data,  -- Connects to s1
            data_o  => s2_data
        );

    -- =========================================================================
    -- CLOCK GENERATION
    -- =========================================================================
    clk_process : process
    begin
        while sim_running loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- =========================================================================
    -- STIMULUS GENERATION
    -- =========================================================================
    stim_process : process
        -- Simulation Settings
        constant N_SAMPLES : integer := 8192*2;
        constant FS_IN     : real := 9.0e6; -- 9 MHz

        -- Frequencies
        constant F1 : real := 3.0e5; -- 1 MHz
        constant F2 : real := 4.0e6; -- 4 MHz (Will be filtered)

        -- SCALING FACTOR CALCULATION
        -- Max theoretical amplitude = 1.0 (from 1MHz) + 0.7 (from 4MHz) = 1.7
        -- Max integer (16-bit signed) = 32767
        -- We scale 1.7 to roughly 30,000 to use almost full range.
        -- constant SCALE_FACTOR : real := (30000.0 / 2); 
        constant SCALE_FACTOR : real := (15000.0); 
        -- Loop Variables
        variable theta1  : real := 0.0;
        variable theta2  : real := 0.0;
        variable step1   : real;
        variable step2   : real;
        variable val_raw : real;
        variable val_int : integer;

    begin
        wait for 100 ns;
        wait until rising_edge(clk);

        report "------------------------------------------------";
        report "Generating Two-Tone Signal";
        report "Tone 1: 1 MHz (Amp 1.0)";
        report "Tone 2: 4 MHz (Amp 0.7)";
        report "Fs In : 9 MHz";
        report "Count : " & integer'image(N_SAMPLES);
        report "Scale : Mapped peak 1.7 to ~30000";
        report "------------------------------------------------";

        -- Calculate Phase Increments
        step1 := 2.0 * MATH_PI * F1 / FS_IN;
        step2 := 2.0 * MATH_PI * F2 / FS_IN;

        for i in 0 to N_SAMPLES-1 loop
            
            -- 1. Calculate Float Value
            val_raw := sin(theta1) +  sin(theta2);
            
            -- 2. Convert to Fixed Point
            val_int := integer(val_raw * SCALE_FACTOR);
            
            -- Saturation Logic (Safety)
            if val_int > 32767 then val_int := 32767; end if;
            if val_int < -32768 then val_int := -32768; end if;

            -- 3. Drive Signals
            s0_valid_i <= '1';
            s0_data_i  <= std_logic_vector(to_signed(val_int, DATA_WIDTH));
            sample_idx <= i;

            wait until rising_edge(clk);

            -- 4. Pipeline Gap (Gap between input samples)
            -- We wait 15 cycles to ensure the Upsampler (L=2) and Downsampler (M=3)
            -- have time to process the "bursts".
            s0_valid_i <= '0';
            -- s0_data_i  <= (others => '0'); --if done mean hold at input samples

            for k in 1 to 15 loop
                wait until rising_edge(clk);
            end loop;

            -- 5. Advance Phase
            theta1 := theta1 + step1;
            if theta1 > 2.0*MATH_PI then theta1 := theta1 - 2.0*MATH_PI; end if;

            theta2 := theta2 + step2;
            if theta2 > 2.0*MATH_PI then theta2 := theta2 - 2.0*MATH_PI; end if;

        end loop;

        -- Wait for pipeline flush
        wait for 2000 ns;
        sim_running <= false;
        report "Simulation Finished.";
        wait;
    end process;

    -- =========================================================================
    -- FILE LOGGING
    -- =========================================================================
    log_process : process(clk)
        file file_ptr : text open write_mode is "resampler_output.txt";
        variable line_el  : line;
        variable v_in  : integer;
        variable v_mid : integer;
        variable v_out : integer;
    begin
        if rising_edge(clk) then
            -- Log INPUT
            if s0_valid_i = '1' then
                v_in := to_integer(signed(s0_data_i));
                write(line_el, string'("IN:  "));
                write(line_el, v_in);
                writeline(file_ptr, line_el);
            end if;

            -- Log MID (Upsampled)
            if s1_valid = '1' then
                v_mid := to_integer(signed(s1_data));
                write(line_el, string'("MID: "));
                write(line_el, v_mid);
                writeline(file_ptr, line_el);
            end if;

            -- Log OUT (Final)
            if s2_valid = '1' then
                v_out := to_integer(signed(s2_data));
                write(line_el, string'("OUT: "));
                write(line_el, v_out);
                writeline(file_ptr, line_el);
            end if;
        end if;
    end process;

end Behavioral;


