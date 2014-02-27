---------------------------------------------
-- A Linear Feedback Shift Register of 11 bits

-- Sources:
-- http://en.wikipedia.org/wiki/Linear_feedback_shift_register
---------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity prng11 is
	Port (
		clk : in STD_LOGIC;
		rst : in STD_LOGIC;
		en : in STD_LOGIC;
		v : out STD_LOGIC_VECTOR(10 downto 0)
	);
end prng11;

architecture Behavioral of prng11 is
	signal fb : STD_LOGIC;
	signal val : STD_LOGIC_VECTOR(10 downto 0) := "10011100001";
begin

	-- TODO: Not sure if I need to use 10/8 or 0/2 for maximal-length
	fb <= (val(10) xor val(8));
	v <= val;
	
	process(clk, rst)
	begin
		if(rst = '1') then
			val <= (others => '0');
		elsif(rising_edge(clk)) then
			if(en = '1') then
				val <= val(9 downto 0) & fb;
			end if;
		end if;
	end process;

end Behavioral;

