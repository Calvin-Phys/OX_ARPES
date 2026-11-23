function R = fdd_fit_edc(E, I, varargin)
%FDD_FIT_EDC  Fit a Fermi edge to an EDC using base MATLAB only.
%   R = FDD_FIT_EDC(E, I) fits the full broadened model (T free). Because a
%   single edge cannot separate T from resolution well, pass Temperature.
%   R = FDD_FIT_EDC(E, I, Name, Value, ...) options:
%
%     'Model'       Preset key, legacy 'Mod N' label or index (FDD_MODELS).
%                   Default 'rcfd_lin_bg_T' when 'Temperature' is given,
%                   otherwise 'rcfd_lin_bg'.
%     'Window'      [Emin Emax] fit range in the units of E (eV). Default:
%                   all finite points.
%     'Temperature' Sample temperature in K. Used as the held value when T
%                   is not free and as the starting value otherwise.
%     'Initial'     Struct of starting values (any subset of Amplitude,
%                   Slope, EF, Temperature, Resolution, Background). Omitted
%                   fields come from FDD_INITIAL_GUESS.
%     'Fixed'       Struct of values to hold fixed, overriding the preset
%                   (e.g. struct('Resolution',0.012)).
%     'Free'        Struct of logicals to free/hold parameters explicitly,
%                   overriding the preset (e.g. struct('Slope',false)).
%     'Weights'     'none' (default, unweighted least squares) or 'poisson'
%                   (1/sqrt(max(I,1)); use only for raw counts).
%     'MaxIter'     Levenberg-Marquardt iteration limit (default 300).
%
%   R contains: params/stderr (structs), free (logical 1x6), names, model,
%   window, E, I, fit, residual, rss, dof, chi2red, rsquared, correlation
%   (6x6, NaN for held parameters), iterations, converged and warnings.
%
%   Units: energies and EF in eV, Temperature in K, Resolution = Gaussian
%   FWHM in eV, Slope in intensity per eV. Uncertainties are 1-sigma
%   estimates from the Jacobian scaled by the reduced chi-square; they do
%   not include systematic errors (e.g. sample/analyser work function drift).
%
%   No toolbox is required (no fit/fittype/lsqcurvefit).

opts = parse_options(varargin{:});
[E, I] = clean_edc(E, I);
if ~isempty(opts.Window)
    w = sort(opts.Window);
    keep = E >= w(1) & E <= w(2);
    E = E(keep); I = I(keep);
end
if numel(E) < 6
    error('FDD:TooFewPoints', 'The fit window contains %d finite points; at least 6 are needed.', numel(E));
end
if max(I) == min(I)
    error('FDD:FlatEDC', 'The EDC is constant in the fit window; there is no edge to fit.');
end

names = {'Amplitude','Slope','EF','Temperature','Resolution','Background'};
model = fdd_models(opts.Model);
free = model.free;

p0 = fdd_initial_guess(E, I, opts.Temperature);
if ~free(2), p0.Slope = 0; end
if ~free(5), p0.Resolution = 0; end
if ~free(6), p0.Background = 0; end
if ~isempty(opts.Temperature), p0.Temperature = opts.Temperature; end
p0 = merge(p0, opts.Initial, names);
check_names(opts.Fixed, names, 'Fixed');
check_names(opts.Free, names, 'Free');
fx = fieldnames(opts.Fixed);
for i = 1:numel(fx)
    p0.(fx{i}) = opts.Fixed.(fx{i});
    free(strcmp(names, fx{i})) = false;
end
fr = fieldnames(opts.Free);
for i = 1:numel(fr)
    free(strcmp(names, fr{i})) = logical(opts.Free.(fr{i}));
end
tGiven = ~isempty(opts.Temperature) || isfield(opts.Initial, 'Temperature') || isfield(opts.Fixed, 'Temperature');
if ~free(4) && (~tGiven || ~(p0.Temperature > 0))
    error('FDD:TemperatureRequired', ...
        'Temperature is held fixed, so a positive Temperature (K) must be supplied.');
end
if ~any(free)
    error('FDD:NothingToFit', 'At least one parameter must be free.');
end

span = max(I) - min(I);
eStep = median(diff(E));
typical = [span, span / max(E(end) - E(1), eps), max(eStep, 1e-4), 10, max(eStep, 1e-4), span];
lb = [-Inf, -Inf, -Inf, 0.1, 0, -Inf];
ub = [ Inf,  Inf,  Inf, 5000, 1, Inf];

if strcmp(opts.Weights, 'poisson')
    wts = 1 ./ sqrt(max(I, 1));
else
    wts = ones(size(I));
end

x = cellfun(@(n) double(p0.(n)), names);
if any(~isfinite(x))
    error('FDD:InvalidParameter', 'Start/held values must be finite (check %s).', strjoin(names(~isfinite(x)), ', '));
end
if ~free(5) && x(5) < 0
    error('FDD:InvalidResolution', 'A held Resolution (FWHM) must be >= 0 eV.');
end
% Bounds apply to free parameters only; held values are used exactly as given.
x(free) = min(max(x(free), lb(free)), ub(free));
resfun = @(xv) wts .* (fdd_model(E, vec2struct(xv, names)) - I);

[x, iters, converged, J] = levenberg_marquardt(resfun, x, free, lb, ub, typical, opts.MaxIter);

R.names = names;
R.model = model.key;
R.free = free;
R.window = [min(E) max(E)];
R.E = E;
R.I = I;
R.params = vec2struct(x, names);
R.fit = fdd_model(E, R.params);
R.residual = I - R.fit;
r = resfun(x);
R.rss = sum(r.^2);
R.dof = numel(E) - nnz(free);
R.chi2red = R.rss / max(R.dof, 1);
R.rsquared = 1 - sum(R.residual.^2) / sum((I - mean(I)).^2);
R.iterations = iters;
R.converged = converged;
R.warnings = {};

stderr = nan(1, 6);
corrM = nan(6);
Jf = J(:, free) .* typical(free);
Hs = Jf' * Jf;
if rcond(Hs) > 1e-15
    cov = (Hs \ eye(nnz(free))) .* (typical(free)' * typical(free)) * R.chi2red;
    sd = sqrt(abs(diag(cov)))';
    stderr(free) = sd;
    corrM(free, free) = cov ./ (sd' * sd);
else
    R.warnings{end+1} = 'Jacobian is rank deficient: some free parameters are not determined by the data.';
end
R.stderr = vec2struct(stderr, names);
R.correlation = corrM;

if free(4) && free(5) && ~(abs(corrM(4, 5)) <= 0.9)
    R.warnings{end+1} = sprintf(['Temperature and resolution are strongly correlated (r = %.2f; NaN = ' ...
        'not separable); hold the temperature at the measured sample value (model rcfd_lin_bg_T).'], corrM(4, 5));
end
for k = find(free & (x <= lb | x >= ub))
    R.warnings{end+1} = sprintf('%s reached its bound (%g).', names{k}, x(k));
end
if ~converged
    R.warnings{end+1} = 'The optimiser stopped at the iteration limit before converging.';
end
if R.params.EF < min(E) || R.params.EF > max(E)
    R.warnings{end+1} = 'Fitted EF lies outside the fit window.';
end
end

function [x, iter, converged, J] = levenberg_marquardt(resfun, x, free, lb, ub, typical, maxIter)
lambda = 1e-3;
% Near-degenerate directions (e.g. T versus resolution) are handled by the
% damping term; MATLAB's singular-matrix warnings would only add noise.
ws = warning('off', 'MATLAB:nearlySingularMatrix');
ws(2) = warning('off', 'MATLAB:singularMatrix');
restore = onCleanup(@() warning(ws));  % restores the warning state on exit
r = resfun(x);
rss = sum(r.^2);
converged = false;
J = jacobian(resfun, x, r, lb, ub, typical, free);
for iter = 1:maxIter
    Jf = J(:, free) .* typical(free);          % scaled (dimensionless) problem
    A = Jf' * Jf;
    g = Jf' * r;
    improved = false;
    while lambda < 1e12
        M = A + lambda * diag(max(diag(A), 1e-12 * max(diag(A)) + realmin));
        step = -(M \ g)';
        xt = x;
        xt(free) = min(max(x(free) + step .* typical(free), lb(free)), ub(free));
        rt = resfun(xt);
        rsst = sum(rt.^2);
        if isfinite(rsst) && rsst < rss
            improved = true;
            break
        end
        lambda = lambda * 10;
    end
    if ~improved
        converged = true;
        break
    end
    relDrop = (rss - rsst) / max(rss, realmin);
    dx = abs(xt - x) ./ typical;
    x = xt; r = rt; rss = rsst;
    lambda = max(lambda / 10, 1e-12);
    J = jacobian(resfun, x, r, lb, ub, typical, free);
    if relDrop < 1e-12 || max(dx(free)) < 1e-10
        converged = true;
        break
    end
end
end

function J = jacobian(resfun, x, r0, lb, ub, typical, free)
% Central differences for the free parameters only (held columns stay 0).
J = zeros(numel(r0), numel(x));
for k = find(free)
    h = 1e-6 * max(abs(x(k)), typical(k));
    xp = x; xm = x;
    xp(k) = min(x(k) + h, ub(k));
    xm(k) = max(x(k) - h, lb(k));
    if xp(k) == xm(k)
        continue
    end
    J(:, k) = (resfun(xp) - resfun(xm)) / (xp(k) - xm(k));
end
end

function p = vec2struct(x, names)
for k = 1:numel(names)
    p.(names{k}) = x(k);
end
end

function check_names(s, names, label)
f = fieldnames(s);
bad = f(~ismember(f, names));
if ~isempty(bad)
    error('FDD:UnknownParameter', 'Unknown parameter "%s" in ''%s''. Valid names: %s.', bad{1}, label, strjoin(names, ', '));
end
end

function p = merge(p, extra, names)
f = fieldnames(extra);
for i = 1:numel(f)
    if ~any(strcmp(names, f{i}))
        error('FDD:UnknownParameter', 'Unknown parameter "%s".', f{i});
    end
    p.(f{i}) = extra.(f{i});
end
end

function [E, I] = clean_edc(E, I)
if ~isnumeric(E) || ~isnumeric(I)
    error('FDD:InvalidInput', 'E and I must be numeric vectors.');
end
E = double(E(:)); I = double(real(I(:)));
if numel(E) ~= numel(I)
    error('FDD:SizeMismatch', 'Energy and intensity must have the same number of elements.');
end
ok = isfinite(E) & isfinite(I);
E = E(ok); I = I(ok);
[E, order] = sort(E);
I = I(order);
end

function opts = parse_options(varargin)
p = inputParser;
p.FunctionName = 'fdd_fit_edc';
p.KeepUnmatched = false;
p.addParameter('Model', '');
p.addParameter('Window', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 2 && all(isfinite(v)) && v(1) ~= v(2)));
p.addParameter('Temperature', [], @(v) isempty(v) || (isnumeric(v) && isscalar(v) && isfinite(v) && v > 0));
p.addParameter('Initial', struct(), @isstruct);
p.addParameter('Fixed', struct(), @isstruct);
p.addParameter('Free', struct(), @isstruct);
p.addParameter('Weights', 'none', @(v) any(strcmpi(v, {'none','poisson'})));
p.addParameter('MaxIter', 300, @(v) isnumeric(v) && isscalar(v) && v >= 1);
p.parse(varargin{:});
opts = p.Results;
opts.Weights = lower(char(opts.Weights));
if isempty(opts.Model)
    if isempty(opts.Temperature)
        opts.Model = 'rcfd_lin_bg';
    else
        opts.Model = 'rcfd_lin_bg_T';
    end
end
end
