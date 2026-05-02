function [new_data, debug] = sym_map_data_autoMask_padded(data, opts)
% Symmetrize 3D map with C3 + mirror symmetry around (0,0), with:
% - automatic outside-mask detection (border-connected zero background)
% - optional feathering
% - NEW: zero/NaN padding margin in x/y to avoid hard cuts at raw boundary
%
% data.x, data.y vectors; data.value [Nx, Ny, Nz]
%
% opts (optional):
%   x_offset, y_offset
%   x_out, y_out
%   interp_method (default "cubic")
%   zero_eps       (default 0)        % treat |I|<=zero_eps as "zero"
%   use_threshold  (default false)
%   thr            (default 0)
%   feather_px     (default 20)
%   min_weight     (default 0.5)
%
%   pad_px         (default 50)       % padding size in pixels (grid points)
%   pad_value      (default 0)        % value to put in padded margin (0 recommended)

    if nargin < 2, opts = struct(); end
    if ~isfield(opts,'x_offset'), opts.x_offset = 0; end
    if ~isfield(opts,'y_offset'), opts.y_offset = 0; end
    if ~isfield(opts,'interp_method'), opts.interp_method = "linear"; end
    if ~isfield(opts,'zero_eps'), opts.zero_eps = 0; end
    if ~isfield(opts,'use_threshold'), opts.use_threshold = false; end
    if ~isfield(opts,'thr'), opts.thr = 0; end
    if ~isfield(opts,'feather_px'), opts.feather_px = 20; end
    if ~isfield(opts,'min_weight'), opts.min_weight = 0.5; end
    if ~isfield(opts,'pad_px'), opts.pad_px = 50; end
    if ~isfield(opts,'pad_value'), opts.pad_value = 0; end

    % Shift to symmetry center
    x0 = data.x - opts.x_offset;
    y0 = data.y - opts.y_offset;

    % Output grid
    if isfield(opts,'x_out'), x = opts.x_out; else, x = -2.1:0.01:2.1; end
    if isfield(opts,'y_out'), y = opts.y_out; else, y = -2.1:0.01:2.1; end
    [Y, X] = meshgrid(y, x);

    new_data = data;
    new_data.x = x;
    new_data.y = y;
    new_data.value = nan(numel(x), numel(y), numel(data.z));

    debug = struct();
    debug.valid_mask = cell(1, numel(data.z));
    debug.weight0    = cell(1, numel(data.z));
    debug.accW       = cell(1, numel(data.z));
    debug.x_in       = [];
    debug.y_in       = [];

    % Precompute padded coordinate vectors (assume roughly uniform grid)
    dx = median(diff(x0));
    dy = median(diff(y0));
    p  = max(0, round(opts.pad_px));

    x_in = [ (x0(1) - dx*(p:-1:1)), x0, (x0(end) + dx*(1:p)) ];
    y_in = [ (y0(1) - dy*(p:-1:1)), y0, (y0(end) + dy*(1:p)) ];
    debug.x_in = x_in;
    debug.y_in = y_in;

    for iz = 1:numel(data.z)
        I0 = data.value(:,:,iz);

        % 1) Pad intensity with a known background margin
        I = pad2d(I0, p, p, opts.pad_value);

        % 2) Background candidate map (zeros/NaNs/low)
        bgCand = isnan(I) | (abs(I) <= opts.zero_eps);
        if opts.use_threshold
            bgCand = bgCand | (I <= opts.thr);
        end

        % 3) Outside-of-support = bgCand connected to border
        outside = floodfill_border_connected(bgCand);

        % 4) Valid region and weights
        valid = ~outside;

        if opts.feather_px > 0
            W0 = feather_from_outside(~valid, opts.feather_px);
        else
            W0 = double(valid);
        end

        debug.valid_mask{iz} = valid;
        debug.weight0{iz}    = W0;

        % 5) Weighted symmetrization
        accV = zeros(numel(x), numel(y));
        accW = zeros(numel(x), numel(y));

        for dd = [0,180]
            Y_ = cosd(dd)*Y + sind(dd)*X;
            X_ = -sind(dd)*Y + cosd(dd)*X;

            Y_2 = cosd(dd)*Y - sind(dd)*X;
            X_2 = -sind(dd)*Y - cosd(dd)*X;

            [v1, w1] = sample_with_weights(x_in, y_in, I, W0,  X_,  Y_, opts.interp_method);
            [v2, w2] = sample_with_weights(x_in, y_in, I, W0,  X_2,  Y_2, opts.interp_method);

            accV = accV + v1.*w1 + v2.*w2;
            accW = accW + w1 + w2;
            % accV = accV + v1.*w1;
            % accW = accW + w1;
        end

        out = accV ./ accW;
        out(accW < opts.min_weight) = nan;
        new_data.value(:,:,iz) = out;
        debug.accW{iz} = accW;
    end
end

function A = pad2d(A0, px, py, pad_value)
% Pad a 2D matrix with px rows (top/bottom) and py cols (left/right)
    [nx, ny] = size(A0);
    A = pad_value * ones(nx + 2*px, ny + 2*py, class(A0));
    A(px+1:px+nx, py+1:py+ny) = A0;
end

function outside = floodfill_border_connected(bgCand)
% Return bgCand pixels that are connected to the border (4-connected).
    [nx, ny] = size(bgCand);
    outside = false(nx, ny);

    qx = zeros(nx*ny,1); qy = zeros(nx*ny,1); qs = 0; qe = 0;

    function push(i,j)
        qe = qe + 1;
        qx(qe) = i; qy(qe) = j;
        outside(i,j) = true;
    end

    for j = 1:ny
        if bgCand(1,j)  && ~outside(1,j),  push(1,j);  end
        if bgCand(nx,j) && ~outside(nx,j), push(nx,j); end
    end
    for i = 1:nx
        if bgCand(i,1)  && ~outside(i,1),  push(i,1);  end
        if bgCand(i,ny) && ~outside(i,ny), push(i,ny); end
    end

    while qs < qe
        qs = qs + 1;
        i = qx(qs); j = qy(qs);

        if i>1  && bgCand(i-1,j) && ~outside(i-1,j), push(i-1,j); end
        if i<nx && bgCand(i+1,j) && ~outside(i+1,j), push(i+1,j); end
        if j>1  && bgCand(i,j-1) && ~outside(i,j-1), push(i,j-1); end
        if j<ny && bgCand(i,j+1) && ~outside(i,j+1), push(i,j+1); end
    end
end

function W = feather_from_outside(outside, feather_px)
% No-toolbox approximate distance-to-outside up to feather_px (4-neighbor expansion).
    if feather_px <= 0
        W = double(~outside);
        return;
    end

    [nx, ny] = size(outside);
    dist = inf(nx, ny);
    dist(outside) = 0;

    cur = outside;
    for k = 1:feather_px
        cur2 = cur;
        cur2(2:end,:)   = cur2(2:end,:)   | cur(1:end-1,:);
        cur2(1:end-1,:) = cur2(1:end-1,:) | cur(2:end,:);
        cur2(:,2:end)   = cur2(:,2:end)   | cur(:,1:end-1);
        cur2(:,1:end-1) = cur2(:,1:end-1) | cur(:,2:end);

        newly = cur2 & isinf(dist);
        dist(newly) = k;
        cur = cur2;
    end

    W = dist / feather_px;
    W(~isfinite(W)) = 1;
    W = min(max(W,0),1);
    W = W.*W.*(3 - 2*W); % smoothstep
end

function [V, W] = sample_with_weights(x_in, y_in, Vin, Win, Xq, Yq, method)
% Interpolate values and weights. Out-of-range -> NaN -> weight 0.
    V = interp2(y_in, x_in, Vin, Yq, Xq, method, nan);
    W = interp2(y_in, x_in, Win, Yq, Xq, "linear", nan);

    bad = isnan(V) | isnan(W) | (W<=0);
    V(bad) = 0;
    W(bad) = 0;
end