# Lydia Lee
# Created 2019/06/27

# Code for generating binary files of received bits with or 
# without PPM packets depending on user specification.

import numpy as np
import scipy as sp
import matplotlib.pyplot as plt
import doctest
from math import ceil
from ppm_base import ppm_mod_vals, ppm_mod_bits


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
		
		In all of the above (preamble, sfd0, sfd1, etc.) the LSB is on
		the right and the MSB goes on the leftmost index.
	"""
	# Creating random packet data based on specified data length
	p_datalen_octets_str = ''.join([str(i) for i in p_datalen])
	p_datalen_octets_dec = int(p_datalen_octets_str, 2)

	symbols_per_octet = int(ceil(8/np.log2(chips_per_symbol)))
	demod_bits_per_symbol = int(np.log2(chips_per_symbol))
	p_datalen_bits_demod = demod_bits_per_symbol * symbols_per_octet \
							* p_datalen_octets_dec
	p_data_demod = np.random.randint(2, size=p_datalen_bits_demod)
	
	# Constructing the packet first as chips, then converting to bits
	packet_demod = preamble*2 + sfd0 + sfd1 + p_version \
		+ p_id + p_seqcontr + p_datalen + list(p_data_demod)
	packet = ppm_mod_bits(packet_demod, chips_per_symbol, \
						bits_per_chip, mode=None)
	# packet = np.array([[c]*bits_per_chip for c in packet_chips])
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
	num_rows = 40
	chips_per_row = 16
	chips_per_symbol = 16
	bits_per_chip = 2
	
	outputFile = './bleh.b'
	rx_rand_data(outputFile, num_rows, chips_per_row, chips_per_symbol, bits_per_chip, mode='rand')
