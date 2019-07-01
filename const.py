# Lydia Lee
# Created 2019/07/01

# Useful constants and equations which describe the 
# physical universe, independent of the transmitting system.

h = 6.6e-34 # J*s
c = 3e8	# m/s

def deg_to_rad(x):
	"""
	Inputs:
		x: Angle in degrees.
	Outputs:
		Returns the angle x (degrees) in radians
	"""
	return np.pi*x/180
	
def calc_E_photon(lamb):
	"""
	Inputs:
		lamb: Float. Wavelength in meters.
	Outputs:
		Energy per photon at a given wavelength.
	"""
	return h*c/lamb
