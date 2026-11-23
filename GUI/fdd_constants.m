function c = fdd_constants()
%FDD_CONSTANTS  Physical constants and conversion factors used by FDD tools.
%   kB       Boltzmann constant in eV/K (CODATA 2018, exact).
%   fwhm2sig Gaussian FWHM-to-sigma factor, sigma = FWHM / (2*sqrt(2*ln 2)).
c.kB = 8.617333262e-5;
c.fwhm2sig = 1 / (2 * sqrt(2 * log(2)));
end
