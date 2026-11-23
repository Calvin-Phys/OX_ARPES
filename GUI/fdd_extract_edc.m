function [E, I, info] = fdd_extract_edc(data, varargin)
%FDD_EXTRACT_EDC  Average an EDC from a cut or map inside an angle window.
%   [E, I] = FDD_EXTRACT_EDC(data) averages over all angles.
%   [E, I, info] = FDD_EXTRACT_EDC(data, 'XRange', [x1 x2], ...
%                                  'YRange', [y1 y2], 'ERange', [e1 e2])
%
%   DATA is an OX_ARPES object (OxA_CUT/MAP/KZ, ...) or a struct with
%   fields x, y, value (2-D cut, VALUE(x, y), energy along y) or x, y, z,
%   value (3-D, VALUE(x, y, z), energy along z). Ranges are inclusive,
%   in axis units, in either order, and work for ascending or descending
%   axes. Omitted ranges use the whole axis. NaN samples are ignored in the
%   average. E and I are column vectors sorted by increasing energy.
%   INFO reports the number of angle samples and the ranges actually used.

p = inputParser;
p.addParameter('XRange', [], @valid_range);
p.addParameter('YRange', [], @valid_range);
p.addParameter('ERange', [], @valid_range);
p.parse(varargin{:});
o = p.Results;

[nd, eAxis] = fdd_energy_axis(data);
x = double(data.x(:));
xm = in_range(x, o.XRange);
if ~any(xm)
    error('FDD:EmptySelection', 'The x range %s contains no samples.', mat2str(o.XRange));
end
v = double(data.value);
if nd == 2
    E = double(data.y(:));
    em = in_range(E, o.ERange);
    block = v(xm, em);
    I = mean(block, 1, 'omitnan');
    nAngles = nnz(xm);
else
    y = double(data.y(:));
    ym = in_range(y, o.YRange);
    if ~any(ym)
        error('FDD:EmptySelection', 'The y range %s contains no samples.', mat2str(o.YRange));
    end
    E = double(data.z(:));
    em = in_range(E, o.ERange);
    block = v(xm, ym, em);
    I = reshape(mean(reshape(block, [], nnz(em)), 1, 'omitnan'), [], 1);
    nAngles = nnz(xm) * nnz(ym);
end
if ~any(em)
    error('FDD:EmptySelection', 'The energy range %s contains no samples.', mat2str(o.ERange));
end
E = E(em);
I = I(:);
[E, order] = sort(E);
I = I(order);
info = struct('nAngles', nAngles, 'energyAxis', eAxis, ...
    'xRange', [min(x(xm)) max(x(xm))], 'eRange', [min(E) max(E)]);
end

function m = in_range(a, r)
if isempty(r)
    m = true(size(a));
else
    m = a >= min(r) & a <= max(r);
end
end

function tf = valid_range(r)
tf = isempty(r) || (isnumeric(r) && numel(r) == 2 && all(isfinite(r)));
end
