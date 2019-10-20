library ieee;
use ieee.std_logic_1164.all;

entity i2c_master is
  generic(  GC_SYSTEM_CLK : integer := 50000000;
            GC_I2C_CLK    : integer := 200000);
  port (clk       : in    std_logic;                      -- system clock
        rst_n     : in    std_logic;                      -- synchronous active low rst
        valid     : in    std_logic;                      -- mysterious module enable signal
        addr      : in    std_logic_vector(6 downto 0);   -- address of target slave
        rnw       : in    std_logic;                      -- read not write command
        data_wr   : in    std_logic_vector(7 downto 0);   -- todo: write to slave
        data_rd   : out   std_logic_vector(7 downto 0);   -- todo: read from slave (be a clown)
        busy      : out   std_logic;                      -- do not disturb, transaction in progress
        ack_error : out   std_logic;                      -- oopsies, something went terribly wrong if I am not low
        sda       : inout std_logic;                      -- serial i2c data
        scl       : inout std_logic);                     -- serial i2c clock
end i2c_master;

architecture i2c_master_arch of i2c_master is
  -- Signals
  signal state_ena    : std_logic;                        -- enable state transition
  signal scl_high_ena : std_logic;                        -- enable signal for start and stop conditions, data sampling and ack (High in the middle of positive edge of scl clk) 
  signal scl_clk      : std_logic;                        -- I2C clock
  signal scl_oe       : std_logic;                        -- enable I2C clock
  signal busy_i		    : std_logic;                        -- internal busy signal, indicates the state machine is running
  signal ack_error_i  : std_logic;                        -- internal ack error, something went terribly wrong
  signal sda_i        : std_logic;                        -- internal sda 
  signal addr_rnw_i   : std_logic_vector(7 downto 0);     -- address and read not write bit
  signal data_tx      : std_logic_vector(7 downto 0);     -- transfer data (send to slave)
  signal data_rx      : std_logic_vector(7 downto 0);     -- read data (received from slave)
  signal bit_cnt      : integer range 0 to 7;
  signal rst_cnt      : std_logic;
  -- Constants
  constant c_scl_period       : integer := gc_system_clk/gc_i2c_clk;
  constant c_scl_half_period  : integer := c_scl_period/2;
  constant c_state_trigger    : integer := c_scl_period/4;
  constant c_scl_trigger      : integer := c_scl_period*3/4;
  -- Type Definitions
  type state_type is (sIDLE, sSTART, sADDR, sACK1, sWRITE, sREAD, sACK2, sMACK, sSTOP);
  signal state : state_type;
  -- Aliases
  alias rnw_i : std_logic is addr_rnw_i(0);
  
  
 begin
----------------------------------------------------------------------------
-- p_sclk is used to generate the scl clock from the system clock
----------------------------------------------------------------------------
  p_sclk: process(clk)
    variable cnt_period: integer range 0 to c_scl_period := 0;
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        -- Synchronous Reset
        cnt_period     := 0;
      elsif (cnt_period = c_scl_period) then
        -- Explicit restart of counter to avoid overflow
        cnt_period     := 0;
        -- Set flag to reset the counter in p_ctrl as well. 
        -- Should be unnecesary but better to be on the safe side!
        -- Better yet had been to have a shared variable or a signal for the counter, imo. :) 
        rst_cnt        <= '1';  
      else
        rst_cnt <= '0'; 
        cnt_period := cnt_period + 1;
      end if;
      if ((rst_n = '0') or (cnt_period < c_scl_half_period)) then
          scl_clk <= '0';
      else -- cnt_period >= c_scl_half_period
          scl_clk <= '1';
      end if;
    end if;
  end process p_sclk;
  
----------------------------------------------------------------------------
-- p_ctrl is used to generate the control signals / trigger signals for the 
-- i2c_master state machine 
----------------------------------------------------------------------------
    p_ctrl : process(clk)
    variable cnt_period: integer range 0 to c_scl_period := 0;
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        -- Synchronous reset
        cnt_period   :=  0;
        state_ena    <= '0';
        scl_high_ena <= '0';
      elsif ((cnt_period = c_scl_period) or (rst_cnt = '1')) then
        -- Overflow / Synchronization reset
        -- Resets to "1" so this counter doesnt lag 1 behind the counter from p_sclk
        -- (although the trigger signals would still be good according to i2c spec if it did) 
        cnt_period := 1;
      else
        cnt_period := cnt_period + 1;
        if (cnt_period = c_state_trigger) then
          state_ena     <= '1';
        elsif (cnt_period = c_scl_trigger) then
          scl_high_ena  <= '1';
        else
          state_ena     <= '0';
          scl_high_ena  <= '0';
        end if;
      end if;    
    end if;
  end process p_ctrl;

----------------------------------------------------------------------------
-- I2C master single process state machine
----------------------------------------------------------------------------
p_state : process (clk) 
begin
  if rising_edge(clk) then
    if (rst_n = '0') then
      state <= sIDLE;
    else
      case state is
      -- Defaults
----------------------------------------------------------------------------
-------------------------------- sIDLE STATE -------------------------------
----------------------------------------------------------------------------
        when sIDLE =>
          busy_i  <= '0'; 
          scl_oe  <= '0'; -- i2c clock not enabled
          sda_i   <= '1'; 
          bit_cnt <= 7;   -- reset bit count for new operation
          
          if valid = '1' then
            data_tx <= data_wr;           -- sample input data_wr to data_tx (transfer data signal) 
            addr_rnw_i <= addr & rnw;     -- sample input addr and rnw and concatenate to internal signal for transfer
            if (ack_error_i = '1') then   -- if coming from error state, reset internal ack error to start new operation
              ack_error_i <= '0';
            end if; 
          end if;
          
        -- Transition Conditions
          if ((state_ena = '1') and (valid = '1')) then -- start condition
            state <= sSTART;
          end if;
----------------------------------------------------------------------------
------------------------------- sSTART STATE -------------------------------
----------------------------------------------------------------------------
        when sSTART =>
          scl_oe <= '1';    -- enable i2c clock
          busy_i <= '1';    -- tell the system we are BUSY, dont gief moar pls
          if scl_high_ena = '1' then -- in the middle of high edge of scl
            sda_i <= '0';            -- pull sda_i low to take control over sda line 
          end if;                    -- this is the start condition for a transaction (seen from the side of the slave) 
        -- Transition Conditions
          if state_ena = '1' then
            state <= sADDR;
          end if;
----------------------------------------------------------------------------
-------------------------------- sADDR STATE -------------------------------
----------------------------------------------------------------------------
        when sADDR => 
          busy_i <= '1';    
          scl_oe <= '1';    -- keep i2c clock enabled (this could be done by setting a default outside the case clause and only pulling scl_oe low for idle) 
          sda_i <= addr_rnw_i(bit_cnt); -- put out addr_rnw_i bit by bit (count is decreased under transition conditions)
        
        -- Transition Conditions
          if (state_ena = '1') then 
            if (bit_cnt = 0) then -- go to sACK1 only when bit_cnt 
              bit_cnt <= 7;   -- reset bit_cnt for next dataphase :) 
              state <= sACK1;
            elsif bit_cnt /= 0 then 
              bit_cnt <= bit_cnt - 1; -- decrease count and go back to sADDR until count reaches 0 
              state <= sADDR;
            end if;
          end if; 
----------------------------------------------------------------------------
-------------------------------- sACK1 STATE -------------------------------
----------------------------------------------------------------------------
        when sACK1 => 
          busy_i  <= '1';  
          scl_oe  <= '1';  
          sda_i   <= '1';  -- To release sda_i (set sda to high impedance and allow the slave to control the line) 
          if ((scl_high_ena = '1') and (sda /= '0')) then 
            ack_error_i <= '1'; -- the slave has failed to pull the sda line low           
          end if;
        -- Transition Conditions
          if ((state_ena = '1') and (rnw_i = '0')) then
            state <= sWRITE;
          elsif ((state_ena = '1') and (rnw_i = '1')) then
            state <= sREAD;
          end if;
----------------------------------------------------------------------------
------------------------------- sWRITE STATE -------------------------------
----------------------------------------------------------------------------        
        when sWRITE =>
          busy_i <= '1';
          scl_oe <= '1';
          sda_i <= data_tx(bit_cnt); -- put out data_tx bit by bit (count is decreased under transition conditions)
      
          -- Transition conditions
          if (state_ena = '1') then
            if (bit_cnt = 0) then
              bit_cnt <= 7;
              state   <= sACK2;
            elsif bit_cnt /= 0 then
              bit_cnt <= bit_cnt - 1;
              state   <= sWRITE;
            end if;
          end if; 
----------------------------------------------------------------------------
-------------------------------- sREAD STATE -------------------------------
----------------------------------------------------------------------------
        when sREAD => 
          busy_i <= '1';
          scl_oe <= '1';
          sda_i <= '1';
          
          if scl_high_ena = '1' then
            data_rx(bit_cnt) <= sda; -- read data from the sda line bit by bit (count is decreased under transition conditions)
          end if;
          
        -- Transition Conditions
          if (state_ena = '1') then
            if (bit_cnt = 0) then
              bit_cnt <= 7;
              state <= sMACK;
            elsif bit_cnt /= 0 then
              bit_cnt <= bit_cnt - 1;
              state <= sREAD;
            end if;
          end if; 
----------------------------------------------------------------------------
-------------------------------- sACK2 STATE -------------------------------
----------------------------------------------------------------------------
        when sACK2 =>
          sda_i <= '1'; -- release sda line so the master can accept commands
          scl_oe <= '1';
          busy_i <= '0'; -- not busy anymore

          if ((scl_high_ena = '1') and (sda /= '0'))then
            ack_error_i <= '1'; -- the slave has failed to pull the sda line low                   
          end if;
        
        -- Transition Conditions 
          if ((state_ena = '1') and (valid = '1') and (rnw = '0')) then
            data_tx <= data_wr; -- sample input data_wr into data_tx so it can be written to the slave 
            state <= sWRITE;
          elsif ((state_ena = '1') and (valid = '1') and (rnw = '1')) then
            addr_rnw_i <= addr & rnw;  -- sample slave address and rnw bit to prepare a repeated start 
            state <= sSTART;
          elsif ((state_ena = '1') and (valid = '0')) then
            sda_i <= '0';
            state <= sSTOP;
          end if;        
----------------------------------------------------------------------------
-------------------------------- sMACK STATE -------------------------------
----------------------------------------------------------------------------
        when sMACK =>
          sda_i <= '1'; 
          scl_oe <= '1';
          busy_i <= '0';
   
          if (state_ena = '1') then
            if (valid = '1' and rnw = '1') then
              state <= sRead; 
            elsif (valid = '1' and rnw = '0') then
              addr_rnw_i  <= addr & rnw; -- sample slave address and rnw bit to prepare a repeated start 
              data_tx     <= data_wr; --sample data input. Go to start
              state       <= sSTART;
            else 
              sda_i <= '0';
              state <= sSTOP; 
            end if;
          else
            state <= sMACK; 
            if (valid = '1') then
              sda_i <= '0';
            end if; 
          end if;      
----------------------------------------------------------------------------
-------------------------------- sSTOP STATE -------------------------------
---------------------------------------------------------------------------- 
        when sSTOP =>
          busy_i <= '1';
          scl_oe <= '1';
          if scl_high_ena = '1' then
            sda_i <= '1'; -- release sda line
          end if;
        -- Transition Conditions
          if state_ena = '1' then
            state <= sIDLE;
          end if;
----------------------------------------------------------------------------
---------------------------------- INVALID  --------------------------------
----------------------------------------------------------------------------
        when others =>
          state <= sIDLE;
      end case;  
    end if;
  end if;

end process; 
----------------------------------------------------------------------------
-- Output Logic
----------------------------------------------------------------------------
busy      <= busy_i;
ack_error <= ack_error_i;
scl       <= '0' when ((scl_clk = '0') and (scl_oe = '1')) else 'Z';
sda       <= 'Z' when (sda_i = '1') else '0'; 
data_rd   <= data_rx;


end architecture i2c_master_arch; -- C'est fini! 
