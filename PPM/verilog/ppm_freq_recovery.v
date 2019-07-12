`timescale 1ps/1ps
`include "/tools/B/lydialee/camera/spad-comms/PPM/verilog/chips.vh"
/*
    Author: Lydia Lee
    Created: 2019/07/10
    Description:
    	The frequency recovery portion of clock and data recovery. Assumes 
    	one chip per cycle input. Given the structure of the preamble,
    	counts the number of clock cycles between each pulse of the modulated
    	preamble and compares it against the 
*/

module ppm_freq_recovery #(
	parameter CHIP_BITS = 1,
	parameter SYMBOL_CHIPS = 16
	)(
	input clk,
	input resetn,
	input [CHIP_BITS-1:0] din,
	input [CHIP_BITS-1:0] pulse_threshold,
	input freq_ok, // TODO: Output?
	
	output pulse_detected,
	output [`ceilLog2(SYMBOL_CHIPS):0] interpulse_cycles,	// Intentional doubling
	output [1:0] intrasymbol_pulses,
	// output [] dac_bits TODO: conversion to DAC bits
	
	// Scan chain connections
	output wire [1:0] 							FREQ_state_SC,
	output wire [1:0] 							FREQ_next_state_SC,
	output wire [1:0] 							FREQ_intrasymbol_pulse_count_SC,
	output wire [`ceilLog2(SYMBOL_CHIPS)-1:0] 	FREQ_symbol_cycle_count_SC,
	output wire [`ceilLog2(SYMBOL_CHIPS):0] 	FREQ_interpulse_cycle_count_SC,
	output wire 								FREQ_max_symbol_cycle_count_SC,
	output wire 								FREQ_max_interpulse_cycle_count_SC,
	output wire 								FREQ_increment_symbol_cycle_count_SC,
	output wire 								FREQ_increment_interpulse_cycle_count_SC);
	
	// FSM states
	localparam [1:0] S_IDLE 	= 2'b00;
	localparam [1:0] S_SCAN		= 2'b01;
	localparam [1:0] S_PULSE1 	= 2'b10;
	localparam [1:0] S_PULSE2	= 2'b11;
	
	reg [1:0] state;
	reg [1:0] next_state;
	
	// Counters and their associated signals
	reg [1:0] intrasymbol_pulse_count;
	reg [`ceilLog2(SYMBOL_CHIPS)-1:0] symbol_cycle_count;
	reg [`ceilLog2(SYMBOL_CHIPS):0] interpulse_cycle_count;	// Intentional doubling
	
	wire new_symbol_cycle_count;
	wire max_symbol_cycle_count;
	wire max_interpulse_cycle_count;
	
	reg increment_symbol_cycle_count;
	reg increment_interpulse_cycle_count;
	
	// Registered outputs
	reg [`ceilLog2(SYMBOL_CHIPS):0] r_interpulse_cycles;
	reg [1:0] r_intrasymbol_pulses;
	
	assign pulse_detected = freq_ok ? 1'b0 : din >= pulse_threshold;
	assign new_symbol_cycle_count = (symbol_cycle_count == {(`ceilLog2(SYMBOL_CHIPS)){1'b0}});
	assign max_symbol_cycle_count = (symbol_cycle_count == {(`ceilLog2(SYMBOL_CHIPS)){1'b1}});
	assign max_interpulse_cycle_count = (interpulse_cycle_count == {(`ceilLog2(SYMBOL_CHIPS)+1){1'b1}});
	
	// FSM state progression
	always @(*) begin
		next_state = state;
		case (state)
			S_IDLE: if (~freq_ok) next_state = S_SCAN;
			S_SCAN: begin
				if (freq_ok) next_state = S_IDLE;
				else if (pulse_detected) next_state = S_PULSE1;
			end
			S_PULSE1: begin
				if (freq_ok) next_state = S_IDLE;
				else if (pulse_detected) next_state = S_PULSE2;
			end
			S_PULSE2: begin
				if (freq_ok) next_state = S_IDLE;
				else if (max_symbol_cycle_count) next_state = S_PULSE1;
			end
		endcase
	end
	
	always @(posedge clk) begin
		if (~resetn) state <= S_IDLE;
		else state <= next_state;
	end
	
	// FSM output progression
	always @(*) begin
		increment_symbol_cycle_count = 1'b0;
		increment_interpulse_cycle_count = 1'b0;
		
		case (state)
			S_IDLE: begin
			end
			S_SCAN: begin
				increment_symbol_cycle_count = 1'b1;
			end
			S_PULSE1: begin
				increment_symbol_cycle_count = 1'b1;
				increment_interpulse_cycle_count = 1'b1;
			end
			S_PULSE2: begin
				increment_symbol_cycle_count = 1'b1;
				increment_interpulse_cycle_count = 1'b1;
			end
		endcase
	end
	
	// Counter incrementing: intrasymbol pulses
	always @(posedge clk) begin
		if (~resetn) begin
			intrasymbol_pulse_count <= 2'b00;
			symbol_cycle_count = {(SYMBOL_CHIPS){1'b0}};
			r_intrasymbol_pulses <= 2'b00;
		end else if (max_symbol_cycle_count) begin
			symbol_cycle_count <= increment_symbol_cycle_count ? {(SYMBOL_CHIPS){1'b0}} : 
										symbol_cycle_count;
			intrasymbol_pulse_count <= ~pulse_detected ? 2'b00 : 
										intrasymbol_pulse_count == 2'b11 ? 2'b11 : 
										intrasymbol_pulse_count + 1'b1;
			r_intrasymbol_pulses <= ~pulse_detected ? intrasymbol_pulse_count : 
										intrasymbol_pulse_count == 2'b11 ? 2'b11 : 
										intrasymbol_pulse_count + 1'b1;
		end else begin 
			symbol_cycle_count <= increment_symbol_cycle_count ? symbol_cycle_count + 1'b1 : 
										symbol_cycle_count;
			if (new_symbol_cycle_count && pulse_detected) intrasymbol_pulse_count <= 2'b01;
			else if (new_symbol_cycle_count) intrasymbol_pulse_count <= 2'b00;
			else if (pulse_detected) intrasymbol_pulse_count <= (intrasymbol_pulse_count == 2'b11) ? 2'b11 : 
											intrasymbol_pulse_count + 1'b1;
		end
	end
	
	// Counter incrementing: interpulse clock cycles
	always @(posedge clk) begin
		if (~resetn) interpulse_cycle_count <= {(SYMBOL_CHIPS+1){1'b0}};
		else if (increment_interpulse_cycle_count) begin
			if (pulse_detected) begin
				interpulse_cycle_count <= {(SYMBOL_CHIPS+1){1'b0}};
				r_interpulse_cycles <= interpulse_cycle_count;
			end else interpulse_cycle_count <= max_interpulse_cycle_count ? 
							{(`ceilLog2(SYMBOL_CHIPS)+1){1'b1}} : interpulse_cycle_count + 1'b1;
		end
	end
	
	// Output assignments
	assign intrasymbol_pulses = r_intrasymbol_pulses;
	assign interpulse_cycles = r_interpulse_cycles;
	
	// Scan chain connections
	assign FREQ_state_SC = state;
	assign FREQ_next_state_SC = next_state;
	assign FREQ_intrasymbol_pulse_count_SC = intrasymbol_pulse_count;
	assign FREQ_symbol_cycle_count_SC = symbol_cycle_count;
	assign FREQ_interpulse_cycle_count_SC = interpulse_cycle_count;
	assign FREQ_max_symbol_cycle_count_SC = max_symbol_cycle_count;
	assign FREQ_max_interpulse_cycle_count_SC = max_interpulse_cycle_count;
	assign FREQ_increment_symbol_cycle_count_SC = increment_symbol_cycle_count;
	assign FREQ_increment_interpulse_cycle_count_SC = increment_interpulse_cycle_count;
	assign FREQ_pulse_detected_SC = pulse_detected;
	
endmodule
