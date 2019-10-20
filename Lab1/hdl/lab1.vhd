library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lab1 is
  port (
  clk50 :  in std_logic;
  rst_n :  in std_logic;
  ena_n :  in std_logic;
  sw    :  in std_logic_vector(9 downto 0); -- Switches end entity lab1;
  led   : out std_logic_vector(9 downto 0); -- Red LEDs
  hex0  : out std_logic_vector(0     to 6) -- 7-segment display
  );
end entity lab1;

architecture top_level of lab1 is
signal ena_r	  : std_logic; 							-- Registered ena_n signal 
signal ena_rr	  : std_logic;
signal counter_s  : unsigned(3 downto 0) := "0000";



begin

  push_p: process(clk50)
  begin
    if rising_edge(clk50) then
	ena_r 	<= ena_n;					-- Register ena_n input		
    ena_rr 	<= ena_r;   
	  if rst_n = '0' then
		ena_r	  <= '1';
        counter_s <= (others => '0');
      elsif (ena_r = '0' and ena_rr = '1') then
        counter_s <= counter_s + 1;         
      end if;
    end if;
  end process;  
 

-- Output Logic
	with counter_s select
		hex0 <= "0000001" when "0000", -- 0
            "1001111" when "0001", -- 1
            "0010010" when "0010", -- 2
            "0000110" when "0011", -- 3
            "1001100" when "0100", -- 4
            "0100100" when "0101", -- 5
            "0100000" when "0110", -- 6
            "0001111" when "0111", -- 7
            "0000000" when "1000", -- 8
            "0000100" when "1001", -- 9
            "0001000" when "1010", -- A
            "1100000" when "1011", -- b
            "0110001" when "1100", -- C
            "1000010" when "1101", -- d
            "0110000" when "1110", -- E
            "0111000" when "1111", -- F
            "1111111" when others; -- turn off all LEDs

  led(9 downto 0) <= sw(9 downto 0);
  
end architecture top_level;