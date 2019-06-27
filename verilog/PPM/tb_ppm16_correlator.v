`timescale 1ps/1ps
/*
    Author: Lydia Lee
    Created: 2019/06/25
    Description:
        Testbench for ppm16_correlator.v
*/

module tb_ppm16_correlator();
    parameter CHIP_BITS = 3;
    parameter CLK_PERIOD = 1000;

    reg                     clk;
    reg [CHIP_BITS-1:0]     chips_in [15:0];
    reg                     input_valid;
    reg [CHIP_BITS-1:0]     corr_threshold;
    reg [3:0]               symbol;
    reg [CHIP_BITS-1:0]     peak_value;
    reg                     threshold_unmet;

    always #(CLK_PERIOD/2) clk <= ~clk;
    
    ppm16_correlator #(.CHIP_BITS(CHIP_BITS)) u_correlator (
        .chips_in(chips_in),
        .input_valid(input_valid),
        .corr_threshold(corr_threshold),
        .symbol(symbol),
        .peak_value(peak_value),
        .threshold_unmet(threshold_unmet));
        
    initial begin
        $display("Turning on VCDPlus...");
        $vcdpluson();
        $display("VCDPlus on");
        
        $display("Initializing chips");
        input_valid = 1'b0;
        corr_threshold = 3'b010;
        chips_in = {0,0,0,0,
                    6,3,2,1,
                    0,0,1,2,
                    5,4,3,2};
                    
        $display("Chips In");
        $display(chips_in);
        
        #(CLK_PERIOD*10);
        
        clk = 1'b0;
        input_valid = 1'b1;
        
        #(CLK_PERIOD*5);
        
        input_valid = 1'b0;
        
        #(CLK_PERIOD*5);
        
        input_valid = 1'b1;
        corr_threshold = 3'b111;
        
        #(CLK_PERIOD*5);
        
        $vcdplusoff();
        $finish;
    end
endmodule
