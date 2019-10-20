library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- User library with I2C read and write procedures  
use work.i2c_master_pkg.all;


-------------------------------------------------------------------------------
-- UVVM Utility Library
-------------------------------------------------------------------------------
library STD;
use std.env.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

-------------------------------------------------------------------------------


entity i2c_master_ctrl_tb is
end entity;




architecture tb of i2c_master_ctrl_tb is
  --signal clk   : std_logic;
  --signal rst_n : std_logic;
  signal sw   : std_logic_vector(9 downto 0);
  signal keys : std_logic_vector(2 downto 0);
  signal led  : std_logic_vector(9 downto 0);
  signal sda  : std_logic;
  signal scl  : std_logic;


  alias data     : std_logic_vector(7 downto 0) is sw(7 downto 0);
  alias reg_addr : std_logic_vector(1 downto 0) is sw(9 downto 8);
  alias load_reg : std_logic is keys(2);
  alias cmd      : std_logic is keys(1);
  alias show     : std_logic is keys(0);


begin

  i2c_master_ctrl_1 : entity work.i2c_master_ctrl
    generic map (
      GC_SYSTEM_CLK => GC_SYSTEM_CLK,
      GC_I2C_CLK    => GC_I2C_CLK)
    port map (
      clk   => clk,
      rst_n => rst_n,
      sw    => sw,
      keys  => keys,
      led   => led,
      sda   => sda,
      scl   => scl);


  tmp175 : entity work.tmp175_simmodel
    generic map (
      i2c_clk => GC_I2C_CLK)
    port map(
      sda => sda,
      scl => scl
      );



  -- Bitvis clock generator
  clock_generator(clk, clk_ena, clk_period, "TB clock");

  p_sequencer : process
    constant C_SCOPE : string := "TB seq.";


    ------------------------------------------------------------------------------
    -- pulse
    -- purpose: general purpose pulse generator
    -- parameters:
    --   target: (std_logic) target signal to be operated on
    --   pulse_value: (std_logic) value of pulse (1= high, 0=low)
    --   clk:   (std_logic)  reference clk
    --   num_periods: (natural) used to specify length of pulse
    --   msg: (string)  log msg to be displayed at pulse generation
    ------------------------------------------------------------------------------
    procedure pulse(
      signal target        : inout std_logic;
      constant pulse_value : in    std_logic;
      signal clk           : in    std_logic;
      constant num_periods : in    natural;
      constant msg         : in    string)
    is
    begin
      if num_periods > 0 then
        wait until falling_edge(clk);
        target <= pulse_value;          --pulse_value;
        for i in 1 to num_periods loop
          wait until falling_edge(clk);
        end loop;
      else
        target <= pulse_value;
      end if;
      target <= not(pulse_value);       --not (pulse_value);
      log(ID_SEQUENCER_SUB, msg, C_SCOPE);
    end procedure;


  begin

    ----------------------------------------------------------------------------------
    -- Set and report init conditions
    ----------------------------------------------------------------------------------
    -- Increment alert counter as two warning is expected when testing writing
    -- to temperature register
    --increment_expected_alerts(warning, 2);
    -- Print the configuration to the log: report/enable logging/alert conditions
    report_global_ctrl(VOID);
    report_msg_id_panel(VOID);
    enable_log_msg(ALL_MESSAGES);
    --disable_log_msg(ID_POS_ACK);        --make output a bit cleaner
    -- Begin simulation
    log(ID_LOG_HDR, "Start Simulation of TB for I2C master", C_SCOPE);
    log(ID_LOG_HDR, "Set default values for I2C master I/O and enable clock and reset system", C_SCOPE);


    -- set resolution bits in configuration register
    clk_ena <= true;
    keys    <= (others => '1');
    sw      <= (others => '0');
    pulse(rst_n, '0', clk, 5, "Activating rst_n");

    data     <= "10010000";
    reg_addr <= "00";
    wait for 0 ns;
    pulse(load_reg, '0', clk, 5, "Loading i2c address");
    wait for clk_period*10;


    data     <= "00000001";
    reg_addr <= "01";
    wait for 0 ns;
    pulse(load_reg, '0', clk, 5, "Loading config reg address");
    wait for clk_period*10;

    data           <= "01100000";
    reg_addr       <= "10";
    wait for 0 ns;
    pulse(load_reg, '0', clk, 5, "Loading resolution bits");
    wait for clk_period*10;
    sw(1 downto 0) <= "01";             -- config reg is 8 bits
    pulse(cmd, '0', clk, 5, "Start transactions");

    wait for clk_period*(GC_SYSTEM_CLK/GC_I2C_CLK)*50;



    --read back configuration register
    --pointer reg alread containing correct address from previous operation
    data           <= "10010001";
    reg_addr       <= "00";
    wait for 0 ns;
    pulse(load_reg, '0', clk, 5, "Loading i2c address");
    wait for clk_period*10;
    sw(1 downto 0) <= "01";             -- config reg is 8 bits
    pulse(cmd, '0', clk, 5, "Start transaction");

    wait for clk_period*(GC_SYSTEM_CLK/GC_I2C_CLK)*50;

    --read back temperature registers
    --first update pointer register with temp. reg. addr. 
    data     <= "10010000";
    reg_addr <= "00";
    wait for 0 ns;
    pulse(load_reg, '0', clk, 5, "Loading i2c address");
    wait for clk_period*10;

    data           <= "00000000";
    reg_addr       <= "01";
    wait for 0 ns;
    pulse(load_reg, '0', clk, 5, "Load temp. reg. addr.");
    wait for clk_period*10;
    sw(1 downto 0) <= "00";             -- Load only temp. reg address to
    -- pointer reg (no bytes to write)
    pulse(cmd, '0', clk, 5, "Start");

    wait for clk_period*(GC_SYSTEM_CLK/GC_I2C_CLK)*50;


    --read temp reg.
    data           <= "10010001";
    reg_addr       <= "00";
    wait for 0 ns;
    pulse(load_reg, '0', clk, 5, "Loading i2c address");
    wait for clk_period*10;
    sw(1 downto 0) <= "10";
    pulse(cmd, '0', clk, 5, "Start");

    wait for clk_period*(GC_SYSTEM_CLK/GC_I2C_CLK)*50;





    --==================================================================================================
    -- Ending the simulation
    --------------------------------------------------------------------------------------
    wait for 1000 ns;                   -- to allow some time for completion
    report_alert_counters(FINAL);  -- Report final counters and print conclusion for simulation (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);
    clk_ena <= false;
    wait;



  end process;


end architecture;
