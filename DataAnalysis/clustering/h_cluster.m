function result = h_cluster(DATA_in, k, maxK, showPlots)
%H_CLUSTER Hierarchical clustering of a 4-D spatial--spectral dataset.
%
%   RESULT = H_CLUSTER(DATA_IN) clusters spectra stored as
%   DATA_IN.value(Nx,Ny,Nu,Nv), estimates an elbow over up to 20 clusters,
%   and returns labels mapped onto the real-space x/y grid.
%
%   RESULT = H_CLUSTER(DATA_IN,K,MAXK,SHOWPLOTS) selects the displayed/final
%   cluster count, elbow search limit, and optional diagnostic plotting.

    if nargin < 2, k = []; end
    if nargin < 3 || isempty(maxK), maxK = 20; end
    if nargin < 4 || isempty(showPlots), showPlots = false; end

    validateattributes(DATA_in.value, {'numeric','logical'}, {'nonempty'});
    if ndims(DATA_in.value) < 3 || ndims(DATA_in.value) > 4
        error('OxArpes:InvalidDimension', ...
            'Hierarchical clustering expects value(Nx,Ny,Nu,Nv).');
    end
    validateattributes(maxK, {'numeric'}, {'scalar','integer','>=',2});
    validateattributes(showPlots, {'logical','numeric'}, {'scalar'});

    [Nx, Ny, Nu, Nv] = size(DATA_in.value);
    X = reshape(double(DATA_in.value), Nx*Ny, Nu*Nv);

    goodSite = all(isfinite(X),2) & std(X,0,2) > 0;
    Xvalid = X(goodSite,:);
    goodFeature = std(Xvalid,0,1) > 0;
    Xvalid = Xvalid(:,goodFeature);

    if ~any(goodFeature)
        error('OxArpes:ConstantData', ...
            'No finite, nonconstant spectral features remain.');
    end
    if size(Xvalid,1) < 2
        error('OxArpes:InsufficientSites', ...
            'Hierarchical clustering requires at least two valid sites.');
    end

    distances = pdist(Xvalid, 'correlation');
    linkageTree = linkage(distances, 'average');

    maxK = min(maxK,size(Xvalid,1));
    kList = 2:maxK;
    wcss = zeros(size(kList));
    for iK = 1:numel(kList)
        labels = cluster(linkageTree,'maxclust',kList(iK));
        for iCluster = 1:kList(iK)
            points = Xvalid(labels == iCluster,:);
            if ~isempty(points)
                centroid = mean(points,1);
                wcss(iK) = wcss(iK) + sum((points-centroid).^2,'all');
            end
        end
    end

    suggestedK = estimate_elbow(kList,wcss);
    if isempty(k)
        if isfinite(suggestedK)
            k = suggestedK;
        else
            k = min(2,maxK);
        end
    end
    validateattributes(k, {'numeric'}, ...
        {'scalar','integer','>=',2,'<=',size(Xvalid,1)});

    labelsValid = cluster(linkageTree,'maxclust',k);
    labelsFlat = nan(Nx*Ny,1);
    labelsFlat(goodSite) = labelsValid;

    result.labels = reshape(labelsFlat,Nx,Ny);
    result.labelsValid = labelsValid;
    result.validSiteMask = reshape(goodSite,Nx,Ny);
    result.goodFeature = goodFeature;
    result.linkage = linkageTree;
    result.distances = distances;
    result.k = k;
    result.elbow.kList = kList;
    result.elbow.wcss = wcss;
    result.elbow.suggestedK = suggestedK;

    if logical(showPlots)
        figure('Name','Hierarchical clustering dendrogram');
        dendrogram(linkageTree,0);
        xlabel('Real-space grid point');
        ylabel('Correlation distance');

        figure('Name','Hierarchical clustering elbow');
        plot(kList,wcss,'-o','LineWidth',1.5);
        xlabel('Number of clusters');
        ylabel('Within-cluster sum of squares');
        grid on;

        figure('Name','Hierarchical cluster map');
        imagesc(DATA_in.x,DATA_in.y,result.labels.');
        set(gca,'YDir','normal');
        axis image;
        colorbar;
        xlabel(DATA_in.x_name);
        ylabel(DATA_in.y_name);
    end
end

function suggestedK = estimate_elbow(kList,wcss)
    suggestedK = NaN;
    if numel(kList) < 3 || range(kList) == 0 || range(wcss) == 0
        return
    end

    x = (kList(:)-min(kList))/range(kList);
    y = (wcss(:)-min(wcss))/range(wcss);
    firstPoint = [x(1),y(1)];
    lineVector = [x(end),y(end)]-firstPoint;
    if norm(lineVector) == 0
        return
    end

    distances = abs(lineVector(1)*(firstPoint(2)-y) - ...
        lineVector(2)*(firstPoint(1)-x))/norm(lineVector);
    distances([1 end]) = -Inf;
    [~,index] = max(distances);
    suggestedK = kList(index);
end
