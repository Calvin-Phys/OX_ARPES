%% value is int32, size [Nx, Ny, Nu, Nv]
x = i05_178697_RD.x;
y = i05_178697_RD.y;
value = i05_178697_RD.value;

[Nx, Ny, Nu, Nv] = size(value);

% Convert once, before arithmetic
V = single(value);

% Optional: clear the original int32 array if memory is limited
% clear value

nSites  = Nx * Ny;
nPixels = Nu * Nv;

% Reshape into [real_space_point, image_pixel]
X = reshape(V, nSites, nPixels);

%% ------------------------------------------------------------
% 2. Remove bad pixels or bad real-space points if NaNs/Infs exist
% ------------------------------------------------------------

goodFeature = all(isfinite(X), 1);   % image pixels valid for all sites
X = X(:, goodFeature);

goodSite = all(isfinite(X), 2);      % real-space sites with valid data
Xvalid = X(goodSite, :);

% ------------------------------------------------------------
% 3. Normalise each local image
% ------------------------------------------------------------
% This makes the clustering compare image shape/pattern rather than
% absolute intensity.

% Xvalid = Xvalid - mean(Xvalid, 2);

% normFactor = vecnorm(Xvalid, 2, 2);
% normFactor(normFactor == 0) = 1;

% Xvalid = Xvalid ./ normFactor;

%% ------------------------------------------------------------
% 4. Compute pairwise distances between local images
% ------------------------------------------------------------
% Common choices:
%   'cosine'      : compares pattern direction, insensitive to scale
%   'correlation' : compares similarity after mean subtraction
%   'euclidean'   : sensitive to absolute differences

D = pdist(Xvalid, "correlation");

% ------------------------------------------------------------
% 5. Hierarchical clustering
% ------------------------------------------------------------
% Common linkage choices:
%   'average'  : robust general-purpose choice
%   'ward'     : compact clusters, usually with Euclidean distance
%   'complete' : stricter cluster separation

Z = linkage(D, 'average');

% Optional dendrogram
figure;
dendrogram(Z, 0);
xlabel('Real-space grid point');
ylabel('Distance');
title('Hierarchical clustering dendrogram');

% Step 3: Elbow Method for optimal k
maxK = 300; % Maximum number of clusters to test
WCSS = zeros(maxK,1); % Within-cluster sum of squares

for k = 1:maxK
    % Assign clusters
    clusterIdx = cluster(Z, 'maxclust', k);
    
    % Compute WCSS for this k
    wcss_k = 0;
    for c = 1:k
        points = X(clusterIdx == c, :);
        if ~isempty(points)
            centroid = mean(points, 1);
            wcss_k = wcss_k + sum(sum((points - centroid).^2));
        end
    end
    WCSS(k) = wcss_k;
end

% Step 4: Plot Elbow Curve
figure;
plot(1:maxK, WCSS, '-o', 'LineWidth', 2);
xlabel('Number of Clusters (k)');
ylabel('Within-Cluster Sum of Squares (WCSS)');
title('Elbow Method for Optimal k');
grid on;

% The "elbow" point is where WCSS reduction slows down significantly

%% ------------------------------------------------------------
% 6. Cut the dendrogram into k clusters
% ------------------------------------------------------------

k = 120;   % choose the number of clusters

idxValid = cluster(Z, 'maxclust', k);

% Put labels back into the full real-space grid
idx = nan(nSites, 1);
idx(goodSite) = idxValid;

labelMap = reshape(idx, Nx, Ny);

% ------------------------------------------------------------
% 7. Plot clusters in real space
% ------------------------------------------------------------

figure;
imagesc(x, y, labelMap.');
set(gca, 'YDir', 'normal');
axis image;
colorbar;
xlabel('x');
ylabel('y');
title('Hierarchical-clustering labels in real space');