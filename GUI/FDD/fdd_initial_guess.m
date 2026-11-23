function p0 = fdd_initial_guess(E, I, T)
%FDD_INITIAL_GUESS  Data-driven starting values for a Fermi-edge fit.
%   p0 = FDD_INITIAL_GUESS(E, I) estimates Amplitude, Slope, EF,
%   Temperature, Resolution and Background from an EDC without assuming
%   that EF is near 0 eV (kinetic-energy axes are supported).
%   p0 = FDD_INITIAL_GUESS(E, I, T) uses a known temperature T (K) and
%   assigns the remaining edge width to the Gaussian resolution.
%
%   Method: the EDC is sorted by energy and lightly smoothed; EF0 is the
%   steepest descent; the 10-90 % edge width w is measured between the
%   occupied (low-energy) and unoccupied (high-energy) plateaus. For a pure
%   Fermi edge w = 4.394 kB*T; for a pure Gaussian step w = 1.089 FWHM.

c = fdd_constants();
[E, I] = clean_edc(E, I);
n = numel(E);
if n < 5
    error('FDD:TooFewPoints', 'At least 5 finite EDC points are needed (got %d).', n);
end
win = max(3, round(n / 25));
Is = movmean(I, win);
dI = gradient(Is, E);
[~, iEdge] = min(dI);
EF0 = E(iEdge);

nTail = max(2, round(0.15 * n));
lowLevel = mean(Is(1:nTail));
highLevel = mean(Is(end-nTail+1:end));
if lowLevel <= highLevel
    lowLevel = max(Is); highLevel = min(Is);
end
span = lowLevel - highLevel;
lev90 = highLevel + 0.9 * span;
lev10 = highLevel + 0.1 * span;
i90 = find(Is(1:iEdge) >= lev90, 1, 'last');
i10 = iEdge - 1 + find(Is(iEdge:end) <= lev10, 1, 'first');
if isempty(i90), i90 = 1; end
if isempty(i10), i10 = n; end
w = max(E(i10) - E(i90), 2 * median(diff(E)));

below = E < EF0 - w;
if nnz(below) >= 3
    pl = polyfit(E(below) - EF0, I(below), 1);
    slope0 = pl(1);
else
    slope0 = 0;
end

p0.Amplitude = span;
p0.Slope = slope0;
p0.EF = EF0;
p0.Background = highLevel;
if nargin >= 3 && ~isempty(T) && T > 0
    p0.Temperature = T;
    wT = 4.394 * c.kB * T;
    p0.Resolution = sqrt(max(w^2 - wT^2, (0.25 * w)^2)) / 1.089;
else
    p0.Temperature = max(w / (4.394 * c.kB), 1);
    p0.Resolution = 0.5 * w / 1.089;
end
end

function [E, I] = clean_edc(E, I)
E = double(E(:)); I = double(I(:));
if numel(E) ~= numel(I)
    error('FDD:SizeMismatch', 'Energy and intensity must have the same number of elements.');
end
ok = isfinite(E) & isfinite(I);
E = E(ok); I = I(ok);
% Average repeated energies (e.g. merged sweeps) so gradient() stays finite.
[E, ~, g] = unique(E);
I = accumarray(g, I, [], @mean);
end
