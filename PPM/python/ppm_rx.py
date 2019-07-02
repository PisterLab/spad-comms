# Lydia Lee
# Created 2019/07/01

from math import ceil

def rx_ppm_packet_vals(inputFile, chips_per_symbol, bits_per_chip,
				preamble_val=0, sfd0_val=7, sfd1_val=10,
				threshold_ext=0):
	"""
	Inputs:
		inputFile: String. Path to the binary file with the received data. 
			The LSB should be in the 0th element of a symbol.
		chips_per_symbol: Integer. Number of chips per symbol in the encoding
			scheme.
		bits_per_chip: Integer. Number of bits per chip in the encoding scheme.
		preamble_val: Integer. The symbol converted to decimal associated with 
			the preamble.
		sfd0_val: Integer. The symbol converted to decimal associated with first 
			start symbol.
		sfd1_val: Integer. The symbol converted to decimal associated with the 
			second start symbol.
		threshold_ext: Integer. External threshold for determining if the correlator
			output is more than just noise. Only used when looking for the start
			of a packet.
	Outputs:
		Assumes only one packet sent! Returns the demodulated packet (list of bits) 
		where the most recently-received element goes at the end of the list.
	Notes:
		WORK IN PROGRESS. Don't use!
	"""
	# Useful constants
	bits_per_symbol = bits_per_chip*chips_per_symbol
	demod_bits_per_symbol = int(ceil(np.log2(chips_per_symbol)))
	
	# Yup, it's an FSMlightroom
	s_scan = 0
	s_preamblematch1 = 1
	s_preamblematch2 = 2
	s_sfdmatch = 3
	s_primaryheader1 = 4
	s_datafield = 5
	state = s_scan
	
	# Counters
	bit_count = 0
	primary_header_symbol_count = 0
	data_field_symbol_count = 0
	
	# Keeping track of the data
	corr_input = [0]*bits_per_symbol
	corr_idx = 0
	primary_header_val = []
	data_field = []
	
	with open(inputFile, 'r') as f:
		for i, line in enumerate(f):
			line_rev = line[::-1].replace('\n', '')
			for c in line_rev:
				corr_input = corr_input[:len(corr_input)-1] + [c]
				# Scanning for the preamble
				if state == s_scan:
					corr_output_vals, threshold_met = ppm_demod_bit_vals(corr_input,
							chips_per_symbol, bits_per_chip, threshold=threshold_ext)
					if corr_output_vals[0] == preamble_val and threshold_met[0]:
						state = s_preamblematch1
				# First instance of preamble symbol found, read in
				# another symbol, and then look for second instance 
				# of preamble symbol
				elif state == s_preamblematch1:
					if bit_count < bits_per_symbol:
						bit_count = bit_count + 1
					else:
						corr_output_vals, threshold_met = ppm_demod_bit_vals(
							corr_input, chips_per_symbol, bits_per_chip, 
							threshold=threshold_ext)
						bit_count = 0
						if corr_output_vals[0] == preamble_val:
							state = s_preamblematch2
						else:
							state = scan
				# Second instance of preamble symbol found, read in another
				# symbol, look for SFD0
				elif state == s_preamblematch2:
					if bit_count < bits_per_symbol:
						bit_count = bit_count + 1
					else:
						corr_output_vals, threshold_met = ppm_demod_bit_vals(
							corr_input, chips_per_symbol, bits_per_chip, 
							threshold=threshold_ext)
						bit_count = 0
						if corr_output_vals[0] == sfd0_val:
							state = s_sfdmatch
						elif corr_output_vals[0] != preamble_val:
							state = s_scan
				# SFD0 found, read in another symbol, look for SFD1
				elif state == s_sfdmatch:
					if bit_count < bits_per_symbol:
						bit_count = bit_count + 1
					else:
						corr_output_vals, threshold_met = ppm_demod_bit_vals(
							corr_input, chips_per_symbol, bits_per_chip, 
							threshold=threshold_ext)
						bit_count = 0
						if corr_output_vals[0] == sfd1_val:
							state = s_primaryheader1
						else:
							state = s_scan
				# SFD1 found, reading in primary header data
				# Accumulate the number of 
				elif state == s_primaryheader:
					if bit_count < bits_per_symbol:
						bit_count = bit_count + 1
					else:
						corr_output_vals, threshold_met = ppm_demod_bit_vals(
							corr_input, chips_per_symbol, bits_per_chip, 
							threshold=threshold_ext)
						bit_count = 0
						if primary_header_symbol_count == 12:
							primary_header_symbol_count = 0
							data_field_octets = sum(np.asarray(primary_header[])* \
								np.asarray([2**i for i in corr_output_vals]))
							data_field_symbols = int(ceil(data_field_octets/ \
								demod_bits_per_symbol))
							state = s_datafield
						else:
							primary_header = primary_header + corr_output_vals
							primary_header_symbol_count = \
								primary_header_symbol_count + 1
				# Reading in 
				elif state == s_datafield:
				else:
					raise ValueError("")
