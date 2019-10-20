library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity system_top is
  port( clk   : in    std_logic;
        rst_n : in    std_logic;                      -- Key 0 in DE2-SoC board
        sw    : in    std_logic_vector(9 downto 0);   -- Toggle switches
        keys  : in    std_logic_vector(2 downto 0);   -- Keys 3-1 in DE2-SoC board
        alert : in    std_logic;                      -- alert line from TMP175
        LED   : out   std_logic_vector(9 downto 0);   -- LEDs
        sda   : inout std_logic;                      -- serial I2C data
        scl   : inout std_logic                       -- serial I2C clock
        );
		
end system_top;

architecture system_top_arch of system_top is

-- registered signals 
--signal keys_r  			: std_logic_vector(2 downto 0);
--signal alert_r 		  : std_logic;

-- synchronized alert and key signals 
signal keys_synced  : std_logic_vector(2 downto 0);
signal alert_synced : std_logic;

-- Component 
	component nios2_system is
		port (
			clk_clk                  : in  std_logic                    := 'X';             -- clk
			reset_reset_n            : in  std_logic                    := 'X';             -- reset_n
			led_pio_ext_export       : out std_logic_vector(9 downto 0);                    -- export
			sw_pio_ext_export        : in  std_logic_vector(9 downto 0) := (others => 'X'); -- export
			interrupt_pio_ext_export : in  std_logic_vector(3 downto 0) := (others => 'X');  -- export
			i2c_wrapper_sda_ext_export : inout std_logic                    := 'X';             -- export
			i2c_wrapper_sc_ext_export  : inout std_logic                    := 'X'              -- export
		);
	end component nios2_system;

begin

	p_sync: process (clk)
	begin
		if rising_edge(clk) then
			keys_synced  <= keys(2 downto 0);
			alert_synced <= alert;
		end if;
	end process; -- p_sync

	u0 : component nios2_system
		port map (
			clk_clk                  						 => clk,                 
			reset_reset_n            						 => rst_n,               
			led_pio_ext_export       						 => LED,      
			sw_pio_ext_export        						 => sw,      
			interrupt_pio_ext_export(3) 				 => alert_synced,
			interrupt_pio_ext_export(2 downto 0) => keys_synced,
			i2c_wrapper_sda_ext_export => sda,
			i2c_wrapper_sc_ext_export  => scl
		);

end architecture system_top_arch;
