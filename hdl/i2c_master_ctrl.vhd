library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_master_ctrl is
  generic(  GC_SYSTEM_CLK : integer := 50000000;
            GC_I2C_CLK    : integer := 200000);
  port( clk   : in    std_logic;
        rst_n : in    std_logic;                     -- Key 0 in DE2-SoC board
        sw    : in    std_logic_vector(9 downto 0);  -- Toggle switches
        keys  : in    std_logic_vector(2 downto 0);  -- Keys 3-1 in DE2-SoC board
        LED   : out   std_logic_vector(9 downto 0);  -- LEDs
        sda   : inout std_logic;
        scl   : inout std_logic
        );
end i2c_master_ctrl;


architecture rtl of i2c_master_ctrl is
-- Registers
signal i2c_addr_reg   : std_logic_vector(7 downto 0); -- [reg_addr: 0]  I2C device address and rnw bit
signal int_addr_reg   : std_logic_vector(7 downto 0); -- [reg_addr: 1] Address of I2C device internal reg
signal write_reg_lo   : std_logic_vector(7 downto 0); -- [reg_addr: 2] Data value to write to internal regs, low reg (LSB)
signal write_reg_hi   : std_logic_vector(7 downto 0); -- [reg_addr: 3] Data value to write to internal regs, high reg (MSB)


-- Read/Write Register Arrays
type two_regs is array(1 downto 0) of std_logic_vector(7 downto 0); 
signal read_reg : two_regs; 

-- I2C Master Signals 
signal busy_s         : std_logic;                      -- do not disturb, transaction in progress
signal ack_error_s    : std_logic;                      -- oopsies, something went terribly wrong if I am not low
signal valid_s        : std_logic;                      -- module enable signal
signal rnw_s          : std_logic;                      -- read not write command
signal addr_s         : std_logic_vector(6 downto 0);   -- address of target slave
signal data_wr_s      : std_logic_vector(7 downto 0);   --  todo: write to slave
signal data_rd_s      : std_logic_vector(7 downto 0);   -- todo: read from slave (be a clown)

-- Other internal signals
signal busy_r         : std_logic;                      -- Registered busy signal from i2c master (for edge detection)
signal byte_cnt       : unsigned(1 downto 0) := (others => '0');   -- Number of bytes to be written to I2C device

signal load_reg_r     : std_logic;                      -- Registered load_reg (Key 2)
signal start_fsm_r    : std_logic;                      -- Registered start_fsm (Key 1)
signal byte_sel_r     : std_logic;                      -- Registered byte_sel (Key 0)

-- Type Definitions
type state_type is (sIDLE, sSTART, sWAIT_DATA, sWRITE_DATA, sWAIT_STOP);
signal state : state_type;

-- Aliases
alias reg_addr    : std_logic_vector(1 downto 0) is sw(9 downto 8); -- address of controller register
alias reg_data    : std_logic_vector(7 downto 0) is sw(7 downto 0); -- data to be written to controller register

alias load_reg_key  : std_logic is keys(2); -- Key3 in DE2-SoC board
alias start_fsm_key : std_logic is keys(1); -- Key2 in DE2-SoC board
alias byte_sel_key  : std_logic is keys(0); -- Key1 in DE2-SoC board

begin -- architecture

p_sync_keys: process (clk)
begin
  -- Register key values 
  if rst_n = '0' then
    load_reg_r  <= '1';
    start_fsm_r <= '1';
    byte_sel_r  <= '1';
  else
    load_reg_r  <= load_reg_key;
    start_fsm_r <= start_fsm_key;
    byte_sel_r  <= byte_sel_key;
  end if; 
end process;

p_regs: process (clk)
begin
  if rising_edge(clk) then
    if rst_n = '0' then
      i2c_addr_reg <= (others => '0');
      int_addr_reg <= (others => '0');
      write_reg_lo <= (others => '0');
      write_reg_hi <= (others => '0');
    elsif (load_reg_r = '0') then 
      LED(8) <= '0';
      case reg_addr is
        when "00" =>  i2c_addr_reg <= reg_data; -- I2C device address and rnw bit 
        when "01" =>  int_addr_reg <= reg_data; -- Address of I2C device internal reg
        when "10" =>  write_reg_lo <= reg_data; -- Data value to write to internal regs, low reg (LSB)
        when "11" =>  write_reg_hi <= reg_data; -- Data value to write to internal regs, high reg (MSB)
        when others => null;  
      end case; 
	else 
	  LED(8) <= '1';
    end if; 
  end if;
end process; -- p_regs

----------------------------------------------------------------------------
-- I2C controller single process state machine
----------------------------------------------------------------------------
p_fsm: process (clk)
begin
  if rising_edge(clk) then
    if (rst_n = '0') then
      busy_r    <= '0';
      byte_cnt  <= (others => '0');
      state     <= sIDLE;
    else
	 busy_r <= busy_s;
	 case state is
      -- Defaults
----------------------------------------------------------------------------
-------------------------------- sIDLE STATE -------------------------------
----------------------------------------------------------------------------
        when sIDLE =>
		LED(9) <= '1';
        byte_cnt <= unsigned(sw(1 downto 0)); 
        -- Transition Conditions        
        if start_fsm_r = '0' then -- Key2 is pressed
          state <= sSTART; 
        else 
          state <= sIDLE;
        end if; 
----------------------------------------------------------------------------
------------------------------- sSTART STATE -------------------------------
----------------------------------------------------------------------------
        when sSTART =>
          LED(9) <= '0';
          data_wr_s <= int_addr_reg;
          addr_s    <= i2c_addr_reg(7 downto 1);
          rnw_s     <= i2c_addr_reg(0);
          valid_s   <= '1';
         -- Transition Conditions      
          if (busy_s = '1' and busy_r = '0') then -- edge detection
           state <= sWAIT_DATA;
          else 
            state <= sSTART;
          end if;
----------------------------------------------------------------------------
----------------------------- sWAIT_DATA STATE -----------------------------
----------------------------------------------------------------------------
        when sWAIT_DATA =>
		  LED(9) <= '0';
        -- Transition Conditions
        if (busy_s = '0' and busy_r = '1') then
          if (rnw_s = '1') then
          -- BRANCH 1: Request Read Operation
            if to_integer(byte_cnt) = 0 then
              state <= sWAIT_STOP;
            else 
              read_reg(to_integer(byte_cnt) - 1) <= data_rd_s;
              byte_cnt <= byte_cnt - 1;
              state <= sWAIT_DATA;
            end if; 
          -- BRANCH 2: Request Write Operation
          else -- rnw = '0'
            if to_integer(byte_cnt) = 0 then
              state <= sWAIT_STOP; 
            else
              state <= sWRITE_DATA;
            end if;
          end if;
        end if;
----------------------------------------------------------------------------
---------------------------- sWRITE_DATA STATE -----------------------------
----------------------------------------------------------------------------
        when sWRITE_DATA =>   
		  LED(9) <= '0';		
        if to_integer(byte_cnt) = 2 then
          data_wr_s <= write_reg_hi;
        elsif to_integer(byte_cnt) = 1 then
          data_wr_s <= write_reg_lo;
        end if; 
        -- Transition Conditions
        if (busy_s = '1' and busy_r = '0') then -- rising_edge detection
          byte_cnt <= byte_cnt - 1;
          state    <= sWAIT_DATA;
        else 
          state    <= sWRITE_DATA;
        end if; 
----------------------------------------------------------------------------
----------------------------- sWAIT_STOP STATE -----------------------------
----------------------------------------------------------------------------
        when sWAIT_STOP =>    
          LED(9) <= '0';
          valid_s <= '0';
        -- Transition Conditions
        if (busy_s = '0' and busy_r = '1') then
          state <= sIDLE;
        else
          state <= sWAIT_STOP;
        end if; 
----------------------------------------------------------------------------
---------------------------------- INVALID  --------------------------------
----------------------------------------------------------------------------
        when others =>
          state <= sIDLE;
        end case;
      end if; 
    end if;
end process; --p_fsm


-- Component Instantiation
I2C_Master : entity work.i2c_master
generic map ( GC_SYSTEM_CLK => GC_SYSTEM_CLK,
              GC_I2C_CLK    => GC_I2C_CLK)
  port map  ( clk       => clk,           
              rst_n     => rst_n,        
              valid     => valid_s,      
              addr      => addr_s,        
              rnw       => rnw_s,         
              data_wr   => data_wr_s,     
              data_rd   => data_rd_s,     
              busy      => busy_s,        
              ack_error => ack_error_s,   
              sda       => sda,           
              scl       => scl);           

-- Output Logic
LED(7 downto 0) <= read_reg(1) when byte_sel_r = '1' else read_reg(0);
end architecture rtl; -- C'est maybe fini!