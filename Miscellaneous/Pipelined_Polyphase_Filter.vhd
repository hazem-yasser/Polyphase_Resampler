library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real.all;

entity Pipelined_Polyphase_Filter is
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
end Pipelined_Polyphase_Filter;

architecture Behavioral of Pipelined_Polyphase_Filter is

    constant Gain : integer := integer(ceil(log2(real(CONVERSION_FACTOR))));

    -- FSM for Interpolation
    type state_type is (IDLE, GAP, PULSE);
    signal state : state_type := IDLE;
    
    signal phase_counter : integer range 0 to CONVERSION_FACTOR-1 := 0;

    -- Data Pipeline
    type p_reg_array is array (0 to CONVERSION_FACTOR*Taps_Per_Phase-1) of signed(2*Data_Width-1 downto 0);
    signal p_reg : p_reg_array :=(others=>(others=>'0'));

    -- Input Registers
    type reg_array is array (0 to Taps_Per_Phase-1) of signed(DATA_WIDTH-1 downto 0);
    signal a_reg : reg_array :=(others=>(others=>'0'));
    signal b_reg : reg_array :=(others=>(others=>'0'));

    -- Decimation Specific Accumulators
    signal product_sum : signed(2*Data_Width-1 downto 0) := (others=>'0');
    
    -- Coefficients
    type coefficients is array (0 to 127) of signed(15 downto 0);     
-- Filter: Low Pass, 128 Taps
-- Fs = 9 MHz, Fc = 1.5 MHz
-- Max Amplitude scaled to 16-bit signed max (0x7FFF)
signal coeff: coefficients :=( 
    x"0000", x"FFFF", x"FFFE", x"FFFE", x"FFFF", x"0002", x"0006", x"000C", 
    x"0013", x"001B", x"0023", x"002A", x"002E", x"002F", x"002C", x"0023", 
    x"0016", x"0002", x"FFE8", x"FFC8", x"FFA3", x"FF7B", x"FF52", x"FF29", 
    x"FF04", x"FEE5", x"FED1", x"FECB", x"FED5", x"FEF1", x"FF21", x"FF66", 
    x"FFC0", x"002F", x"00B0", x"0141", x"01DE", x"0281", x"0326", x"03C6", 
    x"045B", x"04DE", x"0548", x"0594", x"05BC", x"05BC", x"058D", x"052B", 
    x"0494", x"03C2", x"02B4", x"0170", x"FFFA", x"FE53", x"FC7D", x"FA7D", 
    x"F858", x"F614", x"F3B8", x"F14C", x"EED7", x"EC62", x"E9F4", x"E795", 
    x"E795", x"E9F4", x"EC62", x"EED7", x"F14C", x"F3B8", x"F614", x"F858", 
    x"FA7D", x"FC7D", x"FE53", x"FFFA", x"0170", x"02B4", x"03C2", x"0494", 
    x"052B", x"058D", x"05BC", x"05BC", x"0594", x"0548", x"04DE", x"045B", 
    x"03C6", x"0326", x"0281", x"01DE", x"0141", x"00B0", x"002F", x"FFC0", 
    x"FF66", x"FF21", x"FEF1", x"FED5", x"FECB", x"FED1", x"FEE5", x"FF04", 
    x"FF29", x"FF52", x"FF7B", x"FFA3", x"FFC8", x"FFE8", x"0002", x"0016", 
    x"0023", x"002C", x"002F", x"002E", x"002A", x"0023", x"001B", x"0013", 
    x"000C", x"0006", x"0002", x"FFFF", x"FFFE", x"FFFE", x"FFFF", x"0000"
);


begin

    process(clk)
        variable active_cycle  : boolean;
        variable current_phase : integer;
        variable decim_out_val : signed(2*DATA_WIDTH-1 downto 0);
    begin
        if rising_edge (clk) then   
            
            active_cycle := false;
            valid_o <= '0';
            current_phase := phase_counter; 
            decim_out_val := (others => '0'); -- Default

            -----------------------------------------------------------------------
            -- MODE 1: INTERPOLATION (Upsampling)
            -----------------------------------------------------------------------
            if DECIMATION_ARCH = false then
                
                -- Pulse-Gap FSM
                case state is
                    when IDLE =>
                        if valid_i = '1' then
                            active_cycle := true;
                            current_phase := 0; 
                            phase_counter <= 1; 
                            state <= GAP;       
                        else
                            phase_counter <= 0;
                        end if;

                    when GAP =>
                        active_cycle := false;
                        state <= PULSE; 

                    when PULSE =>
                        active_cycle := true;
                        current_phase := phase_counter;
                        
                        if phase_counter = CONVERSION_FACTOR - 1 then
                            state <= IDLE;
                            phase_counter <= 0;
                        else
                            phase_counter <= phase_counter + 1;
                            state <= GAP; 
                        end if;
                end case;

                -- Interpolation Processing
                if active_cycle then
                    valid_o <= '1';
                    
                    for m in 0 to CONVERSION_FACTOR-1 loop                  
                        for t in 0 to Taps_Per_Phase-1 loop                 
                            if current_phase = 0 then
                                a_reg(t) <= signed(data_i);
                            end if;
                            b_reg(t) <= coeff(t*CONVERSION_FACTOR + current_phase);
                            if t = Taps_Per_Phase-1 then        
                                p_reg(t*CONVERSION_FACTOR + CONVERSION_FACTOR-1) <= a_reg(t) * b_reg(t);
                            else
                                p_reg(t*CONVERSION_FACTOR + CONVERSION_FACTOR-1) <= a_reg(t) * b_reg(t) + p_reg((t+1)*CONVERSION_FACTOR);
                            end if;
                            if m < CONVERSION_FACTOR-1 then
                                p_reg(t*CONVERSION_FACTOR + m) <= p_reg(t*CONVERSION_FACTOR + m + 1);
                            end if;
                        end loop;    
                    end loop;
                    -- Direct Output
                    data_o <= std_logic_vector(p_reg(0)(2*DATA_WIDTH-2-Gain downto DATA_WIDTH-1-Gain));
                end if;

            -----------------------------------------------------------------------
            -- MODE 2: DECIMATION (Downsampling)
            -----------------------------------------------------------------------
            else -- DECIMATION_ARCH = true
                
                -- Simple Input Driven Logic (No Gap/Pulse FSM needed)
                if valid_i = '1' then
                    active_cycle := true;
                    
                    -- Counter Logic (Decreasing per original requirement)
                    current_phase := phase_counter; 
                    if phase_counter > 0 then
                        phase_counter <= phase_counter - 1;
                    else
                        phase_counter <= CONVERSION_FACTOR - 1; -- Wrap
                    end if;
                end if;

                -- Decimation Processing
                if active_cycle then
                    
                    for m in 0 to CONVERSION_FACTOR-1 loop                  
                        for t in 0 to Taps_Per_Phase-1 loop                 
                            -- Always latch new input in decimation
                            a_reg(t) <= signed(data_i);
                            
                            -- Coeffs match phase
                            b_reg(t) <= coeff(t*CONVERSION_FACTOR + current_phase);
                            
                            -- MAC & Shift
                            if t = Taps_Per_Phase-1 then        
                                p_reg(t*CONVERSION_FACTOR + CONVERSION_FACTOR-1) <= a_reg(t) * b_reg(t);
                            else
                                p_reg(t*CONVERSION_FACTOR + CONVERSION_FACTOR-1) <= a_reg(t) * b_reg(t) + p_reg((t+1)*CONVERSION_FACTOR);
                            end if;
                            
                            if m < CONVERSION_FACTOR-1 then
                                p_reg(t*CONVERSION_FACTOR + m) <= p_reg(t*CONVERSION_FACTOR + m + 1);
                            end if;
                        end loop;    
                    end loop;

                    -- Accumulator Logic
                    -- p_reg(0) is the current result of the chain. 
                    -- We accumulate it over the 8 phases.
                    
                    if current_phase > 0 then
                        -- Accumulate intermediate results
                        product_sum <= p_reg(0) + product_sum;
                    else 
                        -- Phase 0 reached: End of Decimation Block
                        -- Final addition + Output
                        decim_out_val := p_reg(0) + product_sum;
                        
                        -- Reset Accumulator
                        product_sum <= (others => '0'); 
                        
                        -- Output
                        data_o <= std_logic_vector(decim_out_val(2*DATA_WIDTH-2 downto DATA_WIDTH-1));
                        valid_o <= '1';
                    end if;
                end if; -- End Decim Active
            end if; -- End Arch Select

        end if; -- Rising Edge
    end process;

end Behavioral;


