`timescale 1ps/1ps
/*
    Author: Lydia Lee
    Created: 2019/06/26
    Description:
        Testbench for ppm16_demod.v
*/

module tb_ppm16_demod();
    localparam [1:0] ALIGN_ROW = 2'b00;
    localparam [1:0] ALIGN_CHIP = 2'b01;
    localparam [1:0] ALIGN_NONE = 2'b10;
    
    /* ------------------------------------ */
    /* ----------- Change These ----------- */
    /* ------------------------------------ */
    parameter CHIP_BITS = 3;
    parameter CLK_PERIOD = 1000;
    parameter ALIGNMENT = ALIGN_NONE;
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
            integer chip_count;
            integer bit_count;
            
            localparam NUM_ROWS        = 100;
            localparam CHIPS_PER_ROW   = 16;
            
            // 100 rows, each with 16 chips
            reg [CHIPS_PER_ROW*CHIP_BITS-1:0]       rx_bits_flat [NUM_ROWS-1:0];
            reg [CHIP_BITS-1:0]                     rx_bits [NUM_ROWS-1:0][CHIPS_PER_ROW-1:0];
            reg [CHIP_BITS-1:0]                     curr_row [CHIPS_PER_ROW-1:0];
            reg [CHIP_BITS-1:0]                     curr_chip;
            reg                                     curr_bit;
            
            string align;
            string chip_bits;
            
            // Input file name based on settings
            case (CHIP_BITS)
                3: chip_bits = "3";
                1: chip_bits = "1";
            endcase
            
            case (ALIGNMENT)
                ALIGN_ROW:  align = "Row";
                ALIGN_CHIP: align = "Chip";
                ALIGN_NONE: align = "None";
            endcase
            
            // Reading from the file and setting up the file to write results to
            //$readmemb({"falseNeg_", "chip", chip_bits, "_align", align, ".b"}, rx_bits_flat);
            // FILE_result = $fopen({"falseNeg_", "chip", chip_bits, "_align", align, "_result.txt"}, "w");
            $readmemb("/tools/B/lydialee/camera/SPAD/verilog/PPM/bleh.b", rx_bits_flat);
            FILE_result = $fopen("/tools/B/lydialee/camera/SPAD/verilog/PPM/bleh_result.txt", "w");
            
            // Unflattening the bits read from the file
            for(row_count=0; row_count<NUM_ROWS; row_count=row_count+1) begin
                for(chip_count=0; chip_count<CHIPS_PER_ROW; chip_count=chip_count+1) begin
                    rx_bits[row_count][chip_count] = rx_bits_flat[row_count]
                                                        [CHIP_BITS-1:0];
                end
            end
            
            // Clean startup sequence
            corr_threshold = 3'b001;
            @(posedge clk);
            resetn = 1'b0;
            @(posedge clk);
            resetn = 1'b1;
            @(posedge clk);
            rx_start = 1'b1;
            @(posedge clk);
            rx_start = 1'b0;
            
            // Feeding the info to the demodulator
            for(row_count=0; row_count<NUM_ROWS; row_count=row_count+1) begin
                for(chip_count=0; chip_count<CHIPS_PER_ROW; chip_count=chip_count+1) begin
                    for(bit_count=0; bit_count<CHIP_BITS; bit_count=bit_count+1) begin
                        @(posedge clk)
                        curr_row = rx_bits[row_count];
                        curr_chip = curr_row[chip_count];
                        //curr_bit = curr_chip[bit_count];
                        din = curr_chip[bit_count];
                    end
                end
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
