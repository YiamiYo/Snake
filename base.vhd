---------------------------------------------
-- Single player snake without walls.
-- TODO: Refactoring
---------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity base is
	Port (
		clk_50 : in STD_LOGIC;
		color : in STD_LOGIC_VECTOR(0 to 2);
		UP : in STD_LOGIC;
		DOWN : in STD_LOGIC;
		RIGHT : in STD_LOGIC;
		LEFT : in STD_LOGIC;
		
		vsync : out STD_LOGIC;
		hsync : out STD_LOGIC;
		R : out STD_LOGIC_VECTOR(3 downto 0);
		G : out STD_LOGIC_VECTOR(3 downto 0);
		B : out STD_LOGIC_VECTOR(3 downto 0);
		led : out STD_LOGIC_VECTOR(3 downto 0)
	);
end base;

architecture Behavioral of base is

	constant TICK_PERIOD : INTEGER range 0 to 50000000 := 6250000; -- Our delay in 20ns periods (50MHz clock)

	-- Direction states. We are always moving, pressing a button or not.
	constant DIRECTION_UP : STD_LOGIC_VECTOR(0 to 1) := "00";
	constant DIRECTION_DOWN : STD_LOGIC_VECTOR(0 to 1) := "01";
	constant DIRECTION_RIGHT : STD_LOGIC_VECTOR(0 to 1) := "10";
	constant DIRECTION_LEFT : STD_LOGIC_VECTOR(0 to 1) := "11";
	
	-- Simple state machine for the game logic
	-- I had to break to more states for RAM synchronization
	-- TODO: LEARN RAM SYNCHRONIZATION!!!
	constant STATE_INIT : INTEGER range 0 to 15 := 0; -- Initialize all values for new game. Don't reset prng!
	constant STATE_PLAY_DECREMENT : INTEGER range 0 to 15 := 1; -- Decrement all parts of snake by one
	constant STATE_PLAY_EVENTS : INTEGER range 0 to 15 := 2; -- Check for events
	constant STATE_PLAY_MOVE : INTEGER range 0 to 15 := 3; -- Event or not we always move
	constant STATE_PLAY_SET : INTEGER range 0 to 15 := 4; -- Write our position to RAM
	constant STATE_PLAY_NEXT : INTEGER range 0 to 15 := 5; -- Check for collisions
	constant STATE_PLAY_WAIT : INTEGER range 0 to 15 := 6; -- Delay. Humans are slow.
	constant STATE_PLAY_INCREASE : INTEGER range 0 to 15 := 7; -- Increase size of snake if we ate the food
	constant STATE_PLAY_RAND : INTEGER range 0 to 15 := 8; -- Get a new random value from our prng that is inside our RAM range
	constant STATE_PLAY_CHECK : INTEGER range 0 to 15 := 9; -- Check if the position indicated by our random value is free to place the food. If it's not, just go to the next one
	constant STATE_LOSE : INTEGER range 0 to 15 := 15; -- Lose "animation"
	
	constant RAM_NOP : STD_LOGIC_VECTOR(1 downto 0) := "00";
	constant RAM_RESET : STD_LOGIC_VECTOR(1 downto 0) := "01";
	constant RAM_DECREMENT : STD_LOGIC_VECTOR(1 downto 0) := "10";
	
	signal viewColor : STD_LOGIC_VECTOR(0 to 2);
	signal clk_25 : STD_LOGIC;
	signal clk_draw : STD_LOGIC;
	signal clk_tick : STD_LOGIC;
	signal direction : STD_LOGIC_VECTOR(0 to 1) := DIRECTION_LEFT;
	signal posx : INTEGER range 0 to 39;
	signal posy : INTEGER range 0 to 29;
	signal size : INTEGER range 0 to 1200;
	signal inc : INTEGER range 0 to 10;
	signal state : INTEGER range 0 to 15 := STATE_INIT;
	
	signal ram_action : STD_LOGIC_VECTOR(1 downto 0) := RAM_NOP;
	signal ram_counter : INTEGER range 0 to 1200 := 1200;
	signal ram_we : STD_LOGIC := '0';
	signal ram_read : STD_LOGIC := '0';
	signal ram_addr_pri : STD_LOGIC_VECTOR(10 downto 0);
	signal ram_addr_sec : STD_LOGIC_VECTOR(10 downto 0);
	signal ram_data_in : STD_LOGIC_VECTOR(10 downto 0);
	signal ram_data_pri : STD_LOGIC_VECTOR(10 downto 0);
	signal ram_data_sec : STD_LOGIC_VECTOR(10 downto 0);
	signal tick_counter : INTEGER range 0 to 50000000;
	
	signal prng_rst : STD_LOGIC := '0';
	signal prng_en : STD_LOGIC := '0';
	signal prng_val : STD_LOGIC_VECTOR(10 downto 0);
begin
	led <= std_logic_vector(to_unsigned(state, 4));
	
	div2: entity WORK.fdiv port map(clk_50, 2, clk_25); -- Divide our 50MHz clock by 2 to create 25MHz clock for the VGA controller
	controller: entity WORK.vga port map(clk_25, viewColor, ram_addr_sec, ram_data_sec, clk_draw, vsync, hsync, R, G, B); -- The VGA controller using our RAM to draw
	mem: entity WORK.ram port map(clk_50, ram_we, ram_addr_pri, ram_addr_sec, ram_data_in, ram_data_pri, ram_data_sec); -- Instantiation of RAM
	prng: entity WORK.prng11 port map(clk_50, prng_rst, prng_en, prng_val); -- The pseudo-random sequence generator for the food location

	ram_events: process(clk_50) -- Had to merge all processes to one
	begin
		if(rising_edge(clk_50)) then
			if(ram_read = '1') then -- TODO: probably we don't need this since we use asynchronous read RAM, but I had to make it work as soon as possible.
				ram_read <= '0';
			else
			if(ram_we = '1') then
				ram_we <= '0';
				if(ram_counter < 1200) then
					ram_counter <= ram_counter + 1;
					ram_read <= '1';
				end if;
			else
			if(ram_counter < 1200) then
				case ram_action is
					when RAM_RESET =>
						ram_data_in <= "00000000000";
						ram_we <= '1';
					when RAM_DECREMENT =>
						if((unsigned(ram_data_pri) > 0) and (ram_data_pri /= "11111111111")) then
							ram_data_in <= std_logic_vector(to_unsigned(to_integer(unsigned(ram_data_pri)), 11) - 1);
							ram_we <= '1';
						else
							ram_counter <= ram_counter + 1;
							ram_addr_pri <= std_logic_vector(to_unsigned(ram_counter, 11));
							ram_read <= '1';
						end if;
					when others => ram_counter <= ram_counter + 1;
				end case;
			else
				case state is
					when STATE_INIT =>
						ram_action <= RAM_RESET;
						ram_counter <= 0;
						viewColor <= color;
						direction <= DIRECTION_LEFT;
						posx <= 19;
						posy <= 14;
						size <= 5;
						inc <= 1;
						state <= STATE_PLAY_INCREASE;
					when STATE_PLAY_DECREMENT =>
						viewColor <= color;
						ram_action <= RAM_DECREMENT;
						ram_counter <= 0;
						ram_addr_pri <= std_logic_vector(to_unsigned(ram_counter, 11));
						ram_read <= '1';
						state <= STATE_PLAY_EVENTS;
					when STATE_PLAY_EVENTS =>
						if(LEFT = '1' and not(direction = DIRECTION_RIGHT)) then direction <= DIRECTION_LEFT;					
						elsif(UP = '1' and not(direction = DIRECTION_DOWN)) then direction <= DIRECTION_UP; 
						elsif(DOWN = '1' and not(direction = DIRECTION_UP)) then direction <= DIRECTION_DOWN;
						elsif(RIGHT = '1' and not(direction = DIRECTION_LEFT)) then direction <= DIRECTION_RIGHT;
						end if;
						state <= STATE_PLAY_MOVE;
					when STATE_PLAY_MOVE =>
						case direction is
							when DIRECTION_UP => if(posy = 0) then posy <= 29; else posy <= posy - 1; end if;
							when DIRECTION_DOWN => if(posy = 29) then posy <= 0; else posy <= posy + 1; end if;
							when DIRECTION_RIGHT => if(posx = 39) then posx <= 0; else posx <= posx + 1; end if;
							when DIRECTION_LEFT => if(posx = 0) then posx <= 39; else posx <= posx - 1; end if;
							when others => null;
						end case;
						state <= STATE_PLAY_SET;
					when STATE_PLAY_SET =>
						ram_addr_pri <= std_logic_vector(to_unsigned(posy * 40 + posx, 11));
						ram_read <= '1';
						state <= STATE_PLAY_NEXT;
					when STATE_PLAY_NEXT =>
						if(ram_data_pri = "11111111111") then
							state <= STATE_PLAY_INCREASE;
							ram_data_in <= std_logic_vector(to_unsigned(size + 1, 11));
							ram_we <= '1';
						elsif(ram_data_pri /= "00000000000") then
							state <= STATE_LOSE;
							inc <= 1;
						else
							state <= STATE_PLAY_WAIT;
							ram_data_in <= std_logic_vector(to_unsigned(size, 11));
							ram_we <= '1';
						end if;
					when STATE_PLAY_WAIT =>
						if(tick_counter < TICK_PERIOD) then
							tick_counter <= tick_counter + 1;
						else
							tick_counter <= 0;
							state <= STATE_PLAY_DECREMENT;
						end if;
					when STATE_PLAY_INCREASE =>
						size <= size + 1;
						prng_en <= '1';
						state <= STATE_PLAY_RAND;
					when STATE_PLAY_RAND =>
						if(unsigned(prng_val) < 1200) then
							prng_en <= '0';
							ram_addr_pri <= prng_val;
							ram_read <= '1';
							state <= STATE_PLAY_CHECK;
						end if;
					when STATE_PLAY_CHECK =>
						if(ram_data_pri /= "00000000000") then
							if(unsigned(ram_addr_pri) + 1 < 1200) then
								ram_addr_pri <= std_logic_vector(unsigned(ram_addr_pri) + 1);
								ram_read <= '1';
							else
								ram_addr_pri <= "00000000000";
								ram_read <= '1';
							end if;
						else
							ram_data_in <= "11111111111";
							ram_we <= '1';
							state <= STATE_PLAY_WAIT;
						end if;
					when STATE_LOSE =>
						if(tick_counter < TICK_PERIOD) then
							tick_counter <= tick_counter + 1;
						else
							tick_counter <= 0;
							viewColor <= not(viewColor);
							if(inc < 10) then
								inc <= inc + 1;
							else
								state <= STATE_INIT;
							end if;
						end if;
					when others => null;
				end case;
			end if;
		end if;
		end if;
		end if;
	end process;

end Behavioral;

