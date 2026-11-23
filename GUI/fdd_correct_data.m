function [out, info] = fdd_correct_data(data, params, varargin)
%FDD_CORRECT_DATA  Shift a cut/map to E-EF and optionally divide by the FD edge.
%   out = FDD_CORRECT_DATA(data, params) returns a COPY of DATA with the
%   energy axis shifted by -params.EF (so the fitted Fermi level is 0 eV).
%   out = FDD_CORRECT_DATA(data, params, 'Renormalise', true, ...)
%   additionally subtracts the constant background and divides by the
%   Fermi-Dirac occupation evaluated with the fitted temperature (and
%   resolution, unless 'UseResolution' is false):
%
%       value_new = (value - B) ./ f(E - EF; T, FWHM)
%
%   Options
%     'Renormalise'   false (default) | true
%     'UseResolution' true (default)  | false (unbroadened FD, legacy Mod 1-3)
%     'MinOccupation' Samples whose occupation is below this value
%                     (default 0.05, i.e. above EF + ~3 kB*T) are set to NaN
%                     instead of being amplified noise. Use 0 to keep all
%                     samples except those with zero occupation.
%     'Background'    Override params.Background.
%
%   DATA is not modified. PARAMS needs EF, Temperature, Resolution and
%   Background (as returned in R.params by FDD_FIT_EDC). One EF is applied
%   to every angle; for a curved (angle-dependent) gold edge, fit per angle
%   and correct each EDC separately.
%   INFO returns the occupation threshold and the number of masked samples.

p = inputParser;
p.addParameter('Renormalise', false, @(v) islogical(v) || isnumeric(v));
p.addParameter('UseResolution', true, @(v) islogical(v) || isnumeric(v));
p.addParameter('MinOccupation', 0.05, @(v) isnumeric(v) && isscalar(v) && v >= 0 && v < 0.5);
p.addParameter('Background', [], @(v) isempty(v) || (isnumeric(v) && isscalar(v) && isfinite(v)));
p.parse(varargin{:});
o = p.Results;

[nd, eName] = fdd_energy_axis(data);
need = {'EF','Temperature','Resolution','Background'};
for i = 1:numel(need)
    if ~isfield(params, need{i}) || ~(isnumeric(params.(need{i})) && isscalar(params.(need{i})) && isfinite(params.(need{i})))
        error('FDD:InvalidParameter', 'params.%s must be a finite scalar.', need{i});
    end
end
if params.Temperature <= 0
    error('FDD:InvalidTemperature', 'Temperature must be > 0 K for the correction.');
end

out = data;
Eaxis = data.(eName);
out.(eName) = Eaxis - params.EF;
info = struct('masked', 0, 'minOccupation', o.MinOccupation, 'renormalised', logical(o.Renormalise));
if ~o.Renormalise
    return
end

B = params.Background;
if ~isempty(o.Background), B = o.Background; end
q = params;
q.EF = 0; q.Amplitude = 1; q.Slope = 0; q.Background = 0;
if ~o.UseResolution, q.Resolution = 0; end
Eshift = double(out.(eName)(:));
occ = fdd_model(Eshift, q);

shape = ones(1, nd);
shape(nd) = numel(occ);
occN = reshape(occ, shape);
v = (double(data.value) - B) ./ occN;
mask = repmat(occN < o.MinOccupation | occN <= 0, size(v) ./ shape);   % never divide by 0
v(mask) = NaN;
info.masked = nnz(mask);
out.value = cast_like(v, data.value);
end

function v = cast_like(v, ref)
if isa(ref, 'single')
    v = single(v);
end
end
