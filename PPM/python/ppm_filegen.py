# Lydia Lee
# Created 2019/06/27

import numpy as np
import scipy as sp
import matplotlib.pyplot as plt
import doctest
from math import ceil

def ppm_mod_vals(values, chips_per_symbol, bits_per_chip, mode='rev'):
	"""
	Inputs:
		values: Collection of integers (not bits) to encode. Individual value
			must not exceed the radix.
		chips_per_symbol: Number of chips to use for a single symbol in the
			PPM encoding.
		bits_per_chip: Number of bits associated with a single chip. For 
			values >1, binary 1 is converted to the max possible (unsigned)
			value.
		mode: 'rev' means the LSB of a symbol goes in the 0th index, otherwise the MSB
			goes in the 0th index.
	Outputs:
		Returns a flattened array where elements 0 to chips_per_symbol-1 
		correspond to the PPM form of the 0th element in values, etc.

	>>> values = [1, 2, 3]
	>>> expected_output = [0,0,0,0,1,1,0,0] + [0,0,1,1,0,0,0,0] + [1,1,0,0,0,0,0,0]
	>>> output = ppm_mod(values, 4, 2, None)
	>>> expected_output == list(output)
	True
	"""
	mod_values = []
	for val in values:
		# Check that the value doesn't exceed the max possible value
		if val >= chips_per_symbol:
			raise ValueError("{0} > Max {1}".format(val, chips_per_symbol))
		
		# The value indicates where the high value should go amongst the 0s
		mod_val = [0]*(chips_per_symbol-val-1)*bits_per_chip \
					+ [1]*bits_per_chip \
					+ [0]*val*bits_per_chip
					
		if mode == 'rev':
			mod_val = mod_val[::-1]
			
		mod_values.extend(mod_val)
	return np.asarray(mod_values)

def ppm_mod_bits(symbols, chips_per_symbol, bits_per_chip, mode='rev'):
	"""
	Inputs:
		symbols: Flattened collection of 0 and 1 where each grouping of
			bits constitutes a symbol.
		chips_per_symbol: Number of chips to use for a single symbol in the
			PPM encoding.
		bits_per_chip: Number of bits associated with a single chip. For 
			values >1, binary 1 is converted to the max possible (unsigned)
			value.
		mode: 'rev' means the LSB of a symbol goes in the 0th index, otherwise the MSB
			goes in the 0th index.
	Outputs:
		Returns a flattened array where the symbols have been modulated 
		using chips_per_symbol-PPM and bits_per_chip.
	"""
	bits_per_symbol = int(np.log2(chips_per_symbol))
	symbols_unflat = [symbols[i*bits_per_symbol : (i+1)*bits_per_symbol] \
		for i in range((len(symbols)+bits_per_symbol-1)//bits_per_symbol)]
	values = [int(''.join(map(str,symbol)), 2) for symbol in symbols_unflat]
	return ppm_mod_vals(values, chips_per_symbol, bits_per_chip, mode=mode)

def rx_uniform(outputFile, num_rows, chips_per_row, bits_per_chip, val=0):
	"""
	Inputs:
		outputFile: String. Path and name of the file to write to.
		num_rows: Integer. Number of rows in the file. This is largely
			intended for convenience, and it's recommended that each row
			contain enough chips to constitute one symbol, though symbols
			need not start at the beginning of the row (i.e. misalignment). 
		chips_per_row: Integer. Number of chips per row. Recommend that this
			be the number of chips per symbol.
		bits_per_chip: Integer. Number of bits per chip in the encoding scheme.
		val: Integer 1 or 0. The value to fill the rows with.
	Outputs:
		No return value. Writes to 'outputFile' rows of 'val'.
	"""
	with open(outputFile, 'w+') as file:
		for r in range(num_rows):
			file.write(''.join([str(val)]*chips_per_row*bits_per_chip+'\n'))
	return

def rx_rand_data(outputFile, num_rows, chips_per_row, chips_per_symbol, bits_per_chip,
				preamble=[0,0,0,0], sfd0=[0,1,1,1], sfd1=[1,0,1,0],
				p_version=[0,0,0], p_id=[1]*13, p_seqcontr=[0,1]+[0]*14,
				p_datalen=[0]*16, mode='rand'):
	"""
	Inputs:
		outputFile: String. Path and name of the file to write to.
		num_rows: Integer. Number of rows in the file. This is largely
			intended for convenience, and it's recommended that each row
			contain enough chips to constitute one symbol, though symbols
			need not start at the beginning of the row (i.e. misalignment). 
		chips_per_row: Integer. Number of chips per row. Recommend this being
			equal to the chips per symbol for simplicity in the Verilog
			testbench.
		chips_per_symbol: Integer. Number of chips per symbol in the encoding
			scheme. Recommended this match chips_per_row for ease of use.
		bits_per_chip: Integer. Number of bits per chip in the encoding scheme.
		preamble: List of integers. The symbol associated with the preamble.
		sfd0: List of 1 and 0. Symbol associated with first start symbol.
		sfd1: List of 1 and 0. Symbol associated with second start symbol.
		p_version: List of 1 and 0. Packet version.
		p_id: List of 1 and 0. Packet identification field.
		p_seqcontr: List of 1 and 0. Packet sequence control field.
		p_datalen: List of 1 and 0. (# of octets)-1 in the data length field.
			Packet data is randomized.
		mode: String 'rand', 'zero', 'one'. Specifies what goes in the non-packet
			regions of the transmitted bits.
	Outputs:
		No return value. Writes to 'outputFile' with the fully constructed 
		packet randomly placed somewhere in the file. Format is what the 
		receiver sees (so it's modulated with PPM). This intentionally transmits
		a single packet, and everything else is randomized.
	Raises:
		ValueError if the specified number of chips is insufficient to fit the
			packet, this will append them to the end anyhow.
	Note:
		See either the Overleaf or referenced recommendation		
			https://www.overleaf.com/project/5ceff4266413dd65856e722e
			https://public.ccsds.org/Pubs/133x0b1c2.pdf
			for more detail on the packet construction.
			
		For the chipping sequence, the LSB comes last. 
	"""
	# Creating random packet data based on specified data length
	p_datalen_octets_str = ''.join([str(i) for i in p_datalen])
	p_datalen_octets_dec = int(p_datalen_octets_str, 2)

	symbols_per_octet = int(ceil(8/np.log2(chips_per_symbol)))
	demod_bits_per_symbol = int(np.log2(chips_per_symbol))
	p_datalen_bits_demod = demod_bits_per_symbol*symbols_per_octet*p_datalen_octets_dec
	p_data_demod = np.random.randint(2, size=p_datalen_bits_demod)
	
	# Constructing the packet first as chips, then converting to bits
	packet_demod = preamble*2 + sfd0 + sfd1 + p_version \
		+ p_id + p_seqcontr + p_datalen + list(p_data_demod)
	packet_chips = ppm_mod_bits(packet_demod, chips_per_symbol, bits_per_chip, mode=None)
	packet = np.array([[c]*bits_per_chip for c in packet_chips])
	packet = packet.flatten()

	# Checking that the packet will fit in the size specified
	total_bits = num_rows*chips_per_row*bits_per_chip
	if total_bits < len(packet):
		raise ValueError("Packet larger than no. of chips specified")

	# Deciding on the (random) location to start the packet
	loc = np.random.randint(total_bits-len(packet))
	bits_per_row = bits_per_chip*chips_per_row
	
	with open(outputFile, 'w+') as file:
		idx = 0
		col = 0
		write_str = ''
		while idx < total_bits:
			# Constructing the row to write
			if idx >= loc and idx < loc+len(packet):
				write_str = write_str + str(packet[idx-loc]) 
			elif mode == 'zero':
				write_str = write_str + '0'
			elif mode == 'one':
				write_str = write_str + '1'
			else:
				write_str = write_str + str(np.random.randint(2)) 
			
			# End of the row
			if col == bits_per_row-1:
				col = 0
				file.write(write_str[::-1]+'\n')
				write_str = ''
			else:
				col = col + 1

			idx = idx + 1
	return

if __name__ == "__main__":
	num_rows = 100
	chips_per_row = 16
	chips_per_symbol = 16
	bits_per_chip = 4
	
	outputFile = './bleh.b'
	rx_rand_data(outputFile, num_rows, chips_per_row, chips_per_symbol, bits_per_chip, mode='one')
