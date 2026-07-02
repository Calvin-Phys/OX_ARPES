% value is [Nx, Ny, Nu, Nv]
k = 14;

[idxMap, C, info] = kmeans_cluster_4d(i05_178697_RD.value, k, 'correlation');
% or
% [idxMap, C, info] = kmeans_cluster_4d(i05_178697_RD.value, k, 'cosine');

figure;
imagesc(i05_178697_RD.x,i05_178697_RD.y,idxMap.');
axis image;
set(gca, 'YDir', 'normal');
colorbar;
title('K-means cluster map in real space');
xlabel('x index');
ylabel('y index');


function [idxMap, C, info] = kmeans_cluster_4d(value, k, distMethod)
%KMEANS_CLUSTER_4D K-means clustering for 4D data:
% value: [Nx, Ny, Nu, Nv]
% k: number of clusters
% distMethod: 'correlation' (Pearson) or 'cosine'
%
% Output:
% idxMap: [Nx, Ny] cluster label map
% C: cluster centroids in feature space
% info: struct with reshaped data and validity mask

    if nargin < 3 || isempty(distMethod)
        distMethod = 'correlation';   % Pearson correlation distance
    end

    % Check input
    if ndims(value) ~= 4
        error('Input value must be a 4D array: [Nx, Ny, Nu, Nv].');
    end

    [Nx, Ny, Nu, Nv] = size(value);
    nSites  = Nx * Ny;
    nPixels = Nu * Nv;

    % Flatten each local 2D image into one row vector
    X = reshape(value, nSites, nPixels);

    % Handle invalid sites if needed
    goodSite = all(isfinite(X), 2);
    Xvalid = double(X(goodSite, :));   % kmeans works reliably in double

    % K-means clustering
    % 'correlation' = 1 - Pearson correlation
    % 'cosine'      = 1 - cosine similarity
    rng('default');  % optional, for reproducibility
    [idxValid, C, sumd, D] = kmeans(Xvalid, k, ...
        'Distance', distMethod, ...
        'Replicates', 10, ...
        'Start', 'plus', ...
        'MaxIter', 1000, ...
        'Display', 'final');

    % Put labels back into real-space grid
    idx = nan(nSites, 1);
    idx(goodSite) = idxValid;
    idxMap = reshape(idx, Nx, Ny);

    % Optional outputs
    info.X = X;
    info.goodSite = goodSite;
    info.sumd = sumd;
    info.D = D;
    info.distMethod = distMethod;
end