---------------------------------------------
-- Simple frequency divider
---------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fdiv is
	Port (
		clk_in : in STD_LOGIC;
		div : in INTEGER range 2 to 1000;
		
		clk_out : out STD_LOGIC
	);
end fdiv;

architecture Behavioral of fdiv is
	signal temp_out : STD_LOGIC := '0';
	signal count : INTEGER range 1 to 1000 := 1;
begin
	clk_out <= temp_out;

	process(clk_in)
	begin
		if(rising_edge(clk_in)) then
			if(count = div - 1) then
				count <= 1;
				temp_out <= not(temp_out);
			else
				count <= count + 1;
			end if;
		end if;
	end process;

end Behavioral;

