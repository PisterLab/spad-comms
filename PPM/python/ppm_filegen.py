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
				p_datalen=[0]*16, mode='rand', 
				sigma_tx=0, sigma_bg=0):
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
		sigma_tx: Float. Standard deviation (in chips) to inject into the packet. Does
			not inject noise into the non-packet regions.
		sigma_bg: Float. Standard deviation (in bits) to inject into the background
			of all transmitted bits.
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
	
	# Constructing the packet first as chips and inserting TX noise
	# (if any)
	packet_demod_noiseless = preamble*2 + sfd0 + sfd1 + p_version \
		+ p_id + p_seqcontr + p_datalen + list(p_data_demod)
	if sigma_tx != 0:
		noise_tx = np.random.normal(loc=0, scale=sigma_tx, 
							size=len(packet_demod_noiseless))
	else:
		noise_tx = np.zeros(len(packet_demod_noiseless))
	packet_demod_noisy = list(np.asarray(packet_demod_noiseless) + noise_tx)
	packet_demod_noisy = [int(i) for i in packet_demod_noisy]
	packet = ppm_mod_bits(packet_demod_noisy, chips_per_symbol, \
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
			if sigma_bg != 0:
				noise_bg = np.random.normal(loc=0, scale=sigma_bg)
			else:
				noise_bg = 0
			if idx >= loc and idx < loc+len(packet):
				val = packet[idx-loc]
			elif mode == 'zero':
				val = 0
			elif mode == 'one':
				val = 1
			else:
				val = np.random.randint(2)

			val = min(int(round(val + noise_bg)), 1)
			write_str = write_str + str(val)
			# End of the row
			if col == bits_per_row-1:
				col = 0
				file.write(write_str[::-1]+'\n')
				write_str = ''
			else:
				col = col + 1

			idx = idx + 1
	return

def tx_data_arb(inputFile, outputFile, channelCount, sampleRate,
	fileFormat="1.10", columnChar="TAB", highLevel=1, lowLevel=0, dataType='Short',
	filterOn=False):
	"""
	Inputs:
		inputFile: Path to the file with the data bits to be transmitted.
		outputFile: Path to the .arb file to write to.
		channelCount: Integer 1 or 2. The channel to use on the waveform
			generator.
		sampleRate: Integer. Data rate in Hz. Don't use scientific notation.
		fileFormat: String. Unknown purpose. It's likely some version of something.
		columnChar: String. Unknown purpose. Likely some method of including something 2D?
		highLevel: Float. Voltage level(?) for logic high.
		lowLevel: Float. Voltage level(?) for logic low.
		dataType: String. Unknown, but I'm guessing it's the number of bits to use
			for resolution when writing.
		filterOn: Boolean. Unknown purpose.
	Outputs:
		No return value. Writes the .arb file to 'outputFile' based on the data from
		'inputFile' and the rest of the specs.
	"""
	if filterOn:
		filterTxt = '"ON"'
	else:
		filterTxt = '"OFF"'
	
	header = "File Format:{0}\n".format(fileFormat) + \
		"Channel Count:{0}\n".format(str(channelCount)) + \
		"Column Char:{0}\n".format(columnChar) + \
		"Sample Rate:{0}\n".format(str(sampleRate)) + \
		"High Level:{0}\n".format(str(highLevel)) + \
		"Low Level:{0}\n".format(str(lowLevel)) + \
		'Data Type:"{0}"\n'.format(dataType) + \
		"Filter:{0}\n".format(filterTxt)
		
	with open(outputFile, 'w+') as fileOut:
		with open(inputFile, 'r') as fileIn:
			# Check what size restrictions are on read(), or this could get
			# unwieldy.
			txt_in = fileIn.read()
			data_points = len(txt_in) - txt_in.count('\n')
			header = header + "Data Points:{0}\n".format(str(data_points)) + \
				"Data:\n"
			fileOut.write(header)
		with open(inputFile, 'r') as fileIn:
			for line in fileIn.readlines():
				line_rev = line[::-1]
				line_rev = line_rev.replace('\n', '')
 				fileOut.write('\n'.join(line_rev)+'\n')

if __name__ == "__main__":
	# Generating and transmitting a single valid data packet in the midst
	# of random nonsense.
	if True:
		rx_data_specs = dict(
			outputFile = "../verilog/bleh.b",
			num_rows = 20,
			chips_per_row = 16,
			chips_per_symbol = 16,
			bits_per_chip = 2,
			mode = 'rand')
		
		rx_rand_data(**rx_data_specs)
		
		
	# Reading in .b file for arbitrary TX
	if False:
		tx_arb_specs = dict(
			inputFile="../verilog/bleh.b",
			outputFile="../arb/bleh.arb",
			channelCount=1,
			sampleRate=100000,
			fileFormat="1.10",
			columnChar="TAB",
			highLevel=1,
			lowLevel=0,
			dataType="Short",
			filterOn=False)
			
		tx_data(**tx_arb_specs)
