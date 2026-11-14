%TEST_FS_MAP_SYMMETRY Exercise auto-mask symmetrization on two FS maps.
%   Requires FS_66_LH_map_ksp and FS_94_LH_map_ksp in the MATLAB workspace.

opts = struct();
opts.zero_eps = 2;
opts.feather_px = 20;
opts.pad_px = 50;
opts.min_weight = 0.2;
opts.x_out = -0.1:0.005:1.4;
opts.y_out = -0.1:0.005:0.4;

[FS_66_LH_map_ksp_sym, dbg1] = sym_map_data_autoMask(FS_66_LH_map_ksp, opts);
[FS_94_LH_map_ksp_sym, dbg2] = sym_map_data_autoMask(FS_94_LH_map_ksp, opts);
