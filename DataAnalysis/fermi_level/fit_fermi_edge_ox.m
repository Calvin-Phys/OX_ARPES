function result = fit_fermi_edge_ox(E, I, varargin)
%FIT_FERMI_EDGE_OX  Robust Fermi edge fitting for ARPES
%
% result = fit_fermi_edge_ox(E, I, 'Name', value, ...)
%
% Required:
%   E  - energy axis (vector, monotonic)
%   I  - intensity vector
%
% Optional:
%   'Temperature'     (K)
%   'Resolution'      (eV FWHM)
%   'Fermi0'          (eV)
%   'FitWindow'       (eV, default 0.3)
%   'FixTemperature'  (true/false)
%   'FixResolution'   (true/false)
%
% Resolution can only be fitted when FixTemperature = true.

% ------------------------------------------------------------
% Input parsing
% ------------------------------------------------------------

p = inputParser;
addParameter(p,'Temperature',[]);
addParameter(p,'Resolution',[]);
addParameter(p,'Fermi0',[]);
addParameter(p,'FitWindow',0.3);
addParameter(p,'FixTemperature',false);
addParameter(p,'FixResolution',true);
addParameter(p,'Debug',false);

parse(p,varargin{:});
opt = p.Results;
debugMode = opt.Debug;

result = result_template();

kb = 8.617333262e-5;

E = E(:);
I = I(:);

% ------------------------------------------------------------
% Guard: empty / zero / flat EDC
% ------------------------------------------------------------

if isempty(I) || all(~isfinite(I))
    return
end

if max(abs(I)) < eps
    % All zero or numerically negligible
    return
end

% ------------------------------------------------------------
% Robust axis orientation detection
% ------------------------------------------------------------
if median(diff(E)) < 0
    E = flipud(E);
    I = flipud(I);
end


% ------------------------------------------------------------
% Automatic EF estimate from derivative
% ------------------------------------------------------------

if isempty(opt.Fermi0)
    % Smooth
    Is = smoothdata(I,'gaussian',7);
    
    % First derivative
    dIdE = gradient(Is)./gradient(E);
    
    % Only consider negative slopes
    neg_mask = dIdE < 0;
    
    if ~any(neg_mask)
        return
    end
    
    % Compute local contrast: difference across small window
    dE = mean(diff(E));
    
    kB = 8.617333262e-5;
    
    if ~isempty(opt.Temperature)
        FWHM_th = 3.5 * kB * opt.Temperature;
    else
        % fallback if temperature unknown
        FWHM_th = 0.02;  % 20 meV typical
    end
    
    if ~isempty(opt.Resolution)
        FWHM_total = sqrt(FWHM_th^2 + opt.Resolution^2);
    else
        FWHM_total = FWHM_th;
    end
    
    window_energy = 2 * FWHM_total;   % ±2×FWHM span
    window = max(7, round(window_energy / dE));
    contrast = zeros(size(Is));
    
    for k = window+1 : length(Is)-window
        left_mean  = mean(Is(k-window:k-1));
        right_mean = mean(Is(k+1:k+window));
        contrast(k) = left_mean - right_mean;  % drop magnitude
    end
    
    contrast = max(contrast, 0);  % only positive drops
    
    % High-energy weight (normalized 0→1)
    E_norm = (E - min(E)) / (max(E) - min(E));
    energy_weight = E_norm.^2;   % bias toward high energy
    
    % Combined score
    score = abs(dIdE) .* contrast .* energy_weight;
    
    % Mask positive slopes
    score(~neg_mask) = 0;
    
    % Pick maximum score
    [~, idx] = max(score);
    
    EF0 = E(idx);
else
    EF0 = opt.Fermi0;
end

w = opt.FitWindow;
mask = (E > EF0 - w) & (E < EF0 + w);
Ew = E(mask);
Iw = I(mask);

dynamic_range = max(Iw) - min(Iw);
if dynamic_range < 1e-8 * max(abs(Iw))
    return
end

if numel(Ew) < 10
    return
end

% ------------------------------------------------------------
% -------- Stage 1: Fast non-convolved fit -------------------
% ------------------------------------------------------------

if isempty(opt.Temperature)
    T0 = 100;
else
    T0 = opt.Temperature;
end

A0 = max(Iw) - min(Iw);
S0 = 0;
B0 = min(Iw);

% Decide whether T is fixed in fast stage
if opt.FixTemperature && ~isempty(opt.Temperature)

    Tfix = opt.Temperature;

    ft_fast = fittype(@(A,S,EF,B,x) ...
        (A + S*(x-EF))./(exp((x-EF)./(kb*Tfix))+1) + B, ...
        'independent','x');

    opts1 = fitoptions(ft_fast);
    opts1.StartPoint = [A0,S0,EF0,B0];
    A_scale = max(abs(Iw));
    opts1.Lower = [-2*A_scale, -abs(A0)/w, min(Ew), min(Iw)-abs(A_scale)];
    opts1.Upper = [ 2*A_scale,  abs(A0)/w, max(Ew), max(Iw)+abs(A_scale)];


    fit_fast = fit(Ew,Iw,ft_fast,opts1);
    c = coeffvalues(fit_fast);

    A1 = c(1); S1 = c(2); EF1 = c(3); B1 = c(4);
    T1 = Tfix;

else

    ft_fast = fittype(@(A,S,EF,T,B,x) ...
        (A + S*(x-EF))./(exp((x-EF)./(kb*T))+1) + B, ...
        'independent','x');

    opts1 = fitoptions(ft_fast);
    opts1.StartPoint = [A0,S0,EF0,T0,B0];
    A_scale = max(abs(Iw));
    opts1.Lower = [-2*A_scale, -abs(A0)/w, min(Ew), 1, min(Iw)-abs(A_scale)];
    opts1.Upper = [ 2*A_scale,  abs(A0)/w, max(Ew), 1000, max(Iw)+abs(A_scale)];


    fit_fast = fit(Ew,Iw,ft_fast,opts1);
    c = coeffvalues(fit_fast);

    A1 = c(1); S1 = c(2); EF1 = c(3); T1 = c(4); B1 = c(5);

end

% If no convolution requested → return fast result
if isempty(opt.Resolution) && opt.FixResolution
    % result = pack_result(EF1,A1,S1,B1,T1,[],fit_fast,[]);
    result.EF = EF1;
    result.Amplitude = A1;
    result.Slope = S1;
    result.Background = B1;
    result.Temperature = T1;
    result.Resolution = [];
    result.fitobj = fit_fast;
    result.gof = [];
    result.isValid = true;
    return
end

if debugMode

    figure('Name','Fermi Fit Debug','NumberTitle','off');
    subplot(2,1,1)

    plot(E, I, 'k-'); hold on
    plot(Ew, Iw, 'bo')
    xline(EF0,'--r','Initial EF')
    xline(EF1,'--g','Fitted EF')
    title('Original EDC and Fit Window')
    xlabel('Energy (eV)')
    ylabel('Intensity')
    legend('Full EDC','Fit Window')

    subplot(2,1,2)

    plot(Ew, Iw, 'ko','DisplayName','Data'); hold on

    % Evaluate fitted curve explicitly
    if opt.FixTemperature && ~isempty(opt.Temperature)
        Tplot = opt.Temperature;
        Ifit_plot = (A1 + S1*(Ew-EF1)) ./ ...
            (exp((Ew-EF1)./(kb*Tplot))+1) + B1;
    else
        Ifit_plot = (A1 + S1*(Ew-EF1)) ./ ...
            (exp((Ew-EF1)./(kb*T1))+1) + B1;
    end

    plot(Ew, Ifit_plot, 'r-', 'LineWidth',1.5, ...
        'DisplayName','Fast Fit')

    title(sprintf('Stage 1 Fit  |  A=%.3g  S=%.3g  EF=%.6f', ...
        A1, S1, EF1))

    xlabel('Energy (eV)')
    ylabel('Intensity')
    legend
    grid on

end

% ------------------------------------------------------------
% -------- Stage 2: Convolution fit --------------------------
% ------------------------------------------------------------

dE = mean(diff(Ew));

% -------- Case A: Resolution fixed --------------------------

if opt.FixResolution

    if isempty(opt.Resolution)
        error('Resolution must be provided if FixResolution = true.');
    end

    FWHM = opt.Resolution;
    sigma = FWHM/(2*sqrt(2*log(2)));

    kernel_x = (-5*sigma:dE:5*sigma)';
    G = exp(-0.5*(kernel_x/sigma).^2);
    G = G/sum(G);

    if opt.FixTemperature

        Tfix = opt.Temperature;

        ft = fittype(@(A,S,EF,B,x) ...
            conv((A+S*(x-EF))./(exp((x-EF)./(kb*Tfix))+1), ...
                 G,'same') + B, ...
            'independent','x');

        opts2 = fitoptions(ft);
        opts2.StartPoint = [A1,S1,EF1,B1];
        A_scale = max(abs(Iw));
        opts2.Lower = [-2*A_scale, -abs(A1)/w, min(Ew), min(Iw)-abs(A_scale)];
        opts2.Upper = [ 2*A_scale,  abs(A1)/w, max(Ew), max(Iw)+abs(A_scale)];


        fit_final = fit(Ew,Iw,ft,opts2);
        c = coeffvalues(fit_final);

        %result = pack_result(c(3),c(1),c(2),c(4),Tfix,FWHM,fit_final,[]);
        result.EF = c(3);
        result.Amplitude = c(1);
        result.Slope = c(2);
        result.Background = c(4);
        result.Temperature = Tfix;
        result.Resolution = FWHM;
        result.fitobj = fit_final;
        result.gof = [];
        result.isValid = true;

    else

        ft = fittype(@(A,S,EF,T,B,x) ...
            conv((A+S*(x-EF))./(exp((x-EF)./(kb*T))+1), ...
                 G,'same') + B, ...
            'independent','x');

        opts2 = fitoptions(ft);
        opts2.StartPoint = [A1,S1,EF1,T1,B1];
        A_scale = max(abs(Iw));
        opts2.Lower = [-2*A_scale, -abs(A1)/w, min(Ew), 1, min(Iw)-abs(A_scale)];
        opts2.Upper = [ 2*A_scale,  abs(A1)/w, max(Ew), 1000, max(Iw)+abs(A_scale)];


        fit_final = fit(Ew,Iw,ft,opts2);
        c = coeffvalues(fit_final);

        % result = pack_result(c(3),c(1),c(2),c(5),c(4),FWHM,fit_final,[]);
        result.EF = c(3);
        result.Amplitude = c(1);
        result.Slope = c(2);
        result.Background = c(5);
        result.Temperature = c(4);
        result.Resolution = FWHM;
        result.fitobj = fit_final;
        result.gof = [];
        result.isValid = true;

    end

% -------- Case B: Resolution fitted (T must be fixed) -------

else

    if ~opt.FixTemperature
        error('Resolution fitting requires FixTemperature = true.');
    end

    Tfix = opt.Temperature;

    if isempty(opt.Resolution)
        FWHM0 = 0.03;
    else
        FWHM0 = opt.Resolution;
    end

    ft = fittype(@(A,S,EF,FWHM,B,x) ...
        local_conv(A,S,EF,FWHM,B,x,kb,Tfix,dE), ...
        'independent','x');

    opts2 = fitoptions(ft);
    opts2.StartPoint = [A1,S1,EF1,FWHM0,B1];

    A_scale = max(abs(Iw));
    opts2.Lower = [-2*A_scale, -abs(A1)/w, min(Ew), 0.001, min(Iw)-abs(A_scale)];
    opts2.Upper = [ 2*A_scale,  abs(A1)/w, max(Ew), 0.1,   max(Iw)+abs(A_scale)];


    fit_final = fit(Ew,Iw,ft,opts2);
    c = coeffvalues(fit_final);

    % result = pack_result(c(3),c(1),c(2),c(5),Tfix,c(4),fit_final,[]);
    result.EF = c(3);
    result.Amplitude = c(1);
    result.Slope = c(2);
    result.Background = c(5);
    result.Temperature = Tfix;
    result.Resolution = c(4);
    result.fitobj = fit_final;
    result.gof = [];
    result.isValid = true;

end

if debugMode

    figure('Name','Fermi Fit Debug - Final','NumberTitle','off');

    plot(Ew, Iw, 'ko', 'DisplayName','Data'); hold on

    % Stage 1 fitted curve (exactly as fitted)
    y_fast = fit_fast(Ew);
    plot(Ew, y_fast, 'b--', ...
        'LineWidth',1.2, ...
        'DisplayName','Stage 1 (Fast)');

    % Stage 2 fitted curve (exactly as fitted)
    y_final = fit_final(Ew);
    plot(Ew, y_final, 'r-', ...
        'LineWidth',1.5, ...
        'DisplayName','Stage 2 (Final)');

    xline(result.EF,'--k','EF final');

    xlabel('Energy (eV)');
    ylabel('Intensity');

    title(sprintf(['Final Fit  |  EF=%.6f  T=%.2f K  ' ...
                   'Res=%.4f eV'], ...
                   result.EF, ...
                   result.Temperature, ...
                   result.Resolution));

    legend;
    grid on;

    fprintf('\n--- Stage 2 Debug ---\n');
    fprintf('EF = %.6f eV\n', result.EF);
    fprintf('Amplitude = %.4e\n', result.Amplitude);
    fprintf('Slope = %.4e\n', result.Slope);
    fprintf('Background = %.4e\n', result.Background);
    fprintf('Temperature = %.3f K\n', result.Temperature);
    fprintf('Resolution (FWHM) = %.5f eV\n', result.Resolution);
    fprintf('----------------------\n');

end

end

% ------------------------------------------------------------
% Convolution helper
% ------------------------------------------------------------
function y = local_conv(A,S,EF,FWHM,B,x,kb,T,dE)

sigma = FWHM/(2*sqrt(2*log(2)));
kernel_x = (-5*sigma:dE:5*sigma)';
G = exp(-0.5*(kernel_x/sigma).^2);
G = G/sum(G);

fermi = (A+S*(x-EF))./(exp((x-EF)./(kb*T))+1);
y = conv(fermi,G,'same') + B;

end

% ------------------------------------------------------------
% Output packer
% ------------------------------------------------------------

function result = result_template()

result = struct( ...
    'EF', [], ...
    'Amplitude', [], ...
    'Slope', [], ...
    'Background', [], ...
    'Temperature', [], ...
    'Resolution', [], ...
    'fitobj', [], ...
    'gof', [], ...
    'isValid', false);

end

