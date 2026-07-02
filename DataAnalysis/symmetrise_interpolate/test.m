opts = struct();
opts.zero_eps   = 2;     % if your padding is exactly 0
opts.feather_px = 20;    % tune 10–40 typically
opts.pad_px = 50;
opts.min_weight = 0.2;   % require ~at least one good contribution
opts.x_out = -1.2:0.01:1.2;
opts.y_out = -1.2:0.01:1.2;

[i05_138940_tk_ksp_sym, dbg1] = sym_map_data_autoMask(i05_138940_tk_ksp, opts);