%% -----------------------------
%  PCA reduction + k-means clustering
%  -----------------------------

% Target cumulative explained variance for PCA
targetVariance = 95;   % in percent

% Perform PCA reduction on the 4D spectral data
out = pca_reduce_4d(i05_178698_RD.value, targetVariance);

% Reconstructed 4D data from the retained PCs
i05_178698_PCA.value = out.valueRec;

% PCA score maps for clustering
% size: [Nx, Ny, nComp]
pc_maps = out.scoreMap;

%% Elbow method for choosing nClusters

% Flatten PCA score maps into a feature matrix
% rows = pixels, cols = PCA components
[Nx, Ny, nComp] = size(pc_maps);
features = reshape(pc_maps, [], nComp);

% Remove invalid rows if needed
validMask = all(isfinite(features), 2);
X = features(validMask, :);

% Range of cluster numbers to test
kList = 2:15;

% Store total within-cluster sum of squares
wcss = zeros(size(kList));

rng(0);  % reproducible

for i = 1:numel(kList)
    k = kList(i);

    [~, ~, sumd] = kmeans(X, k, ...
        'Replicates', 10, ...
        'Start', 'plus', ...
        'MaxIter', 1000, ...
        'Display', 'off');

    % Total within-cluster sum of distances
    wcss(i) = sum(sumd);
end

% Plot elbow curve
figure;
plot(kList, wcss, '-o', 'LineWidth', 1.5);
xlabel('Number of clusters k');
ylabel('Total within-cluster sum of squares');
title('Elbow method for k-means');
grid on;

%% -------------------------------------------------------------------------
% k-means clustering on PCA score vectors
% Each spatial pixel is represented by one nComp-dimensional score vector.
% -------------------------------------------------------------------------

% Number of k-means clusters
nClusters = 8;

[Nx, Ny, nComp] = size(pc_maps);

% Reshape to a 2D feature matrix:
%   rows   = pixels
%   cols   = retained PCA components
features = reshape(pc_maps, [], nComp);

% Optional: remove pixels with any NaN/Inf values
validMask = all(isfinite(features), 2);
featuresValid = features(validMask, :);

% Reproducibility
rng(0);

% k-means clustering
% 'plus' is usually a good initialisation strategy
[idxValid, C] = kmeans(featuresValid, nClusters, ...
    'Replicates', 10, ...
    'Start', 'plus', ...
    'MaxIter', 1000, ...
    'Display', 'final');

% Put the cluster labels back into the full image size
idx = nan(size(features,1), 1);
idx(validMask) = idxValid;
clusterMap = reshape(idx, Nx, Ny);

% -------------------------------------------------------------------------
% Visualisation
% -------------------------------------------------------------------------

figure;
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

% Cluster map
nexttile;
imagesc(i05_178698_RD.x,i05_178698_RD.y,clusterMap.');
axis image;
set(gca, 'YDir', 'normal');
title(sprintf('k-means cluster map (k = %d)', nClusters));
colormap(gca, turbo(nClusters));
colorbar;

% First principal component score map
nexttile;
imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,1).');
axis image off;
set(gca, 'YDir', 'normal');
title('PC1 score map');
colorbar;

% Second principal component score map, if available
nexttile;
if nComp >= 2
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,2).');
    title('PC2 score map');
else
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,1).');
    title('PC2 not available');
end
axis image off;
set(gca, 'YDir', 'normal');
colorbar;

% Third principal component score map, if available
nexttile;
if nComp >= 3
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,3).');
    title('PC3 score map');
else
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,1).');
    title('PC3 not available');
end
axis image off;
set(gca, 'YDir', 'normal');
colorbar;

% Third principal component score map, if available
nexttile;
if nComp >= 4
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,4).');
    title('PC3 score map');
else
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,1).');
    title('PC3 not available');
end
axis image off;
set(gca, 'YDir', 'normal');
colorbar;

% Third principal component score map, if available
nexttile;
if nComp >= 5
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,5).');
    title('PC3 score map');
else
    imagesc(i05_178698_RD.x,i05_178698_RD.y,pc_maps(:,:,1).');
    title('PC3 not available');
end
axis image off;
set(gca, 'YDir', 'normal');
colorbar;

function out = pca_reduce_4d(value, targetVariance)
%PCA_REDUCE_4D Perform PCA on a 4D spectral image and reconstruct it.
%
% Input
%   value           : 4D array [Nx, Ny, Ns1, Ns2]
%   targetVariance  : cumulative explained variance target, e.g. 95
%                     If passed as 0.95, it is interpreted as 95%.
%
% Output structure
%   out.scoreMap     : [Nx, Ny, nComp] PCA score maps for each retained PC
%   out.coeff        : PCA loadings for retained PCs
%   out.mu           : mean spectrum used by PCA
%   out.explained    : explained variance (%) for retained PCs
%   out.cumVar       : cumulative explained variance (%) for retained PCs
%   out.nComp        : number of retained PCs
%   out.targetVariance : requested variance threshold
%   out.valueRec     : reconstructed 4D array using retained PCs
%   out.valueFlat    : original flattened data [Nx*Ny, Ns1*Ns2]
%   out.valueRecFlat : reconstructed flattened data [Nx*Ny, Ns1*Ns2]
%
% Notes
%   - Each (x,y) pixel is treated as one observation.
%   - The last two dimensions are flattened into one spectral feature vector.
%   - PCA is performed on the flattened matrix.

    % Check input
    if ndims(value) ~= 4
        error('Input "value" must be a 4D array: [Nx, Ny, Ns1, Ns2].');
    end

    % Interpret targetVariance
    if nargin < 2 || isempty(targetVariance)
        targetVariance = 95;
    end
    if targetVariance <= 1
        targetVariance = 100 * targetVariance;
    end

    % PCA works best with floating-point data
    value = double(value);

    % Original dimensions
    [Nx, Ny, Ns1, Ns2] = size(value);
    nPix  = Nx * Ny;
    nFeat = Ns1 * Ns2;

    % Flatten the 4D data into a 2D matrix:
    % rows = spatial pixels, columns = spectral features
    valueFlat = reshape(value, nPix, nFeat);

    % ---------------------------------------------------------------------
    % PCA
    % ---------------------------------------------------------------------
    [coeff, score, ~, ~, explained, mu] = pca(valueFlat, 'Economy', true);

    % Cumulative explained variance
    cumExplained = cumsum(explained);

    % Find the minimum number of PCs reaching the target variance
    nComp = find(cumExplained >= targetVariance, 1, 'first');

    % Safety fallback in case the threshold is not reached for some reason
    if isempty(nComp)
        nComp = size(score, 2);
    end

    % Keep only the retained PCs
    scoreLow = score(:, 1:nComp);
    coeffLow = coeff(:, 1:nComp);

    % Reconstruct the flattened data from retained PCs
    valueRecFlat = scoreLow * coeffLow' + mu;

    % Reshape score vectors back to spatial maps
    scoreMap = reshape(scoreLow, Nx, Ny, nComp);

    % Reshape reconstructed data back to 4D
    valueRec = reshape(valueRecFlat, Nx, Ny, Ns1, Ns2);

    % Pack outputs
    out.scoreMap       = scoreMap;
    out.coeff          = coeffLow;
    out.mu             = mu;
    out.explained      = explained(1:nComp);
    out.cumVar         = cumExplained(1:nComp);
    out.nComp          = nComp;
    out.targetVariance = targetVariance;
    out.valueRec       = valueRec;
    out.valueFlat      = valueFlat;
    out.valueRecFlat   = valueRecFlat;

    fprintf('PCA finished: keeping %d components (%.2f%% cumulative variance explained).\n', ...
        nComp, cumExplained(nComp));
end