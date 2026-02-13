function result = ox_calibrate_fermi_kz_scan(KZ_DATA, varargin)
%OX_CALIBRATE_FERMI_KZ_SCAN
%   Calibrate Fermi level drift in photon-energy (kz) scan.
%
%   result = ox_calibrate_fermi_kz_scan(KZ_DATA, 'Name', value, ...)
%
% Required:
%   KZ_DATA   OxA_KZ object with value(hv, ky, E)
%
% Optional:
%   'Temperature'     (K)
%   'Resolution'      (eV FWHM)
%   'QuantileIndex'   vector of quantile indices (default [1 2 3])
%   'SmoothSpan'      smoothing span for EF(hv) (default 5)
%   'Debug'           true/false
%
% Output struct:
%   .EF_raw
%   .EF_smooth
%   .valid_mask
%   .data_corrected
%   .isValid

% -------------------------
% Input parsing
% -------------------------

p = inputParser;
addParameter(p,'Temperature',[]);
addParameter(p,'Resolution',[]);
addParameter(p,'QuantileIndex',[1 2 3]);   % 0.05,0.15,0.25
addParameter(p,'SmoothSpan',5);
addParameter(p,'Debug',true);
parse(p,varargin{:});
opt = p.Results;

result = struct( ...
    'EF_raw', [], ...
    'EF_smooth', [], ...
    'valid_mask', [], ...
    'data_corrected', [], ...
    'isValid', false);

% -------------------------
% Basic checks
% -------------------------

if ~isa(KZ_DATA,'OxA_KZ')
    return
end

Nhv = length(KZ_DATA.x);
E = KZ_DATA.z(:);

% -------------------------
% Compute EID per hv
% -------------------------

DP = ox_energy_intensity_distribution_per_hv(KZ_DATA);

eid_bkgd = DP.info.eid_bkgd;   % (hv, E, q)

if isempty(eid_bkgd)
    return
end

Nq = size(eid_bkgd,3);

% Validate quantile indices
q_idx = opt.QuantileIndex;
q_idx = q_idx(q_idx >= 1 & q_idx <= Nq);

if isempty(q_idx)
    return
end

% -------------------------
% Fit EF per hv
% -------------------------

EF_raw = nan(1,Nhv);
valid_mask = false(1,Nhv);

for ihv = 1:Nhv

    EF_candidates = [];

    for iq = q_idx

        EDC_bg = squeeze(eid_bkgd(ihv,:,iq));

        r = fit_fermi_edge_ox(E, EDC_bg, ...
            'Temperature', opt.Temperature, ...
            'Resolution', opt.Resolution, ...
            'FixTemperature', ~isempty(opt.Temperature), ...
            'FixResolution', false,...
            'Debug', false);

        if r.isValid
            EF_candidates(end+1) = r.EF; %#ok<AGROW>
        end

    end

    if ~isempty(EF_candidates)
        EF_raw(ihv) = median(EF_candidates);
        valid_mask(ihv) = true;
    end

end

% -------------------------
% Post-processing
% -------------------------

if ~any(valid_mask)
    return
end

% Fill missing by interpolation
EF_interp = EF_raw;
EF_interp(~valid_mask) = NaN;
EF_interp = fillmissing(EF_interp,'linear','EndValues','nearest');

% Smooth
span = opt.SmoothSpan;
EF_smooth = smoothdata(EF_interp,'movmedian',span);

% -------------------------
% Build corrected data
% -------------------------

value_corrected = KZ_DATA.value;
E_original = KZ_DATA.z;

for ihv = 1:Nhv

    shift = EF_smooth(ihv);

    % Energy shift: adjust axis metadata only
    % (do NOT resample intensity here)

    % If you prefer rigid shift in energy axis:
    % nothing to change in value, only axis

end

KZ_corrected = KZ_DATA;
KZ_corrected.z = E_original - EF_smooth(:)';  
% If z must remain 1D, do not overwrite per hv.
% Alternative approach below.

% -------------------------
% Output
% -------------------------

result.EF_raw = EF_raw;
result.EF_smooth = EF_smooth;
result.valid_mask = valid_mask;
result.data_corrected = KZ_corrected;
result.isValid = true;

% -------------------------
% Debug
% -------------------------

if opt.Debug

    figure('Name','EF(hv) calibration','NumberTitle','off');
    plot(KZ_DATA.x, EF_raw,'o-'); hold on
    plot(KZ_DATA.x, EF_smooth,'r-','LineWidth',1.5);
    xlabel('Photon energy (eV)');
    ylabel('EF shift (eV)');
    legend('Raw','Smoothed');
    grid on;

end

end
