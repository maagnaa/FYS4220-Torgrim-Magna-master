library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_lab1 is
end;

architecture testbench of tb_lab1 is
-- Constants
  constant clk_period_c : time := 20 ns; -- clock period

-- Signals
  signal clk_ena  : boolean;
  signal clk50    : std_logic;
  signal rst_n    : std_logic;
  signal ena_n    : std_logic;
  signal led      : std_logic_vector(9 downto 0);
  signal sw       : std_logic_vector(9 downto 0);
  signal hex0     : std_logic_vector(0     to 6);
  
  
  component lab1 is
    port (
    clk50 :  in std_logic;
    rst_n :  in std_logic;
    ena_n :  in std_logic;
    sw    :  in std_logic_vector(9 downto 0); -- switches end entity lab1;
    led   : out std_logic_vector(9 downto 0); -- Red LEDs
    hex0  : out std_logic_vector(0     to 6) -- 7-segment display
    );
	end component lab1;
  
begin

  clk50 <= not clk50 after clk_period_c/2 when clk_ena else '0'; 

	stimuli_process : process
	begin
		--set default values
    clk_ena <= false;
    rst_n   <= '1';
    ena_n   <= '1';
    sw      <= (others => '0');

    --enable clk and wait for 3 clk periods
    clk_ena <= true;
    wait for 3*clk_period_c;

    --assert rst_n for 3 clk periods
    rst_n   <= '0';
    wait for 3*clk_period_c;

    --deassert rst_n for 3 clk periods
    rst_n   <= '1';
    wait for 3*clk_period_c;

    --enable counter and wait for 20 clk_periods
    ena_n   <= '0';
    wait for 20*clk_period_c;

    --assert rst_n for 3 clk periods
    rst_n   <= '0';
    wait for 3*clk_period_c;

    --deassert rst_n for 10 clk periods
    rst_n   <= '1';
    wait for 3*clk_period_c;

    --disable clk
    clk_ena   <= false;

    --end of simulation
    wait;
	end process stimuli_process;
  
  
  -- Device Under Test
  	DUT : lab1
		port map(
      clk50 => clk50,
      rst_n => rst_n,
      ena_n => ena_n,
			sw    => sw,
      led   => led,
			hex0  => hex0
		);
    
end architecture testbench;