/*

************************************************************

Luma generator for FPGA written in Verilog

It uses a 3 resistor ladder to generate the analog signal,
however in black and white mode the least significant bit is created
with a delta sigma modulator to increase the resolution of the signal
from 8 luminance levels to 128 using the unused chroma bits as LSB's

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

module lumaGeneration (
    input wire clk128,                             // Fast clock clock for the delta sigma modulator
    input wire [7:0] videoIn,                      // 8 bit format 1:3:4  1 bit saturation (0 = b/w, 1 = color), 3 bits luma, 4 chroma which become the LSB's of luma when in B/W mode
    input wire blanking,                           // Blanking signal, 1 = blanking, 0 = active video
    input wire cSync,                              // Composite sync signal, 1 = sync, 0 = video

    output reg [2:0] lumaOut,                      // luma output (3 bits)
    output reg syncOut                             // Sync output
);

reg [5:0] PWM_accumulator;

always @(posedge clk128) begin

    lumaOut <= videoIn[6:4];
    if (cSync) begin
        syncOut <= 1'b0;                                // Sync signal active low
        lumaOut <= 3'b0;                                // no video when sync is active
    end else begin
        syncOut <= 1'b1;                                // Sync signal is always 1 (except during sync)
       // if (blanking)
       //     lumaOut <= 3'b0;                            // Blanking, output black
      //  else if (videoIn[7] == 1'b1)
            //lumaOut <= videoIn[6:4];                    // Color mode, output simple 3 bit luma
       // else if (videoIn[4:0] == 5'b11111)
      //      lumaOut <= videoIn[6:4];                    // highest value for LSB no need for delta sigma modulator
      //  else if (videoIn[4:0] == 5'b00000)
      //      lumaOut <= videoIn[6:4];                    // lowest value for LSB, no need for delta sigma modulator
      //  else begin
      //      PWM_accumulator <= PWM_accumulator + videoIn[4:0];
      //      if (PWM_accumulator[5])
      //          lumaOut <= {videoIn[6:5], 1'b1};
      //      else
      //          lumaOut <= {videoIn[6:5], 1'b0};
       // end
    end
end

endmodule