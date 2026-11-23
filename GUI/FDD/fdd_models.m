function m = fdd_models(name)
%FDD_MODELS  Fit-model presets for FDD_FIT_EDC and the FDD GUI.
%   m = FDD_MODELS() returns the preset table (struct array).
%   m = FDD_MODELS(name) returns one preset. NAME may be the preset key,
%   its legacy "Mod N" label from FDD_new.mlapp, or the numeric index N.
%
%   Each preset lists which of the six parameters are FREE in the fit:
%   Amplitude, Slope, EF, Temperature, Resolution, Background. Parameters
%   that are not free are held at their initial (or user-fixed) values; a
%   held Slope/Background/Resolution defaults to 0.
%
%   Key            Legacy  Free parameters
%   fd             Mod 1   A, EF, T
%   fd_bg          Mod 2   A, EF, T, B
%   fd_lin_bg      Mod 3   A, S, EF, T, B
%   rcfd           Mod 4   A, EF, T, FWHM
%   rcfd_lin_bg    Mod 5   A, S, EF, T, FWHM, B   (T and FWHM correlate)
%   rcfd_lin_bg_T  Mod 6   A, S, EF, FWHM, B      (T fixed: recommended)

P = {'Amplitude','Slope','EF','Temperature','Resolution','Background'};
defs = {
 'fd',            'Mod 1', 'FD',                                               [1 0 1 1 0 0]
 'fd_bg',         'Mod 2', 'FD + background',                                  [1 0 1 1 0 1]
 'fd_lin_bg',     'Mod 3', 'FD + linear DOS + background',                     [1 1 1 1 0 1]
 'rcfd',          'Mod 4', 'Broadened FD',                                     [1 0 1 1 1 0]
 'rcfd_lin_bg',   'Mod 5', 'Broadened FD + lin. DOS + bg, T free',             [1 1 1 1 1 1]
 'rcfd_lin_bg_T', 'Mod 6', 'Broadened FD + lin. DOS + bg, T held',             [1 1 1 0 1 1]
};
presets = struct('key', defs(:,1), 'legacy', defs(:,2), 'label', defs(:,3), ...
    'free', cellfun(@logical, defs(:,4), 'UniformOutput', false));
for i = 1:numel(presets)
    presets(i).params = P;
end
if nargin == 0
    m = presets;
    return
end
if isnumeric(name) && isscalar(name) && name >= 1 && name <= numel(presets) && name == round(name)
    m = presets(name);
    return
end
if ~(ischar(name) || isstring(name))
    error('FDD:UnknownModel', 'Model must be a preset key, legacy label or index 1-6.');
end
name = char(name);
idx = find(strcmpi(name, {presets.key}) | strcmpi(name, {presets.legacy}) | strcmpi(name, {presets.label}), 1);
if isempty(idx)
    error('FDD:UnknownModel', 'Unknown model "%s". Valid keys: %s.', name, strjoin({presets.key}, ', '));
end
m = presets(idx);
end
