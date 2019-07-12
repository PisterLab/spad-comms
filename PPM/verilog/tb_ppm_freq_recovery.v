`timescale 1ps/1ps
`include "/tools/B/lydialee/camera/spad-comms/PPM/verilog/definitions.vh"

/*
    Author: Lydia Lee
    Created: 2019/07/11
    Description:
    	Testbench for ppm_freq_recovery.v. Feeds 1 chip per cycle to the 
    	frequency recovery module.
*/
module tb_ppm_freq_recovery();
	// I've implemented 16-PPM, so don't change this unless
	// you have an alternative M-PPM.
	parameter SYMBOL_CHIPS = 16;
	
	/* ------------------------------------ */
	/* ----------- Change These ----------- */
	/* ------------------------------------ */
	
	// Number of bits needed to represent the SPAD
	// count.
	parameter CHIP_BITS = 1;
	
	// Clock period
	parameter CLK_PERIOD = 1000;
	
	// File read-in parameters
    parameter NUM_ROWS = 40;
    parameter CHIPS_PER_ROW = 16;
	/* ------------------------------------ */
	/* ------------------------------------ */
	/* ------------------------------------ */
	
	integer FILE_result;
	
	reg 					clk;
	reg [CHIP_BITS-1:0] 	din;
	reg [CHIP_BITS-1:0] 	pulse_threshold;
	reg 					freq_ok;
	reg 					resetn;
	wire [SYMBOL_CHIPS:0] 	interpulse_cycles;
	wire [1:0] 				intrasymbol_pulses;
	
	always #(CLK_PERIOD/2) clk <= ~clk;
	
	ppm_freq_recovery #(.CHIP_BITS(CHIP_BITS), .SYMBOL_CHIPS(SYMBOL_CHIPS))
		u_freq_recovery (
		.clk(clk),
		.resetn(resetn),
		.din(din),
		.pulse_threshold(pulse_threshold),
		.freq_ok(freq_ok),
		.interpulse_cycles(interpulse_cycles),
		.intrasymbol_pulses(intrasymbol_pulses),
		.FREQ_state_SC(),
		.FREQ_next_state_SC(),
		.FREQ_intrasymbol_pulse_count_SC(),
		.FREQ_symbol_cycle_count_SC(),
		.FREQ_interpulse_cycle_count_SC(),
		.FREQ_max_symbol_cycle_count_SC(),
		.FREQ_max_interpulse_cycle_count_SC(),
		.FREQ_increment_symbol_cycle_count_SC(),
		.FREQ_increment_interpulse_cycles_SC(),
		.FREQ_pulse_detected_SC());
	
	/* ----------------------------- */
	/* ----------------------------- */
	/* ----------- TESTS ----------- */
	/* ----------------------------- */
	/* ----------------------------- */
	task test_freq_counting;
		begin: test_freq_count
			/*
				Test if the interpulse cycles and intrasymbol pulses
				(number of cycles between pulses and number of pulses within
				the number of cycles that should make up a symbol) increment
				correctly.
			*/
			reg [CHIPS_PER_ROW*CHIP_BITS-1:0] rx_bits [NUM_ROWS-1:0];
	        reg [CHIPS_PER_ROW*CHIP_BITS-1:0] curr_row;
	        reg [CHIP_BITS-1:0] curr_chip;
	        
	        string start;
	        
	        // Read in the RX data and open the appropriate files
	        start = "/tools/B/lydialee/camera/spad-comms/PPM/verilog/binary/freq_rand";
			$readmemb({start, ".b"}, rx_bits);
			FILE_result = $fopen({start, "_result.txt"}, "w");
			// Clean startup sequence
			@(posedge clk);
		    @(posedge clk);
		    @(posedge clk);
    	    pulse_threshold = {1'b1, {CHIP_BITS-1}{1'b0}};
    	    @(posedge clk);
    	    resetn = 1'b0;
    	    @(posedge clk);
    	    resetn = 1'b1;
    	    @(posedge clk);
    	    freq_ok = 1'b0;
    	    
    	    // Feeding the data into the frequency recovery logic
    	    row_count = 0;
		    while (row_count < NUM_ROWS) begin
		        curr_row = rx_bits[row_count];
		        chip_count = 0;
		        while (chip_count < CHIPS_PER_ROW) begin
		        	curr_chip = curr_row[chip_count*CHIP_BITS +: CHIP_BITS];
		            din = curr_row[(chip_count+1)*CHIP_BITS-1 -: CHIP_BITS];
		            @(posedge clk)
		            chip_count = chip_count + 1;
		        end
		        row_count = row_count + 1;
		    end
		    $fclose(FILE_result);
		end
	endtask
	
	task test_jitter_effect;
		begin: test_jitter
			
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
	    freq_ok = 1'b1;
	    
	    test_freq_counting();
	    
	    $vcdplusoff();
	    $finish;
	end
endmodule
