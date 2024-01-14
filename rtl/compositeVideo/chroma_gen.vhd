--------------------------------------------------------------------------------
-- Company:
-- Engineer:		Joerg Wolfram
--
-- Create Date:    	04.03.2007
-- Design Name:
-- Module Name:    	chroma generator
-- Project Name:  	fbas-encoder
-- Target Device:
-- Tool versions:
-- Description:		generates the chroma component of the signal
--
-- Revision:		0.31
-- License:		GPL
--
-- Additional Comments:	10.01.2024 Adapted for HSL input by Robin Jacobs
------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity chroma_gen is

port (
	clk32:	      in std_logic;								--- input clock (32Mhz)
	colorEnable:  in std_logic;								--- colour enable
	hsync:	  	  in std_logic;								--- hor. sync
	vsync:	  	  in std_logic;								--- vert sync
	blanking:  in std_logic;								--- blanking
	palNtsc:	  in std_logic;								--- system (pal/ntsc)
	HSL:		  in std_logic_vector(7 downto 0);		    --- HSL  input, format 1:3:4  1 saturation, 3 luma, 4 chroma
	saturation:   in std_logic_vector(1 downto 0);			--- saturation input amount
	chroma:		 out std_logic_vector(1 downto 0)			--- chroma output

);
end entity chroma_gen;

---############################################################################
--- 32MHz
---############################################################################
architecture color_gen of chroma_gen is

signal 	carrier: 	std_logic_vector(15 downto 0);
signal 	bcounter:	std_logic_vector(3 downto 0);
signal  vcounter:	std_logic_vector(9 downto 0);
signal 	phase:		std_logic_vector(3 downto 0);
signal 	scarrier:	std_logic_vector(3 downto 0);
signal  hue:	    std_logic_vector(3 downto 0);
signal	colorOn:	std_logic;
signal	oddeven:	std_logic;
signal 	burst,bstop:	std_logic;

begin
-------------------------------------------------------------------------------
--- hue value
-------------------------------------------------------------------------------
	process (HSL) is
	begin
		hue <= HSL(3 downto 0);	 --- hue value is the 4 LSB of the HSL input
		colorOn <= HSL(7);		 --- colorOn is the MSB of the HSL input
	end process;

-------------------------------------------------------------------------------
--- DDS for carrier
-------------------------------------------------------------------------------
    process (clk32) is
    begin
		if (rising_edge(clk32)) then
			if (palNtsc = '0') then			--- PAL
				carrier <= carrier + 9080;
			else							--- NTSC
				carrier <= carrier + 7331;
			end if;
		end if;
    end process;

-------------------------------------------------------------------------------
--- burst generator
-------------------------------------------------------------------------------
    process (bcounter) is
    begin
		if (bcounter="0000") then
			bstop <= '1';
		else
			bstop <= '0';
		end if;
    end process;

    process (hsync,bstop,carrier(15)) is
    begin
		if (hsync='1') then
			bcounter <= "0100";
		elsif ((rising_edge(carrier(15))) and (bstop='0'))  then
			bcounter <= bcounter + 1;
		end if;
    end process;

    burst <= bcounter(3);

-------------------------------------------------------------------------------
--- odd/even line and line counter
-------------------------------------------------------------------------------
	process (hsync) is
    begin
		if rising_edge(hsync) then
			if vsync='0' then
				if (palNtsc='0') then
					oddeven <= not(oddeven); -- this is the "AL" in pAL (Alternate Line), not needed for NTSC
				else
					oddeven <= '0';
				end if;
				vcounter <= vcounter + 1;
			elsif (vsync='1') then
				vcounter <= "0000000000";
			end if;
		end if;
    end process;


-------------------------------------------------------------------------------
--- carrier phase
-------------------------------------------------------------------------------
    process (hue,burst,oddeven) is
    begin
		if (burst='1') then
			if ((oddeven = '0') and (palNtsc='0')) then
				phase <= "0110";			--- burst phase 135 deg
			else
				phase <= "1010";			--- burst phase -135 deg
			end if;
		else
			if (oddeven = '0') then
				phase <= hue;
			else
				phase <= 0 - hue;
			end if;
		end if;
    end process;

-------------------------------------------------------------------------------
--- modulated carrier
-------------------------------------------------------------------------------
    scarrier <= carrier(15 downto 12) + phase;

-------------------------------------------------------------------------------
--- chroma 
-------------------------------------------------------------------------------
process (clk32, colorEnable) is
begin
	if (rising_edge(clk32)) then
		if (colorEnable='1') then
			if (burst='1') then
				if (vcounter > "0000000101") then
					chroma(0) <= scarrier(3);
					chroma(1) <= 'Z';
				end if;
			elsif ((blanking = '0') and (colorOn='1')) then
				chroma(0) <= 'Z';
				chroma(1) <= scarrier(3);
			else
				chroma(0) <= 'Z';
				chroma(1) <= 'Z';
			end if;
		else
			chroma(0) <= 'Z';
 			chroma(1) <= 'Z';
		end if;
	end if;
end process;

end architecture color_gen;
