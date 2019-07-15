# Lydia Lee
# Created 2019/07/01

# Contains equations for calculating losses due to pointing error
# with a Gaussian beam.

import numpy as np

def intensity_position(r=1, mu=0, sigma=1):
    """
    Inputs:
        r: Distance from the center of the distribution.
        mu: Mean of the distribution.
        sigma: Standard deviation of the distribution.
    Outputs:
        Value of the Gaussian given the mean and standard deviation
        at a distance r away from the mean.
    """
    return 1/np.sqrt(2*np.pi*sigma**2) * np.exp(-(r-mu)**2/(2*sigma**2))

def intensity_theta(theta, z_0, mu, M=None, lamb=None, n=None, w_0=None, theta_e2=None):
    """
    Inputs:
        theta: Angle from the central axis in radians.
        z_0: Distance between the measurement points (hypotenuse)
        mu: Mean of the distribution at a distance z_0 away
            from the TX, perpendicular (on the central axis).
        M: Beam quality factor.
        lamb: Wavelength in meters.
        n: Index of refraction.
        w_0: Beam waist radius in meters.
    Outputs:
        Value of the Gaussian given the mean and standard deviation
        at an angle theta away from the center when the distance
        between the TX and RX is z_0.
    """
    z = z_0*np.cos(theta)
    r = z_0*np.sin(theta)
    
    # Given the functionally shortened distance, calculate
    # the new Gaussian distribution's standard deviation.
    sigma = calc_sigma(z, M, lamb, n, w_0, theta_e2)
    return intensity_position(r, mu, sigma)

def calc_sigma(z, M=None, lamb=None, n=None, w_0=None, theta_e2=None):
    """
    Inputs:
        z: Distance from the TX point to the perpendicular RX plane
            in the direction of the center of the beam.
        M: Beam quality factor.
        lamb: Wavelength in meters.
        n: Index of refraction.
        w_0: Beam waist radius in meters.
        theta_e2: Half-angle of the beam divergence in radians.
    Outputs:
        Standard deviation of the Gaussian of intensity at a given 
        distance.
    """
    if theta_e2 == None:
        theta_e2 = calc_theta_e2(M, lamb, n, w_0)
    w_e2 = z*np.tan(theta_e2)
    return w_e2/2

def calc_theta_e2(M, lamb, n, w_0):
    """
    Inputs:
        M: Beam quality factor.
        lamb: Wavelength in meters.
        n: Index of refraction.
        w_0: Beam waist radius in meters.
    Outputs:
        Gives the half angle for the 1/e^2 point in beam divergence.
    """
    return M**2 * lamb/(np.pi*n*w_0)
