# Lydia Lee
# Created 2019/06/28

# Basic utility functions (namely, modulation and demodulation) used 
# throughout the rest of the PPM code base. 

import numpy as np
import scipy as sp
import matplotlib.pyplot as plt
import doctest
from math import ceil

def ppm_mod_vals(values, chips_per_symbol, bits_per_chip, mode=None):
	"""
	Inputs:
		values: Collection of integers (not bits) to encode. Individual value
			must not exceed the chips per symbol.
		chips_per_symbol: Number of chips to use for a single symbol in the
			PPM encoding.
		bits_per_chip: Number of bits associated with a single chip. For 
			values >1, binary 1 is converted to the max possible (unsigned)
			value.
		mode: 'rev' means the LSB of a symbol goes in the 0th index, otherwise the MSB
			goes in the 0th index. Does not change the order of the symbols
			amongst one another.
	Outputs:
		Returns a flattened array where elements 0 to chips_per_symbol-1 
		correspond to the PPM form of the 0th element in values, etc.
		Note that the MSB goes in the 0th element.
	Raises:
		UserWarning if the intended symbol value is greater than what's permissible
		given the number of chips per symbol.

	>>> values = [1, 2, 3]
	>>> expected_output = [0,0,0,0,1,1,0,0] + [0,0,1,1,0,0,0,0] + [1,1,0,0,0,0,0,0]
	>>> output = ppm_mod_vals(values, 4, 2, None)
	>>> expected_output == list(output)
	True
	"""
	mod_values = []
	for val in values:
		# Check that the value doesn't exceed the max possible value
		if val >= chips_per_symbol:
			raise UserWarning("{0} > Max {1}".format(val, chips_per_symbol))
			val_mod = chips_per_symbol - 1
		else:
			val_mod = val
			
		# The value indicates where the high value should go amongst the 0s
		mod_val = [0]*(chips_per_symbol-val_mod-1)*bits_per_chip \
					+ [1]*bits_per_chip \
					+ [0]*val_mod*bits_per_chip
					
		if mode == 'rev':
			mod_val = mod_val[::-1]
			
		mod_values.extend(mod_val)
	return np.asarray(mod_values)

def ppm_mod_bits(symbols, chips_per_symbol, bits_per_chip, mode=None):
	"""
	Inputs:
		symbols: Flattened collection of 0 and 1 where each grouping of
			bits constitutes a symbol.
		chips_per_symbol: Number of chips to use for a single symbol in the
			PPM encoding.
		bits_per_chip: Number of bits associated with a single chip. For 
			values >1, binary 1 is converted to the max possible (unsigned)
			value.
		mode: 'rev' means the LSB of a symbol goes in the 0th index, otherwise 
			the MSB goes in the 0th index. Does not change the order of the 
			symbols amongst one another.
	Outputs:
		Returns a flattened array where the symbols have been modulated 
		using chips_per_symbol-PPM and bits_per_chip.
		
	>>> symbols_flat = [0,1] + [1,0] + [1,1]
	>>> expected_output = [0,0,0,0,1,1,0,0] + [0,0,1,1,0,0,0,0] + [1,1,0,0,0,0,0,0]
	>>> output = ppm_mod_bits(symbols_flat, 4, 2, None)
	>>> list(output) == expected_output
	True
	>>> expected_output_rev = [0,0,0,0,1,1,0,0][::-1] + [0,0,1,1,0,0,0,0][::-1] + [1,1,0,0,0,0,0,0][::-1]
	>>> output_rev = ppm_mod_bits(symbols_flat, 4, 2, 'rev')
	>>> list(output_rev) == expected_output_rev
	True
	"""
	bits_per_symbol = int(np.log2(chips_per_symbol))
	symbols_unflat = [symbols[i*bits_per_symbol : (i+1)*bits_per_symbol] \
		for i in range((len(symbols)+bits_per_symbol-1)//bits_per_symbol)]
	values = [int(''.join(map(str,symbol)), 2) for symbol in symbols_unflat]
	return ppm_mod_vals(values, chips_per_symbol, bits_per_chip, mode=mode)

def ppm_bits_to_chips(symbol_mod_bits, bits_per_chip):
	"""
	Inputs:
		symbol_mod_bits: Flattened collection of bits which constitute an
			integer number PPM'd symbols.
		bits_per_chip: Integer. Number of bits in a given chip.
	Outputs:
		Returns a flattened collection of integers where each 
		value corresponds to a chip.
	Raises:
		ValueError if there are a fractional number of chips in 
		the given symbol.
		
	>>> symbol_mod_bits = [0,0,1,1]
	>>> ppm_bits_to_chips(symbol_mod_bits,2)
	[0, 3]
	"""
	if len(symbol_mod_bits) % bits_per_chip != 0:
		raise ValueError("{0} bits in symbol not divisible by {1}".format(len(symbol_mod_bits), bits_per_chip))
	
	chips_per_symbol = int(len(symbol_mod_bits)/bits_per_chip)
	chips = []
	
	# Flattened modulated symbol -> flattened demodulated chips
	for i in range(chips_per_symbol):
		bits = symbol_mod_bits[i*bits_per_chip:(i+1)*bits_per_chip]
		c = int(''.join(map(str,bits)), 2)
		chips.append(c)
	return chips


def ppm_demod_bits_vals(mod_bits, chips_per_symbol, bits_per_chip, threshold=0):
	"""
	Inputs:
		mod_bits: Collection of bits where the MSB is in the 0th index
			of a given symbol.
		chips_per_symbol: Integer. Number of chips used for a single symbol
			in the PPM encoding.
		bits_per_chip:	Integer. Number of bits associated with a single chip.
		threshold: Integer. Minimum value a maximum must take in order to be 
			considered a non-noise pulse.
	Outputs:
		Returns (1) a collection of symbols (integers, not bits) where the incoming
		chips have been demodulated to find their associated symbol (2) a
		collection of boolean values indicating if the symbol of the same index 
		met the threshold for being considered non-noise.
	Raises:
		ValueError if the number of bits received does not contain an integer
		number of symbols.
		
	>>> chips_per_symbol = 16
	>>> bits_per_chip = 4
	>>> values = np.asarray([i for i in range(chips_per_symbol)])
	>>> print(list(values))
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
	>>> mod_values = ppm_mod_vals(values, chips_per_symbol, bits_per_chip, mode=None)
	>>> values_reclaimed = ppm_demod_bits_vals(mod_values, chips_per_symbol, bits_per_chip)
	>>> list(values_reclaimed) == list(values)
	True
	"""
	bits_per_symbol = chips_per_symbol * bits_per_chip
	demod_values = []
	threshold_met = []
	
	# Check that there's no fragmentation of a received symbol
	if len(mod_bits) % bits_per_symbol != 0:
		raise ValueError("{0} received bits not divisible by {1}".format(mod_bits, \
							bits_per_symbol))
	
	# Split the bits into their symbol groupings
	split_mod_bits = [mod_bits[i:i+bits_per_symbol] for i \
					in range(0,len(mod_bits),bits_per_symbol)]
	
	# Convert each chip from bits to an integer value
	for symbol_bits in split_mod_bits:
		chips = ppm_bits_to_chips(symbol_bits, bits_per_chip)
		demod_val = chips_per_symbol - 1 - np.argmax(chips)
		threshold_met.append(np.max(chips) >= threshold)
		demod_values.append(demod_val)
	return demod_values
