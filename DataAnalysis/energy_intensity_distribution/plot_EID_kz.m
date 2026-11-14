function [result, correctedData] = plot_EID_kz(KZ_DATA, varargin)
%PLOT_EID_KZ Calibrate and optionally plot Fermi drift in a KZ scan.
%   This compatibility entry point replaces the former workspace-specific
%   script.  Options are forwarded to ox_calibrate_fermi_kz_scan; use
%   'Debug',true to request its diagnostic plot.

    result = ox_calibrate_fermi_kz_scan(KZ_DATA,varargin{:});
    if result.isValid
        correctedData = result.data_corrected;
    else
        correctedData = [];
    end
end
