kList = 2:20;

[idxMap, bestK, elbowInfo] = kmeans_cluster_4d_elbow(i05_178697_RD.value, kList, 'cosine');

bestK = 4;   % set this after looking at the elbow plot
[idxMap, bestK, elbowInfo] = kmeans_cluster_4d_elbow(i05_178697_RD.value, kList, 'correlation');

figure;
imagesc(i05_178697_RD.x,i05_178697_RD.y,idxMap.');
axis image;
set(gca, 'YDir', 'normal');
colorbar;
title(sprintf('Cluster map, k = %d', bestK));

function [idxMap, bestK, elbowInfo] = kmeans_cluster_4d_elbow(value, kList, distMethod)
%KMEANS_CLUSTER_4D_ELBOW K-means on 4D data with elbow method.
% value: [Nx, Ny, Nu, Nv]
% kList: vector of candidate k values, e.g. 2:10
% distMethod: 'correlation' or 'cosine'
%
% Outputs:
% idxMap: [Nx, Ny] cluster labels for the selected bestK
% bestK: chosen k from the elbow scan
% elbowInfo: struct with scan results

    if nargin < 2 || isempty(kList)
        kList = 2:10;
    end
    if nargin < 3 || isempty(distMethod)
        distMethod = 'correlation';   % Pearson-type distance
    end

    if ndims(value) ~= 4
        error('Input must be a 4D array: [Nx, Ny, Nu, Nv].');
    end

    [Nx, Ny, Nu, Nv] = size(value);
    nSites  = Nx * Ny;
    nPixels = Nu * Nv;

    % Flatten each local image into one row
    X = reshape(value, nSites, nPixels);

    % Keep only valid sites
    goodSite = all(isfinite(X), 2);
    Xvalid = double(X(goodSite, :));

    % Elbow scan
    nK = numel(kList);
    totalDist = nan(nK, 1);

    rng('default');  % reproducibility

    for ii = 1:nK
        k = kList(ii);

        [~, ~, sumd] = kmeans(Xvalid, k, ...
            'Distance', distMethod, ...
            'Replicates', 10, ...
            'Start', 'plus', ...
            'MaxIter', 1000, ...
            'Display', 'off');

        totalDist(ii) = sum(sumd);
    end

    % Plot elbow curve
    figure;
    plot(kList, totalDist, '-o', 'LineWidth', 1.5);
    xlabel('Number of clusters k');
    ylabel('Total within-cluster distance');
    title(['Elbow method using ', distMethod, ' distance']);
    grid on;

    % Choose k
    % Here: simple manual choice by reading the elbow plot.
    % If you want fully automatic selection, you need an extra rule.
    bestK = kList(1);  % placeholder default
    disp('Inspect the elbow plot and set bestK manually if needed.');

    % Example manual assignment:
    % bestK = 4;

    % Final clustering with chosen k
    [idxValid, C, sumd, D] = kmeans(Xvalid, bestK, ...
        'Distance', distMethod, ...
        'Replicates', 10, ...
        'Start', 'plus', ...
        'MaxIter', 1000, ...
        'Display', 'final');

    idx = nan(nSites, 1);
    idx(goodSite) = idxValid;
    idxMap = reshape(idx, Nx, Ny);

    % Save info
    elbowInfo.kList = kList;
    elbowInfo.totalDist = totalDist;
    elbowInfo.C = C;
    elbowInfo.sumd = sumd;
    elbowInfo.D = D;
    elbowInfo.distMethod = distMethod;
    elbowInfo.goodSite = goodSite;
end