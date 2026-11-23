function T = fdd_info_temperature(data)
%FDD_INFO_TEMPERATURE  Sample temperature (K) from data.info.temperature.
%   T = FDD_INFO_TEMPERATURE(data) returns the finite, positive value of
%   data.info.temperature for an OX_ARPES object (info property) or a struct
%   (info field), or [] when it is missing, empty, non-numeric or not
%   positive. A logged vector (several readings) gives the mean of its
%   finite values. The data are not changed.
T = [];
if isstruct(data)
    if ~isscalar(data) || ~isfield(data, 'info'), return; end
elseif ~isobject(data) || ~isprop(data, 'info')
    return
end
info = data.info;
if ~(isstruct(info) && isscalar(info) && isfield(info, 'temperature')), return; end
v = info.temperature;
if ~(isnumeric(v) && isreal(v)) || isempty(v), return; end
v = double(v(:));
v = v(isfinite(v));
if isempty(v), return; end
v = mean(v);
if v > 0, T = v; end
end
