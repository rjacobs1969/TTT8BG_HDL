/*

A simple PS/2 keyboard interface for FPGA written in Verilog

Copyright (c) 2024 by Robin Jacobs

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

module ps2_keyboard (
    input wire clk32,                               // System clock 32Mhz, not critical but TIMOUT_VALUE and SAMPLE_DELAY must be adjusted for other frequencies
    input wire kbd_clk,                             // Keyboard clock line
    input wire kbd_dat,                             // Keyboard data line
    output reg	interrupt,                          // Interrupt signal
    output reg [7:0] scanCode                       // 8 bit scancode
);
    localparam TIMEOUT_VALUE = 3200;                // 100 uS at 32 Mhz
    localparam SAMPLE_DELAY = 10;                   // 10 cycles at 32 Mhz

    reg previousClock;                              // Previous clock value to detect clock edges
    reg bitDone;                                    // Flag to indicate that a bit has already been processed
    reg [14:0] debounceCnt;                         // Clock debounce filter counter
    reg [10:0] shiftRegister = 11'b0;               // Shift register for received data
    integer bitsCount = 0;                          // Number of bits received
    integer timeout = 0;                            // Bus timeout counter

    always @(posedge clk32) begin
        interrupt <= 1'b0;                          // Clear interrupt signal by default
                                                    // Timeout check to check if bus does not send any data for more than 100 uS
        if (timeout != 0)                           // Timeout counter is not zero
            timeout <= timeout - 1;                 // Decrement timeout counter
        else                                        // Timeout counter is zero
            bitsCount <= 0;                         // Reset bits counter

        if (previousClock != kbd_clk) begin			// Filter instability on the clock line, the clock should remain the same at least SAMPLE_DELAY cycles
				bitDone <= 1'b0;                    // It will be a new bit so it is not "done"
            debounceCnt <= SAMPLE_DELAY;            // Wait SAMPLE_DELAY cycles before sampling
            previousClock <= kbd_clk;               // Store clock edge to detect changes
        end else if (debounceCnt != 0) begin        // Debounce counter is not zero, wait more
            debounceCnt <= debounceCnt - 1;         // Decrement debounce counter
        end else if (previousClock == 1'b1 && bitDone == 1'b0) begin
            shiftRegister <= {kbd_dat, shiftRegister[10:1]};// Move data into shift register
            timeout <= TIMEOUT_VALUE;               // Reset timeout
            if (bitsCount < 10) begin
                bitsCount <= bitsCount + 1;
            end else begin                          // All 10 bits received
					 interrupt <= 1'b1;                  // Set interrupt signal
                bitsCount <= 0;                     // Reset bits counter
                scanCode <= shiftRegister[9:2];     // Output scancode
            end
            bitDone <= 1'b1;                        // Bit processed and wait for next one
        end
    end
endmodule
