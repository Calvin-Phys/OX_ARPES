function I = fdd_model(E, p)
%FDD_MODEL  Resolution-broadened Fermi edge with linear DOS and background.
%   I = FDD_MODEL(E, p) evaluates, for energies E (eV, any shape),
%
%       I(E) = [ (A + S*(E-EF)) * f_FD(E; EF, T) ] (*) G(FWHM) + B
%
%   where (*) is convolution with a unit-area Gaussian of full width at half
%   maximum FWHM (eV), f_FD is the Fermi-Dirac function (FDD_FERMI) and
%   p is a struct with fields Amplitude (A), Slope (S, counts/eV), EF (eV),
%   Temperature (T, K), Resolution (FWHM, eV) and Background (B).
%   Resolution = 0 gives the unbroadened edge. The linear density of
%   states is convolved together with the occupation (physically, the
%   instrument broadens the whole spectrum, not only the occupation).
%
%   Numerical method: normalised trapezoidal quadrature over +/-6 sigma with
%   node spacing min(0.01 sigma, kB*T/2) (at most 40 001 nodes), evaluated
%   at every requested energy, so no interpolation is involved.

c = fdd_constants();
validate_params(p);
A = p.Amplitude; S = p.Slope; EF = p.EF; T = p.Temperature;
B = p.Background; sigma = p.Resolution * c.fwhm2sig;

sz = size(E);
E = E(:);
if isempty(E)
    I = zeros(sz);
    return
end

if sigma == 0
    I = (A + S .* (E - EF)) .* fdd_fermi(E, EF, T) + B;
    I = reshape(I, sz);
    return
end

% Quadrature in units of sigma: the nodes u scale with sigma, so the
% result is a smooth function of every parameter (needed for stable
% finite-difference Jacobians in FDD_FIT_EDC).
du = 0.01;
if T > 0
    du = min(du, 0.5 * c.kB * T / sigma);   % resolve kB*T when kB*T << sigma
end
du = max(du, 6 / 20000);                   % cap at 40 001 nodes
nU = 2 * ceil(6 / du) + 1;
u = linspace(-6, 6, nU).';
w = exp(-0.5 * u.^2);
w = w / sum(w);
I = zeros(size(E));
chunk = max(1, floor(4e6 / nU));
for i0 = 1:chunk:numel(E)
    idx = i0:min(i0 + chunk - 1, numel(E));
    Es = E(idx).' - sigma * u;             % nU-by-numel(idx)
    I(idx) = (w.' * ((A + S .* (Es - EF)) .* fdd_fermi(Es, EF, T))).';
end
I = I + B;
I = reshape(I, sz);
end

function validate_params(p)
names = {'Amplitude','Slope','EF','Temperature','Resolution','Background'};
for i = 1:numel(names)
    if ~isfield(p, names{i})
        error('FDD:MissingParameter', 'Parameter "%s" is missing.', names{i});
    end
    v = p.(names{i});
    if ~(isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v))
        error('FDD:InvalidParameter', 'Parameter "%s" must be a finite real scalar.', names{i});
    end
end
if p.Temperature < 0
    error('FDD:InvalidTemperature', 'Temperature must be >= 0 K.');
end
if p.Resolution < 0
    error('FDD:InvalidResolution', 'Resolution (FWHM) must be >= 0 eV.');
end
end
