`timescale 1ps/1ps
`include "/tools/B/lydialee/camera/spad-comms/PPM/verilog/chips.vh"
/*
    Author: Lydia Lee
    Created: 2019/06/25
    Description:
        8-bit pulse-position modulation demodulator. Output is fed into a FIFO.
        
        Because of noise and background signal, we may need to represent each
        pulse with more than a single bit. We do this by using the SPAD count
        to give each pulse a "magnitude", and the bit-position with the 
        largest magnitude is the location of the 1 in the pulse bits. For 
        example, comparing traditional PPM against using 2 bits per chip:
        
        0010_1000 could be either 0010_0000 or 0000_1000
        0030_1000 is definitively 0010_1000
*/

module ppm16_demod #(
    parameter CHIP_BITS = 1     // Number of bits per chip
    )(
    input clk,
    input resetn,
    input din,
    input rx_start,
    input [CHIP_BITS-1:0] corr_threshold_ext,
    output packet_detected,
    output dout_valid,
    output [3:0] dout,

    
    // Scan chain connections
    output wire [2:0]                       DEMOD_state_SC,
    output wire [2:0]                       DEMOD_next_state_SC,
    output wire [16*CHIP_BITS-1:0]          DEMOD_shifted_bits_SC,
    output wire                             DEMOD_corr_input_valid_SC,
    output wire [CHIP_BITS-1:0]             DEMOD_corr_threshold_SC,
    output wire [3:0]                       DEMOD_corr_symbol_SC,
    output wire [CHIP_BITS-1:0]             DEMOD_corr_peak_value_SC,
    output wire                             DEMOD_corr_threshold_unmet_SC,
    output wire                             DEMOD_shift_new_bit_SC,
    output wire [`ceilLog2(CHIP_BITS)-1:0]  DEMOD_chip_bit_count_SC,
    output wire [3:0]                       DEMOD_symbol_chip_count_SC,
    output wire [2:0]						DEMOD_preamble2_symbol_count_SC,
    output wire [2:0]                       DEMOD_primary_header1_symbol_count_SC,
    output wire [1:0]                       DEMOD_primary_header2_symbol_count_SC,
    output wire [15:0]                      DEMOD_data_field_symbol_count_SC,
    output wire                             DEMOD_max_chip_bit_count_SC,
    output wire                             DEMOD_max_symbol_chip_count_SC,
    output wire                             DEMOD_max_primary_header1_symbol_count_SC,
    output wire                             DEMOD_max_primary_header2_symbol_count_SC,
    output wire                             DEMOD_max_data_field_symbol_count_SC,
    output wire                             DEMOD_increment_chip_bit_count_SC,
    output wire                             DEMOD_increment_symbol_chip_count_SC,
    output wire                             DEMOD_increment_primary_header1_symbol_count_SC,
    output wire                             DEMOD_increment_primary_header2_symbol_count_SC,
    output wire                             DEMOD_increment_data_field_symbol_count_SC,
    output wire [15:0]                      DEMOD_packet_data_length_symbols_SC,
    output wire                             DEMOD_packet_detected_SC,
    output wire                             DEMOD_dout_valid_SC
    );
    
    // FSM states
    localparam [2:0] S_IDLE             = 3'b000;
    localparam [2:0] S_SCAN             = 3'b001;
    localparam [2:0] S_PREAMBLE_MATCH1  = 3'b010;
    localparam [2:0] S_PREAMBLE_MATCH2  = 3'b011;
    localparam [2:0] S_SFD_MATCH        = 3'b100;
    localparam [2:0] S_PRIMARY_HEADER1  = 3'b101;
    localparam [2:0] S_PRIMARY_HEADER2  = 3'b110;
    localparam [2:0] S_DATA_FIELD       = 3'b111;
    
    // FSM connections
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Correlator connections
    reg [16*CHIP_BITS-1:0]  shifted_bits;
    wire [CHIP_BITS-1:0]    shifted_chips    [15:0];
    
    reg                     corr_input_valid;
    reg [CHIP_BITS-1:0]     corr_threshold;
    wire [3:0]              corr_symbol;
    wire [CHIP_BITS-1:0]    corr_peak_value;
    wire                    corr_threshold_unmet;
    
    // Counters and their various flags
    reg                             shift_new_bit;
    reg [`ceilLog2(CHIP_BITS)-1:0]  chip_bit_count;
    reg [3:0]                       symbol_chip_count;
    
    reg [2:0] 	preamble2_symbol_count;
    reg [2:0]   primary_header1_symbol_count;
    reg [1:0]   primary_header2_symbol_count;
    reg [15:0]  data_field_symbol_count;
    
    wire max_chip_bit_count;
    wire max_symbol_chip_count;
    wire max_preamble2_symbol_count;
    wire max_primary_header1_symbol_count;
    wire max_primary_header2_symbol_count;
    wire max_data_field_symbol_count;
    
    reg increment_chip_bit_count;
    reg increment_symbol_chip_count;
    reg increment_preamble2_symbol_count;
    reg increment_primary_header1_symbol_count;
    reg increment_primary_header2_symbol_count;
    reg increment_data_field_symbol_count;
    
    // Getting data field length
    reg [15:0] packet_data_length_symbols;
    reg [1:0] load_len_count;
    
    // Registered outputs
    reg r_packet_detected;
    reg r_dout_valid;
    
    // Partitioning incoming bits into chips for the correlator
    genvar i;
    generate
        for (i=0; i<16; i=i+1) begin: break_into_chips
            assign shifted_chips[i] = shifted_bits[(i+1)*CHIP_BITS-1:i*CHIP_BITS];
        end
    endgenerate
    
    ppm16_correlator #(.CHIP_BITS(CHIP_BITS)) u_ppm16_correlator(
        .chips_in(shifted_chips),
        .input_valid(corr_input_valid),
        .corr_threshold(corr_threshold),
        .symbol(corr_symbol),
        .peak_value(corr_peak_value),
        .threshold_unmet(corr_threshold_unmet));
    
    // Checking when the counters are at their max
    assign max_chip_bit_count =                 chip_bit_count == CHIP_BITS-1;
    assign max_symbol_chip_count =              symbol_chip_count == 4'b1111;
    assign max_preamble2_symbol_count = 		(preamble2_symbol_count == 3'b110);
    assign max_primary_header1_symbol_count =   (primary_header1_symbol_count == 3'b111);
    assign max_primary_header2_symbol_count =   (primary_header2_symbol_count == 2'b11);
    assign max_data_field_symbol_count =        (data_field_symbol_count == packet_data_length_symbols);
    
    // FSM output progression
    always @(*) begin
        corr_input_valid = 1'b0;
        corr_threshold = {(CHIP_BITS){1'b0}};
        
        shift_new_bit = 1'b1;
        
        increment_chip_bit_count = 1'b0;
        increment_symbol_chip_count = 1'b0;
        increment_preamble2_symbol_count = 1'b0;
        increment_primary_header1_symbol_count = 1'b0;
        increment_primary_header2_symbol_count = 1'b0;
        increment_data_field_symbol_count = 1'b0;
        
        r_packet_detected = 1'b0;
        r_dout_valid = 1'b0;
        case (state)
            S_IDLE: shift_new_bit = 1'b0;
            S_SCAN: begin
                corr_input_valid = 1'b1;
                corr_threshold = corr_threshold_ext;
            end
            S_PREAMBLE_MATCH1: begin
            	increment_chip_bit_count = 1'b1;
                increment_symbol_chip_count = 1'b1;
                corr_input_valid = max_symbol_chip_count && max_chip_bit_count;
            end 
            S_PREAMBLE_MATCH2: begin
                increment_chip_bit_count = 1'b1;
                increment_symbol_chip_count = 1'b1;
                increment_preamble2_symbol_count = 1'b1;
                corr_input_valid = max_symbol_chip_count && max_chip_bit_count;
            end
            S_SFD_MATCH: begin
                increment_chip_bit_count = 1'b1;
                increment_symbol_chip_count = 1'b1;
                corr_input_valid = max_symbol_chip_count && max_chip_bit_count;
            end
            S_PRIMARY_HEADER1: begin
                increment_chip_bit_count = 1'b1;
                increment_symbol_chip_count = 1'b1;
                increment_primary_header1_symbol_count = 1'b1;
                corr_input_valid = max_symbol_chip_count && max_chip_bit_count;
            end
            S_PRIMARY_HEADER2: begin
                increment_chip_bit_count = 1'b1;
                increment_symbol_chip_count = 1'b1;
                increment_primary_header2_symbol_count = 1'b1;
                corr_input_valid = max_symbol_chip_count && max_chip_bit_count;
            end
            S_DATA_FIELD: begin
                increment_chip_bit_count = 1'b1;
                increment_symbol_chip_count = 1'b1;
                increment_data_field_symbol_count = 1'b1;
                r_packet_detected = (chip_bit_count == {(`ceilLog2(CHIP_BITS)){1'b0}}) 
                                    && (symbol_chip_count == 4'b0000)
                                    && (data_field_symbol_count == {(16){1'b0}});
                if (max_symbol_chip_count && max_chip_bit_count) begin
                    corr_input_valid = 1'b1;
                    r_dout_valid = 1'b1;
                end
            end
        endcase
    end
    
    // FSM state progression
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: if (rx_start) next_state = S_SCAN;
            S_SCAN: begin
                if ((corr_symbol == `PREAMBLE_SYMBOL) 
                    && ~corr_threshold_unmet) next_state = S_PREAMBLE_MATCH1; 
            end
            S_PREAMBLE_MATCH1: begin
                if ((corr_symbol == `PREAMBLE_SYMBOL)
                    && ~corr_threshold_unmet
                    && max_chip_bit_count
                    && max_symbol_chip_count) next_state = S_PREAMBLE_MATCH2;
                else if (max_chip_bit_count
                    && max_symbol_chip_count) next_state = S_SCAN;
            end
            S_PREAMBLE_MATCH2: begin
                if (max_chip_bit_count
                    && max_symbol_chip_count 
                    && (corr_symbol == `PREAMBLE_SYMBOL)) next_state = S_PREAMBLE_MATCH2;
                else if (max_chip_bit_count
                    && max_symbol_chip_count
                    && max_preamble2_symbol_count
                    && (corr_symbol == `SFD0)) next_state = S_SFD_MATCH;
                else if (max_chip_bit_count
                    && max_symbol_chip_count) next_state = S_SCAN;
            end
            S_SFD_MATCH: begin
                if (max_chip_bit_count
                    && max_symbol_chip_count
                    && (corr_symbol == `SFD1)) next_state = S_PRIMARY_HEADER1;
                else if (max_chip_bit_count
                    && max_symbol_chip_count) next_state = S_SCAN;
            end
            S_PRIMARY_HEADER1: begin
                if (max_chip_bit_count
                    && max_symbol_chip_count 
                    && max_primary_header1_symbol_count) next_state = S_PRIMARY_HEADER2;
            end
            S_PRIMARY_HEADER2: begin
                if (max_chip_bit_count
                    && max_symbol_chip_count
                    && max_primary_header2_symbol_count) next_state = S_DATA_FIELD;
            end
            S_DATA_FIELD: begin
                if (max_chip_bit_count
                    && max_symbol_chip_count 
                    && max_data_field_symbol_count) next_state = S_IDLE;
            end
        endcase
    end

    // Counter incrementing: bits in a chip
    always @(posedge clk or negedge resetn) begin
        if (~resetn) begin
            chip_bit_count <= {(`ceilLog2(CHIP_BITS)){1'b0}};
        end else if (increment_chip_bit_count && max_chip_bit_count) begin
            chip_bit_count <= {(`ceilLog2(CHIP_BITS)){1'b0}};
        end else if (increment_chip_bit_count) chip_bit_count <= chip_bit_count + 1'b1;
    end
    
    // Counter incrementing: chips in a symbol
    always @(posedge clk or negedge resetn) begin
        if (~resetn) symbol_chip_count <= 4'b0000;
        else if (increment_chip_bit_count && max_chip_bit_count && increment_symbol_chip_count) begin
            symbol_chip_count <= max_symbol_chip_count ? 4'b0000 : symbol_chip_count + 1'b1;
        end
    end
    
    // Counter incrementing: symbols
    always @(posedge clk or negedge resetn) begin
        if (~resetn) begin
            primary_header1_symbol_count <= 4'b0000;
            primary_header2_symbol_count <= 1'b0;
            data_field_symbol_count <= {(16){1'b0}};
        end else if (increment_chip_bit_count && max_chip_bit_count
                    && increment_symbol_chip_count && max_symbol_chip_count) begin
            if (increment_preamble2_symbol_count) begin
            	if (~max_preamble2_symbol_count) preamble2_symbol_count <= preamble2_symbol_count + 1'b1;
            	else if (state == S_PREAMBLE_MATCH2) preamble2_symbol_count <= 3'b110;
            	else preamble2_symbol_count <= 3'b000;
           	end
            if (increment_primary_header1_symbol_count) primary_header1_symbol_count <= max_primary_header1_symbol_count ? 4'b0000 :
                                                                                    primary_header1_symbol_count + 1'b1;
            if (increment_primary_header2_symbol_count) primary_header2_symbol_count <= max_primary_header2_symbol_count ? 2'b00 :
            																			primary_header2_symbol_count + 1'b1;
            if (increment_data_field_symbol_count) data_field_symbol_count <= max_data_field_symbol_count ? {(16){1'b0}} :
                                                                                    data_field_symbol_count + 1'b1;
        end
    end
    
    // Loading the packet length field
    always @(posedge clk or negedge resetn) begin
        if (~resetn) packet_data_length_symbols <= {(16){1'b0}};
        case (primary_header2_symbol_count)
        	2'b00: packet_data_length_symbols[3:0] <= corr_symbol;
        	2'b01: packet_data_length_symbols[7:4] <= corr_symbol;
        	2'b10: packet_data_length_symbols[11:8] <= corr_symbol;
        	2'b11: packet_data_length_symbols[15:12] <= corr_symbol;
        endcase
    end
    
    // Shifting in new bits
    always @(posedge clk or negedge resetn) begin
        if (~resetn) shifted_bits <= {(16*CHIP_BITS){1'b0}};
        else if (shift_new_bit) shifted_bits <= {shifted_bits[16*CHIP_BITS-2:0], din};
    end
    
    // FSM state transition
    always @(posedge clk or negedge resetn) begin
        if (~resetn) state <= S_IDLE;
        else state <= next_state;
    end
    
    // Scan chain connections
    assign DEMOD_state_SC = state;
    assign DEMOD_next_state_SC = next_state;
    assign DEMOD_shifted_bits_SC = shifted_bits;
    assign DEMOD_corr_input_valid_SC = corr_input_valid;
    assign DEMOD_corr_threshold_SC = corr_threshold;
    assign DEMOD_corr_symbol_SC = corr_symbol;
    assign DEMOD_corr_peak_value_SC = corr_peak_value;
    assign DEMOD_corr_threshold_unmet_SC = corr_threshold_unmet;
    assign DEMOD_shift_new_bit_SC = shift_new_bit;
    assign DEMOD_chip_bit_count_SC = chip_bit_count;
    assign DEMOD_symbol_chip_count_SC = symbol_chip_count;
    assign DEMOD_primary_header1_symbol_count_SC = primary_header1_symbol_count;
    assign DEMOD_primary_header2_symbol_count_SC = primary_header2_symbol_count;
    assign DEMOD_data_field_symbol_count_SC = data_field_symbol_count;
    assign DEMOD_max_chip_bit_count_SC = max_chip_bit_count;
    assign DEMOD_max_symbol_chip_count_SC = max_symbol_chip_count;
    assign DEMOD_max_primary_header1_symbol_count_SC = max_primary_header1_symbol_count;
    assign DEMOD_max_primary_header2_symbol_count_SC = max_primary_header2_symbol_count;
    assign DEMOD_max_data_field_symbol_count_SC = max_data_field_symbol_count;
    assign DEMOD_increment_chip_bit_count_SC = max_chip_bit_count;
    assign DEMOD_increment_symbol_chip_count_SC = increment_symbol_chip_count;
    assign DEMOD_increment_primary_header1_symbol_count_SC = increment_primary_header1_symbol_count;
    assign DEMOD_increment_primary_header2_symbol_count_SC = increment_primary_header2_symbol_count;
    assign DEMOD_increment_data_field_symbol_count_SC = increment_data_field_symbol_count;
    assign DEMOD_packet_data_length_symbols_SC = packet_data_length_symbols;
    assign DEMOD_packet_detected_SC = packet_detected;
    assign DEMOD_dout_valid_SC = dout_valid;
    
    // Outputs
    assign packet_detected = r_packet_detected;
    assign dout_valid = r_dout_valid;
    assign dout = corr_symbol;
endmodule
