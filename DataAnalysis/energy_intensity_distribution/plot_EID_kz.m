KZ_DATA = XXX;

Texp = 26.5;          % Kelvin
res_guess = 0.03;   % eV initial guess

result = ox_calibrate_fermi_kz_scan(KZ_DATA, ...
    'Temperature', Texp, ...
    'Resolution', res_guess, ...
    'QuantileIndex', [1 2 3], ...
    'SmoothSpan', 1, ...
    'Debug', true);

EF_curve = result.EF_smooth;

%%

XXX_fixFL = ox_apply_fermi_shift_extended(KZ_DATA,EF_curve);