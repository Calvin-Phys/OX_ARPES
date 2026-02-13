KZ_DATA = A015_Ni3In2S2_1_tk_s_nor;

Texp = 100;          % Kelvin
res_guess = 0.02;   % eV initial guess

result = ox_calibrate_fermi_kz_scan(KZ_DATA, ...
    'Temperature', Texp, ...
    'Resolution', res_guess, ...
    'QuantileIndex', [1 2 3], ...
    'SmoothSpan', 7, ...
    'Debug', true);

EF_curve = result.EF_smooth;

%%

A015_Ni3In2S2_1_tk_s_nor_fixFL = ox_apply_fermi_shift_extended(KZ_DATA,EF_curve);