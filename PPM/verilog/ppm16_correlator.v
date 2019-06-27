`timescale 1ps/1ps
/*
    Author: Lydia Lee
    Created: 2019/06/25
    Description:
        Correlator for 16-bit pulse-position modulation. Given a threshold, finds and
        returns the index of the largest pulse which passes the threshold. If
        no value surpasses the threshold, threshold_unmet goes high.
        
        0000_0000_0010_0000__0000_0000_0000_0001 -> 5_1 -> 0101_0001
*/
module ppm16_correlator #(
    parameter CHIP_BITS = 1     // Number of bits per chip
    )(
    input unsigned [CHIP_BITS-1:0]  chips_in        [15:0],
    input                           input_valid,
    input unsigned [CHIP_BITS-1:0]  corr_threshold,
    
    output wire [3:0]               symbol,
    output wire [CHIP_BITS-1:0]     peak_value,
    output wire                     threshold_unmet
    );

    reg [3:0] idx_comp0   [7:0];
    reg [3:0] idx_comp1   [3:0];
    reg [3:0] idx_comp2   [1:0];
    reg [3:0] idx_comp3;
    
    wire unsigned [CHIP_BITS-1:0]    din         [15:0];
    
    // Input is 0 when calculation isn't needed to save power
    genvar j;
    generate
        for (j=0; j<16; j=j+1) begin
            assign din[j] = input_valid ? chips_in[j] : {(CHIP_BITS){1'b0}};
        end
    endgenerate
    
    // Find the index with the largest magnitude pulse
    // N chips requires N-1 comparators
    genvar i;
    generate
        for (i=0; i<16; i=i+2) begin
            always @(*) idx_comp0[i/2] = (din[i] < din[i+1]) ? i+1 : i;
        end
        
        for (i=0; i<8; i=i+2) begin
            always @(*) idx_comp1[i/2] = (din[idx_comp0[i]] < din[idx_comp0[i+1]]) ? 
                idx_comp0[i+1] : idx_comp0[i];
        end
        
        for (i=0; i<4; i=i+2) begin
            always @(*) idx_comp2[i/2] = (din[idx_comp1[i]] < din[idx_comp1[i+1]]) ? 
                idx_comp1[i+1] : idx_comp1[i];
        end
    endgenerate
    
    always @(*) idx_comp3 = din[idx_comp2[0]] < din[idx_comp2[1]] ? idx_comp2[1] : idx_comp2[0];

    // Assign visible outputs
    assign peak_value = din[idx_comp3];
    assign threshold_unmet = din[idx_comp3] < corr_threshold;    
    assign symbol = idx_comp3;

    
endmodule
