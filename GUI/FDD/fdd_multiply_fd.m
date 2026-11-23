function out = fdd_multiply_fd(data, T, varargin)
%FDD_MULTIPLY_FD  Multiply a cut/map by the Fermi-Dirac occupation.
%   out = FDD_MULTIPLY_FD(data, T) returns a COPY of DATA whose values are
%   multiplied by f(E; EF=0, T). The energy axis must already be E-EF (eV);
%   T is in K and must be > 0.
%   out = FDD_MULTIPLY_FD(data, T, 'Resolution', FWHM, 'EF', EF) uses a
%   Gaussian-broadened occupation and/or a non-zero Fermi level.
%   Works for 2-D cuts (energy along y) and 3-D maps (energy along z).

p = inputParser;
p.addParameter('Resolution', 0, @(v) isnumeric(v) && isscalar(v) && isfinite(v) && v >= 0);
p.addParameter('EF', 0, @(v) isnumeric(v) && isscalar(v) && isfinite(v));
p.parse(varargin{:});
if ~(isnumeric(T) && isscalar(T) && isfinite(T) && T > 0)
    error('FDD:InvalidTemperature', 'Temperature must be a finite value > 0 K.');
end
[nd, eName] = fdd_energy_axis(data);
q = struct('Amplitude', 1, 'Slope', 0, 'EF', p.Results.EF, 'Temperature', T, ...
    'Resolution', p.Results.Resolution, 'Background', 0);
occ = fdd_model(double(data.(eName)(:)), q);
shape = ones(1, nd);
shape(nd) = numel(occ);
out = data;
v = double(data.value) .* reshape(occ, shape);
if isa(data.value, 'single'), v = single(v); end
out.value = v;
end
