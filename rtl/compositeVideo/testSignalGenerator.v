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
    output reg [7:0] videoOut,                     // HSL  output, format 1:3:4  1 saturation, 3 luma, 4 chroma
    output reg hSync,                              // Horizontal sync
    output reg vSync,                              // Vertical sync
    output reg blanking,                           // Blanking signal
    output reg [1:0] saturationValue = 2'b10       // Saturation (default = 2)

);

    /*
        	                    PAL	    NTSC
    ---------------------------------------
    Whole Scanline	       64μs    63.55μs
    Front Porch	           1.65μs  1.5μs
    H-Sync pulse	           4.7μs	 4.7μs
    Back Porch	              5.7μs	 4.5μs
    Blanking period (total) 12.05μs	10.7μs
    'Active Display' period 51.95μs 52.9μs
	 number of lines		      312    262
	 ---------------------------------------
    */

    reg videoEnable = 1'b1;                             // Video enable (1) or sync only (0)
    reg hBlank = 1'b0;                                  // Horizontal blanking
    reg vBlank = 1'b0;                                  // Vertical blanking
    reg [11:0] lineTime = 12'd2048;                     // @32 Mhz = 2048 cycles for PAL (64uS)
    reg [8:0] frontPorch = 9'd53;                       // @32 Mhz = 53   cycles for PAL (1.65uS)
    reg [8:0] hsyncPulse = 9'd150;                      // @32 Mhz = 150  cycles (both PAL and NTSC)
    reg [8:0] backPorch = 9'd183;                       // @32 Mhz = 182  cycles for PAL (5.7uS)
    reg [10:0] videoTime = 11'd1662;                    // @32 Mhz = 1662 cycles for PAL (52uS)
    reg [8:0] hBlankTime = 9'd386;                      // frontPorch + hsyncPulse + backPorch;
    reg [9:0] numberOfLines = 10'd312;                  // Number of lines for PAL (312) or NTSC (262)
    reg [3:0] startChromaValue = 4'b0;                  // Start chroma value (default = 0)
    reg [3:0] chromaValue = 4'b0;                       // Chroma value (default = 0)
    reg [2:0] lumaValue = 3'b111;                      // Luma value (default = 7)

    reg [3:0] pattern = 2'b0;                           // Pattern (default = 0)
    reg [10:0] hCount = 11'd0;                          // Horizontal counter
    reg [10:0] vCount = 11'd0;                          // Vertical counter
    reg [10:0] dotCount = 11'd0;                        // Dot counter
    reg [3:0] chromaTemp;                               // Temporary variable
    reg [3:0] lumaTemp;                                 // Temporary variable
    reg [1:0] saturationTemp;                           // Temporary variable
    reg [2:0] colorBarIndex = 3'b0;                     // Color index
    reg [3:0] colorBarChroma[7:0];                      // Color bar chroma values
    reg [2:0] colorBarLuma[7:0];                        // Color bar luma values
    reg [0:0] colorBarSaturation[7:0];                  // Color bar saturation values

    initial begin
        colorBarChroma[0] = 4'b0000;        // White
        colorBarChroma[1] = 4'b0111;        // Yellow
        colorBarChroma[2] = 4'b1101;        // Cyan
        colorBarChroma[3] = 4'b1011;        // Green
        colorBarChroma[4] = 4'b0011;        // Magenta
        colorBarChroma[5] = 4'b0101;        // Red
        colorBarChroma[6] = 4'b0000;        // Blue
        colorBarChroma[7] = 4'b0000;        // Black

        colorBarLuma[0] = 3'b111;           // White
        colorBarLuma[1] = 3'b110;           // Yellow
        colorBarLuma[2] = 3'b101;           // Cyan
        colorBarLuma[3] = 3'b100;           // Green
        colorBarLuma[4] = 3'b011;           // Magenta
        colorBarLuma[5] = 3'b010;           // Red
        colorBarLuma[6] = 3'b001;           // Blue
        colorBarLuma[7] = 3'b000;           // Black

        colorBarSaturation[0] = 1'b0;       // White
        colorBarSaturation[1] = 1'b1;       // Yellow
        colorBarSaturation[2] = 1'b1;       // Cyan
        colorBarSaturation[3] = 1'b1;       // Green
        colorBarSaturation[4] = 1'b1;       // Magenta
        colorBarSaturation[5] = 1'b1;       // Red
        colorBarSaturation[6] = 1'b1;       // Blue
        colorBarSaturation[7] = 1'b0;       // Black
    end

    always @(posedge clk32) begin

        blanking <= hBlank | vBlank | ~videoEnable;

        if (hCount < lineTime)
            hCount <= hCount + 1'b1;
        else
            begin
                hCount <= 11'd0;
                if (vCount < numberOfLines) begin
                    vCount <= vCount + 1'b1;
                    vSync <= 1'b0;
                end else begin
                    vCount <= 10'd0;
                    vSync <= 1'b1;
                end
            end

        if (hCount < hBlankTime)
            begin
                hBlank <= 1'b1;
                dotCount <= 11'b0;
                colorBarIndex <= 0;
            end
        else
            hBlank <= 1'b0;

        if (hCount == frontPorch)
            hSync <= 1'b1;
        else if (hCount == frontPorch + hsyncPulse)
            hSync <= 1'b0;

        if (keyboardInterrupt == 1'b1) begin
            case (keyboardScanCode)
                8'h4D: begin
                    palNtsc <= 1'b0;                              // Pal video standard
                    lineTime <= 12'd2048;                         // @32 Mhz = 2048 cycles for PAL (64uS)
                    frontPorch <= 9'd53;                          // @32 Mhz = 53   cycles for PAL (1.65uS)
                    hsyncPulse <= 9'd150;                         // @32 Mhz = 150  cycles (both PAL and NTSC)
                    backPorch <= 9'd183;                          // @32 Mhz = 182  cycles for PAL (5.7uS)
                    videoTime <= 11'd1662;                        // @32 Mhz = 1662 cycles for PAL (52uS)
                    hBlankTime <= 9'd386;                         // frontPorch + hsyncPulse + backPorch;
                    numberOfLines <= 10'd312;                     // Number of lines for PAL (312)
                end
                8'h31: begin
                    palNtsc <= 1'b1;                              // NTSC video standard
                    lineTime <= 12'd2034;                         // @32 Mhz = 2034 cycles for NTSC (63.56uS)
                    frontPorch <= 9'd48;                          // @32 Mhz = 48   cycles for NTSC (1.5uS)
                    hsyncPulse <= 9'd150;                         // @32 Mhz = 150  cycles (both PAL and NTSC)
                    backPorch <= 9'd145;                          // @32 Mhz = 144  cycles for NTSC (4.5uS)
                    videoTime <= 11'd1693;                        // @32 Mhz = 1693 cycles for NTSC (52.9uS)
                    hBlankTime <= 9'd342;                         // frontPorch + hsyncPulse + backPorch;
                    numberOfLines <= 10'd262;                     // Number of lines for NTSC (262)
                end
                8'h33: begin
                    palNtsc <= 1'b0;                              // PAL60 video standard (NTSC timing with PAL color subcarrier)
                    lineTime <= 12'd2034;                         // @32 Mhz = 2034 cycles for NTSC (63.56uS)
                    frontPorch <= 9'd48;                          // @32 Mhz = 48   cycles for NTSC (1.5uS)
                    hsyncPulse <= 9'd150;                         // @32 Mhz = 150  cycles (both PAL and NTSC)
                    backPorch <= 9'd145;                          // @32 Mhz = 144  cycles for NTSC (4.5uS)
                    videoTime <= 11'd1693;                        // @32 Mhz = 1693 cycles for NTSC (52.9uS)
                    hBlankTime <= 9'd342;                         // frontPorch + hsyncPulse + backPorch;
                    numberOfLines <= 10'd262;                     // Number of lines for NTSC (262)
                end
                8'h35: colorEnable <= 1'b0;                             // B&W
                8'h2D: colorEnable <= 1'b1;                             // Color
                8'h1B: videoEnable <= 1'b0;                             // Sync only
                8'h2A: videoEnable <= 1'b1;                             // Video
                8'h72: startChromaValue <= startChromaValue + 4'b0001;  // Increase chroma value
                8'h75: startChromaValue <= startChromaValue - 4'b0001;  // Decrease chroma value
                8'h6B: lumaValue <= lumaValue + 3'b001;                // Increase luma value
                8'h74: lumaValue <= lumaValue - 3'b001;                // Decrease luma value
                8'h3A: saturationValue <= saturationValue + 2'b01;      // Increase saturation value
                8'h4B: saturationValue <= saturationValue - 2'b01;      // Decrease saturation value
                8'h22: pattern <= pattern + 2'b01;                      // Next pattern
                8'h1A: pattern <= pattern - 2'b01;                      // Previous pattern
            endcase
        end

        if (hBlank == 1'b0 && vBlank == 1'b0 && videoEnable == 1'b1) begin
            dotCount <= dotCount + 1'b1;
            case(pattern)
                2'b00: begin    // Color bars White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
                    if (dotCount > 11'd208)
                        begin
                            dotCount <= 11'd0;
                            colorBarIndex <= colorBarIndex + 1'b1;
                            chromaTemp <= colorBarChroma[colorBarIndex];
                            lumaTemp <= colorBarLuma[colorBarIndex];
                            saturationTemp <= colorBarSaturation[colorBarIndex];
                            videoOut <= {saturationTemp, lumaTemp, chromaTemp};
                        end
                    end
                2'b01: begin
                    if (dotCount > 11'd104) // 16 Color bars, changable luma and saturation
                        begin
                            dotCount <= 11'd0;
                            colorBarIndex <= colorBarIndex + 1'b1;
                            chromaTemp <= colorBarIndex + startChromaValue;
                            videoOut <= {saturationValue[1], lumaValue, chromaTemp};
                        end
                    end
                2'b10:  // solid color
                    videoOut <= {1'b1, lumaValue, startChromaValue};
                2'b11: begin // grayscale from white to black
                        if (dotCount < 11'd200)
                        begin
                            chromaTemp <= 4'b1111;
                            lumaTemp <= 3'b111;
                        end else begin
                            if (dotCount % 10 == 0) begin
                                if (chromaTemp != 4'b0000)
                                    chromaTemp <= chromaTemp - 4'b0001;
                                else if (lumaTemp != 3'b000) begin
                                    lumaTemp <= lumaTemp - 3'b001;
                                    chromaTemp <= 4'b1111;
                                end
                            end
                        end
                        videoOut <= {1'b1, lumaTemp, chromaTemp};
                    end
            endcase
        end else
            videoOut <= {1'b0, 3'b000, 4'b0000};
    end
endmodule
