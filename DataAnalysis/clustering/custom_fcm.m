k = 7;

[idxMap, U, C, objHist, info] = fcm_cluster_4d(i05_178697_RD.value, k, 'correlation', 2.0, 200, 1e-5);
% or
% [idxMap, U, C, objHist, info] = fcm_cluster_4d(i05_178697_RD.value, k, 'cosine', 2.0, 200, 1e-5);

figure;
imagesc(i05_178697_RD.x,i05_178697_RD.y,idxMap.');
axis image;
set(gca, 'YDir', 'normal');
colorbar;
xlabel('x index');
ylabel('y index');
title('FCM cluster map');



function [idxMap, U, C, objHist, info] = fcm_cluster_4d(value, k, distMethod, m, maxIter, tol)
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

    if ndims(value) ~= 4
        error('Input value must be a 4D array: [Nx, Ny, Nu, Nv].');
    end

    if ~ismember(lower(distMethod), {'cosine', 'correlation'})
        error('distMethod must be ''cosine'' or ''correlation''.');
    end

    [Nx, Ny, Nu, Nv] = size(value);
    nSites  = Nx * Ny;
    nPixels = Nu * Nv;

    % Convert to floating point once
    X = double(reshape(value, nSites, nPixels));

    % Keep only valid sites
    goodSite = all(isfinite(X), 2);
    X = X(goodSite, :);
    n = size(X, 1);

    if n < k
        error('Number of valid sites is smaller than k.');
    end

    % Optional: remove constant features to reduce numerical issues
    featureStd = std(X, 0, 1);
    goodFeature = featureStd > 0;
    X = X(:, goodFeature);

    % Recompute feature count after feature filtering
    p = size(X, 2);

    % ------------------------------------------------------------
    % Initialise membership matrix U
    % ------------------------------------------------------------
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