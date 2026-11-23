function [E, I, p] = fdd_synthetic(varargin)
%FDD_SYNTHETIC  Synthetic Fermi-edge EDC with known parameters (test fixture).
%   [E, I, p] = FDD_SYNTHETIC('EF',0.0123,'Temperature',30,'Resolution',0.015,
%       'Amplitude',1000,'Slope',-800,'Background',40,'Step',0.002,
%       'Range',[-0.15 0.08],'Noise','poisson','Seed',1)
%   Noise 'poisson' adds Gaussian noise with variance equal to the mean
%   (normal approximation; no Statistics Toolbox needed); 'none' is exact.
%   The truth is computed by an independent direct numerical integral of
%   the Gaussian-broadened Fermi function (integral(), not FDD_MODEL).
ip = inputParser;
ip.addParameter('EF', 0.0123); ip.addParameter('Temperature', 30);
ip.addParameter('Resolution', 0.015); ip.addParameter('Amplitude', 1000);
ip.addParameter('Slope', -800); ip.addParameter('Background', 40);
ip.addParameter('Step', 0.002); ip.addParameter('Range', [-0.15 0.08]);
ip.addParameter('Noise', 'poisson'); ip.addParameter('Seed', 1);
ip.parse(varargin{:});
p = rmfield(ip.Results, {'Step','Range','Noise','Seed'});
E = (p.EF + (ip.Results.Range(1):ip.Results.Step:ip.Results.Range(2)))';
I = reference_model(E, p);
if strcmp(ip.Results.Noise, 'poisson')
    rng(ip.Results.Seed, 'twister');
    I = I + sqrt(max(I, 0)) .* randn(size(I));
end
end

function I = reference_model(E, p)
kB = 8.617333262e-5;
occ = @(e) 1 ./ (exp((e - p.EF) ./ (kB * p.Temperature)) + 1);
lin = @(e) (p.Amplitude + p.Slope .* (e - p.EF)) .* occ(e);
if p.Resolution == 0
    I = lin(E) + p.Background;
    return
end
s = p.Resolution / (2 * sqrt(2 * log(2)));
I = zeros(size(E));
for k = 1:numel(E)
    g = @(x) exp(-0.5 * (x / s).^2) / (s * sqrt(2 * pi)) .* lin(E(k) - x);
    I(k) = integral(g, -8 * s, 8 * s, 'AbsTol', 1e-10, 'RelTol', 1e-10);
end
I = I + p.Background;
end
