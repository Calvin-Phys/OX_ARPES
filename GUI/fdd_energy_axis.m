function [nd, axisName] = fdd_energy_axis(data)
%FDD_ENERGY_AXIS  Identify the energy axis of a 2-D cut or 3-D map.
%   [nd, axisName] = FDD_ENERGY_AXIS(data) returns 2 and 'y' for a cut
%   (VALUE(x, y)) or 3 and 'z' for a 3-D dataset (VALUE(x, y, z)), the
%   OX_ARPES/yulinARPES convention. The axis lengths are checked against
%   size(VALUE) so that a mismatched struct fails before any calculation.

for f = {'x','y','value'}
    if ~has_field(data, f{1})
        error('FDD:InvalidData', 'Data must have fields/properties x, y and value.');
    end
end
v = data.value;
if ~isnumeric(v) || isempty(v)
    error('FDD:InvalidData', 'data.value must be a non-empty numeric array.');
end
if ndims(v) > 3
    error('FDD:InvalidData', 'Only 2-D cuts and 3-D maps are supported (value has %d dimensions).', ndims(v));
end
if ismatrix(v) && ~(has_field(data, 'z') && numel(data.z) > 1)
    nd = 2; axisName = 'y';
    if numel(data.x) ~= size(v, 1) || numel(data.y) ~= size(v, 2)
        error('FDD:InvalidData', 'A 2-D cut needs numel(x) = size(value,1) and numel(y) = size(value,2).');
    end
elseif ndims(v) == 3 || (has_field(data, 'z') && numel(data.z) > 1)
    nd = 3; axisName = 'z';
    if ~has_field(data, 'z') || numel(data.x) ~= size(v, 1) || numel(data.y) ~= size(v, 2) || numel(data.z) ~= size(v, 3)
        error('FDD:InvalidData', 'A 3-D dataset needs x, y, z matching size(value).');
    end
else
    error('FDD:InvalidData', 'Only 2-D cuts and 3-D maps are supported.');
end
end

function tf = has_field(s, name)
if isstruct(s)
    tf = isfield(s, name);
else
    tf = isprop(s, name);
end
end
