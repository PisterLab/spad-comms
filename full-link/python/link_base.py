# Lydia Lee
# Created 2019/07/01

# Contains equations for high-level link budgeting.

def calc_rx_power(P_TX, eta_TX, eta_RX,
	A_TX, A_RX, z, lamb, L_point, L_pol, L_atm):
	"""
	Inputs:
		P_TX: Float. Transmitted power in watts.
		eta_TX: Float between 0 and 1, inclusive. Efficiency of the transmit
			optics, etc.
		eta_RX: Float between 0 and 1, inclusive. Efficiency of the receive
			optics, etc.
		A_TX: Float. Aperture area on the TX side in square meters.
		A_RX: Float. Aperture are on the RX side in square meters.
		z: Float. Distance in meters between RX and TX.
		lamb: Float. Wavelength in meters of the light in question.
		L_point: Float between 0 and 1, inclsuive. Fractional pointing loss.
		L_pol: Float between 0 and 1, inclusive. Fractional loss due to 
			polarization.
		L_atm: Float between 0 and 1, inclsuive. Fractional loss due to 
			atmospheric effects.
	Outputs:
		Returns the output power which reaches the receiver in watts.
	"""
	return min(P_TX, P_TX * (1-L_point) * (1-L_atm) * (1-L_pol) \
		* eta_TX * eta_RX * (A_TX*A_RX)/(z*lamb)**2)
		
def calc_channel_capacity(P_RX, lamb, M, SNR):
	"""
	Inputs:
		P_RX: Float. Power which reaches the receiver in watts.
		lamb: Float. Wavelength in meters of the light in question.
		M: Float. Peak-to-average power ratio of the signal.
		SNR: Float. Signal-to-noise ratio of the received power.
	Outputs:
		Returns the theoretical channel capacity in photons/bit.
	"""
	
	return np.log2(np.exp(1)) * photons_per_sec/M * \
		((1+1/SNR)*np.log(1+SNR) - (1+M/SNR)*np.log(1+SNR/M))
