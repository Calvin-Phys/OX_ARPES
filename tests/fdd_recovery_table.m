function fdd_recovery_table()
%FDD_RECOVERY_TABLE  Print fitted vs true parameters for each model (report table).
here = fileparts(mfilename('fullpath')); root = fileparts(here);
addpath(fullfile(root, 'GUI', 'FDD'), here);
truth = struct('EF', 0.0123, 'Temperature', 30, 'Resolution', 0.015, 'Amplitude', 1000, 'Slope', -800, 'Background', 40);
cases = {'fd', struct('Resolution', 0, 'Slope', 0, 'Background', 0); 'fd_bg', struct('Resolution', 0, 'Slope', 0); ...
    'fd_lin_bg', struct('Resolution', 0); 'rcfd', struct('Slope', 0, 'Background', 0); 'rcfd_lin_bg', struct(); 'rcfd_lin_bg_T', struct()};
fprintf('| Model | Data | EF true (meV) | EF fit (meV) | T true (K) | T fit (K) | FWHM true (meV) | FWHM fit (meV) |\n|---|---|---|---|---|---|---|---|\n');
for noisy = [false true]
for c = 1:size(cases, 1)
    t = truth; f = fieldnames(cases{c, 2});
    for k = 1:numel(f), t.(f{k}) = cases{c, 2}.(f{k}); end
    nv = reshape([fieldnames(t)'; struct2cell(t)'], 1, []);
    if noisy, [E, I] = fdd_synthetic(nv{:}, 'Seed', 42); lab = 'noisy (seed 42)'; else, [E, I] = fdd_synthetic(nv{:}, 'Noise', 'none', 'Step', 0.001); lab = 'noiseless'; end
    T0 = []; if strcmp(cases{c, 1}, 'rcfd_lin_bg_T'), T0 = 30; end
    R = fdd_fit_edc(E, I, 'Model', cases{c, 1}, 'Temperature', T0);
    m = fdd_models(cases{c, 1});
    fprintf('| %s (%s) | %s | %.2f | %.3f ± %.3f | %g | %s | %.1f | %s |\n', cases{c, 1}, m.legacy, lab, 1e3 * t.EF, ...
        1e3 * R.params.EF, 1e3 * R.stderr.EF, t.Temperature, pm(R.params.Temperature, R.stderr.Temperature, R.free(4), 1), ...
        1e3 * t.Resolution, pm(1e3 * R.params.Resolution, 1e3 * R.stderr.Resolution, R.free(5), 1e3 * t.Resolution));
end
end
end
function s = pm(v, e, isFree, ~)
if ~isFree, s = sprintf('%.4g (held)', v); else, s = sprintf('%.2f ± %.2f', v, e); end
end
