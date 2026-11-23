function tests = TestFDDCore
%TESTFDDCORE  Numerical tests for the upgraded FDD backend (base MATLAB).
tests = functiontests(localfunctions);
end

function setupOnce(tc)
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
tc.TestData.oldPath = addpath(fullfile(root, 'GUI'), fullfile(root, 'DataType'), here);
end

function teardownOnce(tc)
path(tc.TestData.oldPath);
end

function testFermiAnalyticInvariants(tc)
E = linspace(-0.05, 0.05, 101);
f = fdd_fermi(E, 0.01, 20);
tc.verifyEqual(fdd_fermi(0.01, 0.01, 20), 0.5, 'AbsTol', 1e-15);
tc.verifyEqual(f + fliplr(fdd_fermi(fliplr(0.02 - E), 0.01, 20)), ones(size(E)), 'AbsTol', 1e-12); % f(EF+d)+f(EF-d)=1
tc.verifyEqual(fdd_fermi(1, 0, 1), 0, 'AbsTol', 1e-300);        % no overflow at E-EF >> kT
tc.verifyEqual(fdd_fermi(-1, 0, 1), 1, 'AbsTol', 1e-15);
tc.verifyEqual(fdd_fermi([-1 0 1], 0, 0), [1 0.5 0]);
kB = 8.617333262e-5;   % 10-90 % width of the bare Fermi function = 2 ln 9 kB T
tc.verifyEqual(2 * log(9) * kB, 4.3944 * kB, 'RelTol', 1e-4);
end

function testModelMatchesIndependentIntegral(tc)
[E, Iref, p] = fdd_synthetic('Noise', 'none', 'Temperature', 12, 'Resolution', 0.009, 'Step', 0.001);
Imod = fdd_model(E, p);
tc.verifyLessThan(max(abs(Imod - Iref)) / p.Amplitude, 2e-4);
q = p; q.Resolution = 0;
[~, Iref0] = fdd_synthetic('Noise', 'none', 'Temperature', 12, 'Resolution', 0, 'Step', 0.001);
tc.verifyEqual(fdd_model(E, q), Iref0, 'RelTol', 1e-12);
end

function testModelUnitAreaKernel(tc)
% A constant spectrum is unchanged by a unit-area resolution kernel.
p = struct('Amplitude', 5, 'Slope', 0, 'EF', 10, 'Temperature', 10, 'Resolution', 0.05, 'Background', 0);
tc.verifyEqual(fdd_model((-0.3:0.01:-0.1)', p), 5 * ones(21, 1), 'RelTol', 1e-6);
end

function testNoiselessRecoveryEveryModel(tc)
truth = struct('EF', 0.0123, 'Temperature', 30, 'Resolution', 0.015, ...
    'Amplitude', 1000, 'Slope', -800, 'Background', 40);
cases = {
    'fd',            struct('Resolution', 0, 'Slope', 0, 'Background', 0)
    'fd_bg',         struct('Resolution', 0, 'Slope', 0)
    'fd_lin_bg',     struct('Resolution', 0)
    'rcfd',          struct('Slope', 0, 'Background', 0)
    'rcfd_lin_bg',   struct()
    'rcfd_lin_bg_T', struct()
    };
for c = 1:size(cases, 1)
    t = truth;
    f = fieldnames(cases{c, 2});
    for k = 1:numel(f), t.(f{k}) = cases{c, 2}.(f{k}); end
    args = struct2nv(t);
    [E, I] = fdd_synthetic(args{:}, 'Noise', 'none', 'Step', 0.001);
    T0 = [];
    if strcmp(cases{c, 1}, 'rcfd_lin_bg_T'), T0 = t.Temperature; end
    R = fdd_fit_edc(E, I, 'Model', cases{c, 1}, 'Temperature', T0);
    tc.verifyTrue(R.converged, cases{c, 1});
    tc.verifyEqual(R.params.EF, t.EF, 'AbsTol', 2e-5, cases{c, 1});
    tc.verifyEqual(R.params.Temperature, t.Temperature, 'RelTol', 0.02, cases{c, 1});
    tc.verifyEqual(R.params.Resolution, t.Resolution, 'AbsTol', 3e-4, cases{c, 1});
    tc.verifyEqual(R.params.Amplitude, t.Amplitude, 'RelTol', 0.01, cases{c, 1});
end
end

function testNoisyMonteCarloFixedT(tc)
nRun = 40;
ef = zeros(nRun, 1); res = ef; sEF = ef;
for s = 1:nRun
    [E, I, p] = fdd_synthetic('Seed', s);
    R = fdd_fit_edc(E, I, 'Model', 'Mod 6', 'Temperature', 30);
    ef(s) = R.params.EF; res(s) = R.params.Resolution; sEF(s) = R.stderr.EF;
end
tc.verifyLessThan(abs(mean(ef) - p.EF), 3e-4);                 % bias < 0.3 meV
tc.verifyLessThan(abs(mean(res) - p.Resolution) / p.Resolution, 0.05);
ratio = std(ef) / mean(sEF);                                    % reported vs actual scatter
tc.verifyGreaterThan(ratio, 0.6); tc.verifyLessThan(ratio, 1.6);
end

function testKineticEnergyAxisAndNoZeroAssumption(tc)
[E, I, p] = fdd_synthetic('EF', 16.8317, 'Seed', 3);
R = fdd_fit_edc(E, I, 'Temperature', 30);
tc.verifyEqual(R.params.EF, p.EF, 'AbsTol', 1e-3);
tc.verifyEmpty(R.warnings);
end

function testDescendingNaNAndZeroCounts(tc)
[E, I, p] = fdd_synthetic('Background', 0, 'Seed', 4);
I(I < 0) = 0;             % zero counts above EF break a log-space fit
I(5) = NaN;
R = fdd_fit_edc(flipud(E), flipud(I), 'Model', 'rcfd_lin_bg_T', 'Temperature', 30);
tc.verifyEqual(R.params.EF, p.EF, 'AbsTol', 1e-3);
tc.verifyEqual(numel(R.E), numel(E) - 1);
tc.verifyTrue(issorted(R.E));
end

function testTemperatureResolutionDegeneracyFlagged(tc)
% With realistic counting noise a single edge does not separate T from the
% Gaussian resolution. Every free-T fit must warn, EF must stay accurate,
% and the fitted RSS must not exceed the RSS of the true parameters (so the
% scatter is a property of the data, not an optimiser failure).
nRun = 6; T = zeros(nRun, 1);
for s = 1:nRun
    [E, I, p] = fdd_synthetic('Seed', s);
    R = fdd_fit_edc(E, I, 'Model', 'Mod 5');
    T(s) = R.params.Temperature;
    tc.verifyTrue(any(contains(R.warnings, 'strongly correlated')), sprintf('seed %d', s));
    tc.verifyEqual(R.params.EF, p.EF, 'AbsTol', 1e-3);
    tc.verifyLessThanOrEqual(R.rss, sum((fdd_model(E, p) - I).^2));
end
tc.verifyGreaterThan(std(T), 10);         % 30 K truth, scatter > 10 K
end

function testWindowAndFixedOverrides(tc)
[E, I, p] = fdd_synthetic('Seed', 9);
R = fdd_fit_edc(E, I, 'Model', 'rcfd_lin_bg', 'Window', [p.EF + 0.05, p.EF - 0.1], ...
    'Fixed', struct('Temperature', 30));
tc.verifyFalse(R.free(4));
tc.verifyEqual(R.params.Temperature, 30);
tc.verifyGreaterThanOrEqual(min(R.E), p.EF - 0.1 - 1e-12);
tc.verifyLessThanOrEqual(max(R.E), p.EF + 0.05 + 1e-12);
tc.verifyTrue(isnan(R.stderr.Temperature));
end

function testInvalidInputsFailClearly(tc)
[E, I] = fdd_synthetic('Seed', 2);
tc.verifyError(@() fdd_fit_edc(E, I, 'Model', 'Mod 6'), 'FDD:TemperatureRequired');
tc.verifyError(@() fdd_fit_edc(E, I, 'Model', 'Mod 9'), 'FDD:UnknownModel');
tc.verifyError(@() fdd_fit_edc(E, I, 'Bogus', 1), 'MATLAB:InputParser:UnmatchedParameter');
tc.verifyError(@() fdd_fit_edc(E, I, 'Window', [5 6]), 'FDD:TooFewPoints');
tc.verifyError(@() fdd_fit_edc(E(1:5), I), 'FDD:SizeMismatch');
tc.verifyError(@() fdd_fit_edc(E, ones(size(E))), 'FDD:FlatEDC');
tc.verifyError(@() fdd_fit_edc(E, I, 'Temperature', -3), 'MATLAB:InputParser:ArgumentFailedValidation');
tc.verifyError(@() fdd_fit_edc(E, I, 'Initial', struct('Temp', 3)), 'FDD:UnknownParameter');
p = struct('Amplitude', 1, 'Slope', 0, 'EF', 0, 'Temperature', 10, 'Resolution', -0.01, 'Background', 0);
tc.verifyError(@() fdd_model(E, p), 'FDD:InvalidResolution');
end

function testCorrectionOfCutAndMapCopies(tc)
x = -10:0.5:10; E = (16.8 + (-0.2:0.002:0.06));
truth = struct('Amplitude', 100, 'Slope', 0, 'EF', 16.8, 'Temperature', 15, 'Resolution', 0.012, 'Background', 3);
edc = fdd_model(E, truth);
cut = struct('x', x, 'y', E, 'value', repmat(edc, numel(x), 1));
original = cut;
[out, info] = fdd_correct_data(cut, truth, 'Renormalise', true);
tc.verifyEqual(cut, original);                                   % source not modified
tc.verifyEqual(out.y, E - 16.8, 'AbsTol', 1e-12);
occ = fdd_model((E - 16.8)', setfield(setfield(setfield(truth, 'EF', 0), 'Amplitude', 1), 'Background', 0)); %#ok<SFLD>
ok = occ >= 0.05;
tc.verifyEqual(out.value(:, ok), 100 * ones(numel(x), nnz(ok)), 'RelTol', 1e-9);
tc.verifyTrue(all(isnan(out.value(:, ~ok)), 'all'));
tc.verifyEqual(info.masked, numel(x) * nnz(~ok));

map = struct('x', x, 'y', -5:5, 'z', E, 'value', repmat(reshape(edc, 1, 1, []), numel(x), 11, 1));
outMap = fdd_correct_data(map, truth, 'Renormalise', true, 'MinOccupation', 0);
tc.verifyEqual(size(outMap.value), size(map.value));
tc.verifyEqual(squeeze(outMap.value(3, 4, 1:50)), 100 * ones(50, 1), 'RelTol', 1e-9);
outOff = fdd_correct_data(map, truth);
tc.verifyEqual(outOff.value, map.value);
tc.verifyEqual(outOff.z, E - 16.8, 'AbsTol', 1e-12);
end

function testCorrectionOnOxArpesObjects(tc)
tc.assumeTrue(exist('OxA_CUT', 'class') == 8 && exist('OxA_MAP', 'class') == 8, 'OX_ARPES not on path');
x = -10:0.5:10; E = -0.2:0.002:0.06;
truth = struct('Amplitude', 100, 'Slope', 0, 'EF', 0.004, 'Temperature', 15, 'Resolution', 0.012, 'Background', 3);
edc = fdd_model(E, truth);
cut = OxA_CUT(x, E, repmat(edc, numel(x), 1));
out = fdd_correct_data(cut, truth, 'Renormalise', true);
tc.verifyClass(out, 'OxA_CUT');
tc.verifyEqual(out.y, E - 0.004, 'AbsTol', 1e-12);
m = OxA_MAP(); m.x = x; m.y = -5:5; m.z = E; m.value = repmat(reshape(edc, 1, 1, []), numel(x), 11, 1);
outM = fdd_correct_data(m, truth, 'Renormalise', true);
tc.verifyClass(outM, 'OxA_MAP');
tc.verifyEqual(outM.value(1, 1, 10), 100, 'RelTol', 1e-9);
end

function testMultiplyIsInverseOfRenormalise(tc)
x = 1:4; E = -0.1:0.002:0.02;
cut = struct('x', x, 'y', E, 'value', 7 * ones(numel(x), numel(E)));
m = fdd_multiply_fd(cut, 25, 'Resolution', 0.01);
params = struct('EF', 0, 'Temperature', 25, 'Resolution', 0.01, 'Background', 0, 'Amplitude', 1, 'Slope', 0);
back = fdd_correct_data(m, params, 'Renormalise', true, 'MinOccupation', 0);
tc.verifyEqual(back.value, cut.value, 'RelTol', 1e-9);
tc.verifyError(@() fdd_multiply_fd(cut, 0), 'FDD:InvalidTemperature');
end

function testExtractEdcWindows(tc)
x = linspace(-5, 5, 11); E = linspace(-0.1, 0.05, 76);
v = (1:11)' * ones(1, 76);
cut = struct('x', fliplr(x), 'y', fliplr(E), 'value', rot90(v, 2));
[Ee, I, info] = fdd_extract_edc(cut, 'XRange', [2 -2], 'ERange', [0 -0.05]);
tc.verifyTrue(issorted(Ee));
tc.verifyEqual(I, 6 * ones(size(I)), 'AbsTol', 1e-12);        % mean of rows 4..8
tc.verifyEqual(info.nAngles, 5);
tc.verifyError(@() fdd_extract_edc(cut, 'XRange', [20 30]), 'FDD:EmptySelection');
tc.verifyError(@() fdd_extract_edc(struct('x', 1:3, 'y', 1:4, 'value', ones(4, 3))), 'FDD:InvalidData');
end

function testLegacyModelAliases(tc)
for k = 1:6
    tc.verifyEqual(fdd_models(sprintf('Mod %d', k)).key, fdd_models(k).key);
end
tc.verifyEqual(fdd_models('Mod 6').free, logical([1 1 1 0 1 1]));
end

function c = struct2nv(s)
f = fieldnames(s);
c = reshape([f'; struct2cell(s)'], 1, []);
end

function testSecondReviewRegressions(tc)
% Added in the second review before the first commit (see improvement log).
[E, I] = fdd_synthetic('Noise', 'none', 'Step', 0.002);
% Misspelled Fixed/Free names fail instead of being silently ignored.
tc.verifyError(@() fdd_fit_edc(E, I, 'Temperature', 30, 'Fixed', struct('Resolutoin', 0.01)), 'FDD:UnknownParameter');
tc.verifyError(@() fdd_fit_edc(E, I, 'Temperature', 30, 'Free', struct('Slop', false)), 'FDD:UnknownParameter');
% Held values are used exactly, not clamped to the free-parameter bounds.
R = fdd_fit_edc(E, I, 'Model', 'rcfd_lin_bg_T', 'Temperature', 0.05);
tc.verifyEqual(R.params.Temperature, 0.05);
R = fdd_fit_edc(E, I, 'Model', 'rcfd_lin_bg_T', 'Temperature', 30, 'Fixed', struct('Resolution', 0.015));
tc.verifyEqual(R.params.Resolution, 0.015);
tc.verifyEqual(R.params.EF, 0.0123, 'AbsTol', 1e-6);
% Repeated energies (merged sweeps) give finite start values.
p0 = fdd_initial_guess([E; E], [I; I], 30);
tc.verifyTrue(all(isfinite(cell2mat(struct2cell(p0)))));
tc.verifyEqual(p0.EF, 0.0123, 'AbsTol', 0.004);
% 4-D arrays are rejected rather than read as maps.
d4 = struct('x', 1:2, 'y', 1:3, 'z', 1:4, 'value', ones(2, 3, 4, 4));
tc.verifyError(@() fdd_extract_edc(d4), 'FDD:InvalidData');
% MinOccupation = 0 never yields Inf (zero occupation far above EF).
cut = struct('x', 1:3, 'y', linspace(-0.05, 2, 50), 'value', ones(3, 50));
q = struct('EF', 0, 'Temperature', 1, 'Resolution', 0, 'Background', 0);
[out, info] = fdd_correct_data(cut, q, 'Renormalise', true, 'MinOccupation', 0);
tc.verifyFalse(any(isinf(out.value(:))));
tc.verifyGreaterThan(info.masked, 0);
end
