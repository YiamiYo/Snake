---------------------------------------------
-- Dual-Port RAM With Asynchronous Read

-- Sources:
-- http://www.xilinx.com/support/documentation/sw_manuals/xilinx14_7/xst.pdf
---------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram is
	Port (
		clk : in STD_LOGIC;
		we : in STD_LOGIC;
		addr_pri : in STD_LOGIC_VECTOR(10 downto 0);
		addr_sec : in STD_LOGIC_VECTOR(10 downto 0);
		data_in : in STD_LOGIC_VECTOR(10 downto 0);
		data_pri : out STD_LOGIC_VECTOR(10 downto 0);
		data_sec : out STD_LOGIC_VECTOR(10 downto 0)
	);
end ram;

architecture Behavioral of ram is
	type BUFF is ARRAY(1199 downto 0) of STD_LOGIC_VECTOR(10 downto 0);
	signal RAM : BUFF;
	--signal read_addr_pri : STD_LOGIC_VECTOR(10 downto 0);
	--signal read_addr_sec : STD_LOGIC_VECTOR(10 downto 0);
begin

	process(clk)
	begin
		if(rising_edge(clk)) then
			if(we = '1') then
				RAM(to_integer(unsigned(addr_pri))) <= data_in;
			end if;
			--read_addr_pri <= addr_pri;
			--read_addr_sec <= addr_sec;
		end if;
	end process;
	
	data_pri <= RAM(to_integer(unsigned(addr_pri)));
	data_sec <= RAM(to_integer(unsigned(addr_sec)));
	
end Behavioral;