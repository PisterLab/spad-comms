# Lydia Lee
# Created 2019/07/01

# Miscellaneous, questionably useful equations which I've never used myself
# but I thought I might at some point.

def Kruse_atten(z, lamb):
	"""
	Inputs:
		z: Distance in meters.
		lamb: Wavelength in meters.
	Outputs:
		Returns the fractional loss due to atmospheric effects
		as per Kruse.
	"""
	if z > 50e3:
		q = 1.6
	elif z > 6e3:
		q = 1.3
	else:
		q = .585*z**(1/3)
		
	return 13/z*(lamb/550e-9)**(-q)

def FSPL_atten(z, lamb):
	"""
	Inputs:
		z: Distance in meters.
		lamb: Wavelength in meters.
	Outputs:
		Returns the fractional loss due to atmospheric effects.
	"""
	return 1/(4*np.pi*z/lamb)**2
