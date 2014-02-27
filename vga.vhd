---------------------------------------------
-- Customized 640x480 VGA Controller

-- It reads a RAM buffer of 1200x11bit as a
-- serialized 40x30 viewport and scales it to
-- 640x480.

-- Values:
-- "00000000000": Empty
-- "11111111111": Food
-- Other: Snake part
---------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga is
	Port (
		clk_in : in STD_LOGIC;
		color : in STD_LOGIC_VECTOR(0 to 2); -- The RGB color of the background in 1 bit depth per channel (3 switches). The snake is the inverse.
		ram_addr : out STD_LOGIC_VECTOR(10 downto 0);
		ram_data : in STD_LOGIC_VECTOR(10 downto 0);
		clk_out : out STD_LOGIC;
		vsync : out STD_LOGIC;
		hsync : out STD_LOGIC;
		R : out STD_LOGIC_VECTOR(3 downto 0);
		G : out STD_LOGIC_VECTOR(3 downto 0);
		B : out STD_LOGIC_VECTOR(3 downto 0)
	);
end vga;

architecture Behavioral of vga is
	signal vcount : INTEGER range 0 to 525 := 0;
	signal hcount : INTEGER range 0 to 800 := 0;
	signal pixelx : INTEGER range 0 to 39;
	signal pixely : INTEGER range 0 to 29;
begin

	inc: process(clk_in) -- Counts clocks needed to do the VGA synchronization
	begin
		if(rising_edge(clk_in)) then
			
			if(hcount = 799) then
				if(vcount = 520) then
					vcount <= 0;
					clk_out <= '1';
				else
					clk_out <= '0';
					vcount <= vcount + 1;
				end if;
				hcount <= 0;
			else
				clk_out <= '0';
				hcount <= hcount + 1;
			end if;
						
		end if;
	end process;
	
	sync: process(clk_in) -- Outputs the necessary clocks for the VGA synchronization
	begin
		if(rising_edge(clk_in)) then
			if(vcount >= 490 and vcount <= 491) then
				vsync <= '0';
			else
				vsync <= '1';
			end if;
			
			if(hcount >= 655 and hcount <= 751) then
				hsync <= '0';
			else
				hsync <= '1';
			end if;
		end if;
	end process;
	
	draw: process(clk_in) -- Our main draw process
	begin
		if(rising_edge(clk_in)) then
			if(vcount < 480 and hcount < 640) then -- We're inside our VGA viewport
				pixelx <= hcount / 16; -- Scale x axis
				pixely <= vcount / 16; -- Scale y axis
				ram_addr <= std_logic_vector(to_unsigned(pixely * 40 + pixelx, 11)); -- Read data from RAM
				-- TODO: Probably we need +1 so we compare the correct values
				if(ram_data = "11111111111") then -- Draw the food
					R <= color(0) & not(color(0) & color(0) & color(0));
					G <= color(1) & not(color(1) & color(1) & color(1));
					B <= color(2) & not(color(2) & color(2) & color(2));
				elsif(ram_data /= "00000000000") then -- Draw background
					R <= not(color(0) & color(0) & color(0) & color(0));
					G <= not(color(1) & color(1) & color(1) & color(1));
					B <= not(color(2) & color(2) & color(2) & color(2));
				else -- Draw snake part
					R <= color(0) & color(0) & color(0) & color(0);
					G <= color(1) & color(1) & color(1) & color(1);
					B <= color(2) & color(2) & color(2) & color(2);
				end if;
			else
				R <= "0000";
				G <= "0000";
				B <= "0000";
			end if;
		end if;
	end process;

end Behavioral;

