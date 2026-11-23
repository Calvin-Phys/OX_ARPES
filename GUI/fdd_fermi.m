function f = fdd_fermi(E, EF, T)
%FDD_FERMI  Fermi-Dirac occupation f(E) = 1/(exp((E-EF)/(kB*T)) + 1).
%   f = FDD_FERMI(E, EF, T) evaluates the occupation for energies E (eV),
%   Fermi level EF (eV) and temperature T (K). The tanh form is numerically
%   stable for |E-EF| >> kB*T (no overflow). T = 0 returns the step
%   function with f(EF) = 0.5.
%
%   Convention: E - EF is negative below the Fermi level (occupied states).

kB = fdd_constants().kB;
if T < 0 || ~isfinite(T)
    error('FDD:InvalidTemperature', 'Temperature must be finite and >= 0 K.');
end
if T == 0
    f = double(E < EF) + 0.5 * double(E == EF);
else
    f = 0.5 * (1 - tanh((E - EF) ./ (2 * kB * T)));
end
end
