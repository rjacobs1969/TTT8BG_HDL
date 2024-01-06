/*

************************************************************

NTSC / PAL test signal generator for FPGA written in Verilog

Connected to a PS/2 keyboard interface it can change the generated output

left or right arrow (or numeric kp 4, and 6): increase or decrease luminance
down or up arrow (or numeric kp 2, and 8): rotate color values

c key: Color output (default)
b key: Black and white output
p key: PAL output
h key: PAL60 output (NTSC timing with PAL color subcarrier)
n key: NTSC output
s key: Sync only output (no video)
v key: Video output (default)
m key: Increase saturation
l key: Decrease saturation
z key: previous pattern
x key: next pattern
Copyright (c) 2024 by Robin Jacobs (elholandes44@gmail.com)

************************************************************

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

module testBarSignalGenerator (
    input wire clk32,                              // System clock 32Mhz
    input wire keyboardInterrupt,                  // Interrupt signal
    input wire [7:0] keyboardScanCode,             // 8 bit scancode

    output reg palNtsc,                            // PAL (0) or NTSC (1) video standard selection
    output reg colorEnable,                        // Color enable (1) or B&W (0)
    output reg [8:0] HSL ,                         // HSL  output, format 4:2:4
    output reg hsync,                              // Horizontal sync
    output reg vsync,                              // Vertical sync

    output wire blanking                           // Blanking signal


);

    /*
        	                    PAL	    NTSC
    --------------------------------------------
    Whole Scanline	            64μs	63.55μs
    Front Porch	                1.65μs	1.5μs
    H-Sync pulse	            4.7μs	4.7μs
    Back Porch	                5.7μs	4.5μs
    Blanking period (total)	    12.05μs	10.7μs
    'Active Display' period	    51.95μs	52.9μs
    */

    reg videoEnable = 1'b1;                             // Video enable (1) or sync only (0)
    reg hBlank = 1'b0;                                  // Horizontal blanking
    reg vBlank = 1'b0;                                  // Vertical blanking
    reg [10:0] lineTime = 11'd2048;                     // @32 Mhz = 2048 cycles for PAL (64uS)
    reg [8:0] frontPorch = 9'd53;                       // @32 Mhz = 53   cycles for PAL (1.65uS)
    reg [8:0] hsyncPulse = 9'd150;                      // @32 Mhz = 150  cycles (both PAL and NTSC)
    reg [8:0] backPorch = 9'd183;                       // @32 Mhz = 182  cycles for PAL (5.7uS)
    reg [10:0] videoTime = 11'd1662;                    // @32 Mhz = 1662 cycles for PAL (52uS)
    reg [8:0] hblankTime = 9'd386;                      // frontPorch + hsyncPulse + backPorch;
    reg [9:0] numberOfLines = 10'd312;                  // Number of lines for PAL (312) or NTSC (262)
    reg [3:0] startChromaValue = 4'b0;                  // Start chroma value (default = 0)
    reg [3:0] lumaValue = 4'b0111;                      // Luma value (default = 7)
    reg [1:0] SaturationValue = 2'b11;                  // Saturation (default = 3, max)
    reg [3:0] pattern = 2'b0;                           // Pattern (default = 0)
    reg [10:0] hCount = 11'd0;                          // Horizontal counter
    reg [9:0] vCount = 10'd0;                           // Vertical counter

    always @(posedge clk32) begin

        if   (hCount < lineTime)
            hCount <= hCount + 1'b1;
        else
            begin
                hCount <= 11'd0;
                if (vCount < numberOfLines)
                    vCount <= vCount + 1'b1;
                else
                    vCount <= 10'd0;
            end

        if (hCount < hblankTime)
            hBlank <= 1'b1;
        else
            hBlank <= 1'b0;

        if (hCount == frontPorch)
            hSync <= 1'b1;
        else if (hCount == frontPorch + hsyncPulse)
            hSync <= 1'b0;

        if (keyboardInterrupt = 1'b1) begin
            case (keyboardScanCode)
                8'h4D: begin
                    palNtsc <= 1'b0;                              // Pal video standard
                    lineTime <= 11'd2048;                         // @32 Mhz = 2048 cycles for PAL (64uS)
                    frontPorch <= 9'd53;                          // @32 Mhz = 53   cycles for PAL (1.65uS)
                    hsyncPulse <= 9'd150;                         // @32 Mhz = 150  cycles (both PAL and NTSC)
                    backPorch <= 9'd183;                          // @32 Mhz = 182  cycles for PAL (5.7uS)
                    videoTime <= 11'd1662;                        // @32 Mhz = 1662 cycles for PAL (52uS)
                    hblankTime <= 9'd386;                         // frontPorch + hsyncPulse + backPorch;
                    numberOfLines <= 10'd312;                     // Number of lines for PAL (312)
                end
                8'h31: begin
                    palNtscSel <= 1'b1;                           // NTSC video standard
                    lineTime <= 11'd2034;                         // @32 Mhz = 2034 cycles for NTSC (63.56uS)
                    frontPorch <= 9'd48;                          // @32 Mhz = 48   cycles for NTSC (1.5uS)
                    hsyncPulse <= 9'd150;                         // @32 Mhz = 150  cycles (both PAL and NTSC)
                    backPorch <= 9'd145;                          // @32 Mhz = 144  cycles for NTSC (4.5uS)
                    videoTime <= 11'd1693;                        // @32 Mhz = 1693 cycles for NTSC (52.9uS)
                    hblankTime <= 9'd342;                         // frontPorch + hsyncPulse + backPorch;
                    numberOfLines <= 10'd262;                     // Number of lines for NTSC (262)
                end
                8'h33: begin
                    palNtscSel <= 1'b0;                           // PAL60 video standard (NTSC timing with PAL color subcarrier)
                    lineTime <= 11'd2034;                         // @32 Mhz = 2034 cycles for NTSC (63.56uS)
                    frontPorch <= 9'd48;                          // @32 Mhz = 48   cycles for NTSC (1.5uS)
                    hsyncPulse <= 9'd150;                         // @32 Mhz = 150  cycles (both PAL and NTSC)
                    backPorch <= 9'd145;                          // @32 Mhz = 144  cycles for NTSC (4.5uS)
                    videoTime <= 11'd1693;                        // @32 Mhz = 1693 cycles for NTSC (52.9uS)
                    hblankTime <= 9'd342;                         // frontPorch + hsyncPulse + backPorch;
                    numberOfLines <= 10'd262;                     // Number of lines for NTSC (262)
                end
                8'h35: colorEnable <= 1'b0;                             // B&W
                8'h2D: colorEnable <= 1'b1;                             // Color
                8'h1B: videoEnable <= 1'b0;                             // Sync only
                8'h2A: videoEnable <= 1'b1;                             // Video
                8'h72: startChromaValue <= startChromaValue + 4'b0001;  // Increase chroma value
                8'h75: startChromaValue <= startChromaValue - 4'b0001;  // Decrease chroma value
                8'h6B: lumaValue <= LumaValue + 3'b0001;                // Increase luma value
                8'h74: lumaValue <= LumaValue - 3'b0001;                // Decrease luma value
                8'h3A: saturationValue <= saturationValue + 2'b01;      // Increase saturation value
                8'h4B: saturationValue <= saturationValue - 2'b01;      // Decrease saturation value
                8'h22: pattern <= pattern + 2'b01;                      // Next pattern
                8'h1A: pattern <= pattern - 2'b01;                      // Previous pattern
            endcase
        end

    end
endmodule
