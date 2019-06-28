`timescale 1ps/1ps
/*
    Author: Lydia Lee
    Created: 2019/06/26
    Description:
        Testbench for ppm16_demod.v
*/

module tb_ppm16_demod();
    
    /* ------------------------------------ */
    /* ----------- Change These ----------- */
    /* ------------------------------------ */
    parameter CHIP_BITS = 2;
    parameter CLK_PERIOD = 1000;
    /* ------------------------------------ */
    /* ------------------------------------ */
    /* ------------------------------------ */
    
    integer FILE_result;
    
    reg                 clk;
    reg                 resetn;
    reg                 din;
    reg                 rx_start;
    reg [CHIP_BITS-1:0] corr_threshold;
    wire                packet_detected;
    wire                dout_valid;
    wire [3:0]          dout;
    
    always #(CLK_PERIOD/2) clk <= ~clk;
    
    ppm16_demod #(.CHIP_BITS(CHIP_BITS)) u_ppm16_demod (
        .clk(clk),
        .resetn(resetn),
        .din(din),
        .rx_start(rx_start),
        .corr_threshold_ext(corr_threshold),
        .packet_detected(packet_detected),
        .dout_valid(dout_valid),
        .dout(dout),
        .DEMOD_state_SC(),
        .DEMOD_next_state_SC(),
        .DEMOD_shifted_bits_SC(),
        .DEMOD_corr_input_valid_SC(),
        .DEMOD_corr_threshold_SC(),
        .DEMOD_corr_symbol_SC(),
        .DEMOD_corr_peak_value_SC(),
        .DEMOD_corr_threshold_unmet_SC(),
        .DEMOD_shift_new_bit_SC(),
        .DEMOD_chip_bit_count_SC(),
        .DEMOD_symbol_chip_count_SC(),
        .DEMOD_primary_header1_symbol_count_SC(),
        .DEMOD_primary_header2_symbol_count_SC(),
        .DEMOD_data_field_symbol_count_SC(),
        .DEMOD_max_chip_bit_count_SC(),
        .DEMOD_max_symbol_chip_count_SC(),
        .DEMOD_max_primary_header1_symbol_count_SC(),
        .DEMOD_max_primary_header2_symbol_count_SC(),
        .DEMOD_max_data_field_symbol_count_SC(),
        .DEMOD_increment_chip_bit_count_SC(),
        .DEMOD_increment_symbol_chip_count_SC(),
        .DEMOD_increment_primary_header1_symbol_count_SC(),
        .DEMOD_increment_primary_header2_symbol_count_SC(),
        .DEMOD_increment_data_field_symbol_count_SC(),
        .DEMOD_packet_data_length_symbols_SC(),
        .DEMOD_load_len_msb_SC(),
        .DEMOD_load_len_lsb_SC(),
        .DEMOD_packet_detected_SC(),
        .DEMOD_dout_valid_SC());
    
    /* ----------------------------- */
    /* ----------------------------- */
    /* ----------- TESTS ----------- */
    /* ----------------------------- */
    /* ----------------------------- */
    task test_false_negative;
        begin : test_false_neg
            /*
                Purpose is to test for false negatives.
            */
            integer row_count;
            integer bit_count;
            
            /* ------------------------------------ */
			/* ----------- Change These ----------- */
			/* ------------------------------------ */
            localparam NUM_ROWS        = 40;
            localparam CHIPS_PER_ROW   = 16;
			/* ------------------------------------ */
			/* ------------------------------------ */
			/* ------------------------------------ */
            
            // Rread as rows of bits
            reg [CHIPS_PER_ROW*CHIP_BITS-1:0] rx_bits [NUM_ROWS-1:0];
            reg [CHIPS_PER_ROW*CHIP_BITS-1:0] curr_row ;
            reg curr_bit;
            
            // Reading from the file and setting up the file to write results to
            $readmemb("/tools/B/lydialee/camera/spad-comms/PPM/verilog/bleh.b", rx_bits);
            FILE_result = $fopen("/tools/B/lydialee/camera/spad-comms/PPM/verilog/bleh_result.txt", "w");
            
            // Clean startup sequence
            @(posedge clk);
            @(posedge clk);
            @(posedge clk);
            corr_threshold = 1'b1;
            @(posedge clk);
            resetn = 1'b0;
            @(posedge clk);
            resetn = 1'b1;
            @(posedge clk);
            rx_start = 1'b1;
            @(posedge clk);
            rx_start = 1'b0;
            
            // Feeding the info to the demodulator
            row_count = 0;
            while (row_count < NUM_ROWS) begin
                curr_row = rx_bits[row_count];
                //$display(rx_bits[row_count]);
                bit_count = 0;
                while (bit_count < CHIP_BITS*CHIPS_PER_ROW) begin
                    curr_bit = curr_row[bit_count];
                    din = curr_row[bit_count];
                    @(posedge clk)
                    bit_count = bit_count + 1;
                end
                row_count = row_count + 1;
            end
            $fclose(FILE_result);
        end
    endtask
    
    /* -------------------------------- */
    /* -------------------------------- */
    /* ----------- Main Run ----------- */
    /* -------------------------------- */
    /* -------------------------------- */
    initial begin
        $display("Turning on VCDPlus...");
        $vcdpluson();
        $display("VCDPlus on");
        
        clk = 1'b0;
        resetn = 1'b1;
        din = 1'b0;
        rx_start = 1'b0;

        test_false_negative();

        $vcdplusoff();
        $finish;
    end
    
    // Packet detection
    always @(posedge packet_detected) begin
        $display("PACKET DETECTED AT TIME %d us", $time);
    end
    
    // Write to the file for each valid output
    always @(posedge clk) begin
        if(dout_valid) begin
            $fwrite(FILE_result, "%1d", dout);
        end
    end
endmodule
