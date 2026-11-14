function [idxMap, U, C, objHist, info] = custom_fcm(value, k, distMethod, m, maxIter, tol)
%FCM_CLUSTER_4D Fuzzy c-means clustering for 4D data.
%
% Input:
%   value      : [Nx, Ny, Nu, Nv]
%   k          : number of clusters
%   distMethod : 'cosine' or 'correlation'
%   m          : fuzziness exponent, usually 2.0
%   maxIter    : maximum iterations, e.g. 200
%   tol        : convergence tolerance, e.g. 1e-5
%
% Output:
%   idxMap  : [Nx, Ny] hard label map from max membership
%   U       : [k, nValidSites] membership matrix
%   C       : [k, nFeatures] cluster centers
%   objHist : objective function history
%   info    : extra diagnostic information

    if nargin < 3 || isempty(distMethod)
        distMethod = 'correlation';   % Pearson-type distance
    end
    if nargin < 4 || isempty(m)
        m = 2.0;
    end
    if nargin < 5 || isempty(maxIter)
        maxIter = 200;
    end
    if nargin < 6 || isempty(tol)
        tol = 1e-5;
    end

    if ndims(value) < 3 || ndims(value) > 4
        error('Input value must represent [Nx, Ny, Nu, Nv] (Nv may be singleton).');
    end

    distMethod = lower(char(distMethod));
    if ~ismember(distMethod, {'cosine', 'correlation'})
        error('distMethod must be ''cosine'' or ''correlation''.');
    end
    validateattributes(k, {'numeric'}, {'scalar','integer','>=',2});
    validateattributes(m, {'numeric'}, {'scalar','real','finite','>',1});
    validateattributes(maxIter, {'numeric'}, {'scalar','integer','positive'});
    validateattributes(tol, {'numeric'}, {'scalar','real','finite','positive'});

    [Nx, Ny, Nu, Nv] = size(value);
    nSites  = Nx * Ny;
    nPixels = Nu * Nv;

    % Convert to floating point once
    X = double(reshape(value, nSites, nPixels));

    % Keep only valid sites
    goodSite = all(isfinite(X), 2);
    if strcmp(distMethod,'correlation')
        goodSite = goodSite & std(X,0,2) > 0;
    end
    X = X(goodSite, :);
    n = size(X, 1);

    if n < k
        error('Number of valid sites is smaller than k.');
    end

    % Optional: remove constant features to reduce numerical issues
    featureStd = std(X, 0, 1);
    goodFeature = featureStd > 0;
    X = X(:, goodFeature);

    if ~any(goodFeature)
        error('OxArpes:ConstantData', ...
            'No nonconstant spectral features remain for clustering.');
    end

    % Recompute feature count after feature filtering
    p = size(X, 2);

    % ------------------------------------------------------------
    % Initialise membership matrix U
    % ------------------------------------------------------------
    rngState = rng;
    rngCleanup = onCleanup(@() rng(rngState)); %#ok<NASGU>
    rng('default');  % reproducible initialisation
    U = rand(k, n);
    U = U ./ sum(U, 1);

    objHist = zeros(maxIter, 1);

    for iter = 1:maxIter
        Uold = U;

        % --------------------------------------------------------
        % 1) Update cluster centers
        %    Cj = sum_i (u_ij^m * x_i) / sum_i u_ij^m
        % --------------------------------------------------------
        Um = U.^m;
        C = (Um * X) ./ sum(Um, 2);

        % Guard against zero centers
        C(~isfinite(C)) = 0;

        % --------------------------------------------------------
        % 2) Compute distances from each sample to each center
        %    D(i,j) = distance between X(i,:) and C(j,:)
        % --------------------------------------------------------
        D = pdist2(X, C, distMethod);

        % Avoid division by zero
        D(D < eps) = eps;

        % --------------------------------------------------------
        % 3) Update memberships
        %    u_ij = 1 / sum_l (d_ij / d_il)^(2/(m-1))
        % --------------------------------------------------------
        power = 2 / (m - 1);

        for i = 1:n
            di = D(i, :);  % 1 x k

            if any(di == eps)
                % If a point matches a center exactly, assign full membership there
                U(:, i) = 0;
                [~, jmin] = min(di);
                U(jmin, i) = 1;
            else
                ratio = (di.' ./ di).^power;  % k x k
                U(:, i) = 1 ./ sum(ratio, 2);
            end
        end

        % Normalise columns to protect against numerical drift
        U = U ./ sum(U, 1);

        % --------------------------------------------------------
        % 4) Objective function
        %    Standard FCM-like form with chosen distance
        % --------------------------------------------------------
        objHist(iter) = sum(sum((U.^m) .* (D'.^2)));

        % Convergence check
        if max(abs(U(:) - Uold(:))) < tol
            objHist = objHist(1:iter);
            break;
        end
    end

    % ------------------------------------------------------------
    % Hard labels and output map
    % ------------------------------------------------------------
    [~, idxValid] = max(U, [], 1);

    idx = nan(nSites, 1);
    idx(goodSite) = idxValid;
    idxMap = reshape(idx, Nx, Ny);

    % Extra info
    info.goodSite = goodSite;
    info.goodFeature = goodFeature;
    info.distMethod = distMethod;
    info.m = m;
    info.nIter = numel(objHist);
    info.X = X;
    info.p = p;
    info.nValidSites = n;
end
