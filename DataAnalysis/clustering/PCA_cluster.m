function result = PCA_cluster(DATA_in, varargin)
%PCA_CLUSTER Perform PCA and k-means clustering for every value in KList.
%
% Syntax
%   result = PCA_cluster(DATA_in)
%   result = PCA_cluster(DATA_in, Name, Value, ...)
%
% Name-value options
%   'TargetVariance'  Cumulative PCA variance threshold. Default: 95.
%   'KList'           Cluster numbers to evaluate. Default: 2:15.
%   'Replicates'      Number of k-means replicates. Default: 10.
%   'MaxIter'         Maximum k-means iterations. Default: 1000.
%   'RandomSeed'      Random seed. Default: 0.
%   'Reconstruct'     Reconstruct the PCA-reduced 4D data. Default: false.
%
% Output
%   result.pca
%       PCA results.
%
%   result.elbow
%       KList, within-cluster sums of squares, and estimated elbow.
%
%   result.clustering
%       Structure array containing one clustering result for every element
%       of KList.
%
% Example
%   result = PCA_cluster(DATA_in, ...
%       'TargetVariance', 95, ...
%       'KList', 2:15);

    %% Options

    parser = inputParser;

    addParameter(parser, 'TargetVariance', 95);
    addParameter(parser, 'KList', 2:15);
    addParameter(parser, 'Replicates', 10);
    addParameter(parser, 'MaxIter', 1000);
    addParameter(parser, 'RandomSeed', 0);
    addParameter(parser, 'Reconstruct', false);

    parse(parser, varargin{:});
    options = parser.Results;

    targetVariance = options.TargetVariance;

    if targetVariance <= 1
        targetVariance = 100 * targetVariance;
    end

    %% PCA

    [Nx, Ny, Ns1, Ns2] = size(DATA_in.value);

    pcaResult = pca_reduce_4d( ...
        DATA_in.value, targetVariance, options.Reconstruct);

    featuresValid = pcaResult.scoreValid;
    validMaskFlat = pcaResult.validMask;
    nValidPixels = size(featuresValid, 1);

    %% Prepare cluster numbers

    kList = unique(options.KList(:).', 'stable');
    kList = kList(kList >= 2 & kList <= nValidPixels);

    if isempty(kList)
        error('KList does not contain any valid cluster numbers.');
    end

    %% Run k-means for every value in KList

    rngState = rng;
    rngCleanup = onCleanup(@() rng(rngState)); %#ok<NASGU>

    rng(options.RandomSeed, 'twister');

    nK = numel(kList);
    wcss = zeros(1, nK);

    clustering = repmat(struct( ...
        'nClusters', [], ...
        'map', [], ...
        'labelsValid', [], ...
        'centroids', [], ...
        'withinClusterSum', [], ...
        'totalWCSS', []), 1, nK);

    for i = 1:nK
        k = kList(i);

        [idxValid, centroids, sumd] = kmeans( ...
            featuresValid, k, ...
            'Distance', 'sqeuclidean', ...
            'Start', 'plus', ...
            'Replicates', options.Replicates, ...
            'MaxIter', options.MaxIter, ...
            'EmptyAction', 'singleton', ...
            'Display', 'off');

        % Sort cluster labels by the PC1 centroid coordinate.
        [~, clusterOrder] = sort(centroids(:, 1));

        labelMap = zeros(k, 1);
        labelMap(clusterOrder) = 1:k;

        idxValid = labelMap(idxValid);
        centroids = centroids(clusterOrder, :);
        sumd = sumd(clusterOrder);

        labelsFlat = nan(Nx * Ny, 1);
        labelsFlat(validMaskFlat) = idxValid;

        clustering(i).nClusters = k;
        clustering(i).map = reshape(labelsFlat, Nx, Ny);
        clustering(i).labelsValid = idxValid;
        clustering(i).centroids = centroids;
        clustering(i).withinClusterSum = sumd;
        clustering(i).totalWCSS = sum(sumd);

        wcss(i) = clustering(i).totalWCSS;
    end

    %% Elbow estimate

    suggestedK = estimate_elbow(kList, wcss);

    %% Assemble output

    validPixelMask = reshape(validMaskFlat, Nx, Ny);
    pcaResult = rmfield(pcaResult, {'scoreValid', 'validMask'});

    result.inputSize = [Nx, Ny, Ns1, Ns2];
    result.validPixelMask = validPixelMask;
    result.pca = pcaResult;

    result.elbow.kList = kList;
    result.elbow.wcss = wcss;
    result.elbow.suggestedK = suggestedK;

    result.clustering = clustering;

    options.TargetVariance = targetVariance;
    options.KList = kList;
    result.options = options;

    fprintf( ...
        'PCA retained %d components and explained %.2f%% of the variance.\n', ...
        result.pca.nComp, result.pca.cumulativeExplained(end));

    fprintf( ...
        'K-means completed for k = %s.\n', ...
        mat2str(kList));

    if isfinite(suggestedK)
        fprintf('Estimated elbow: k = %d.\n', suggestedK);
    end
end


function out = pca_reduce_4d(value, targetVariance, reconstructData)
%PCA_REDUCE_4D Perform PCA on a 4D spatial-spectral array.

    [Nx, Ny, Ns1, Ns2] = size(value);

    nPixels = Nx * Ny;
    nFeatures = Ns1 * Ns2;

    valueFlat = reshape(double(value), nPixels, nFeatures);

    validMask = all(isfinite(valueFlat), 2);
    valueValid = valueFlat(validMask, :);

    [coeffAll, scoreAll, latentAll, ~, explainedAll, meanSpectrumFlat] = ...
        pca(valueValid, 'Algorithm', 'svd', 'Economy', true);

    cumulativeExplainedAll = cumsum(explainedAll);

    nComp = find( ...
        cumulativeExplainedAll >= targetVariance, 1, 'first');

    if isempty(nComp)
        nComp = size(scoreAll, 2);
    end

    coeff = coeffAll(:, 1:nComp);
    scoreValid = scoreAll(:, 1:nComp);

    scoreFlat = nan(nPixels, nComp);
    scoreFlat(validMask, :) = scoreValid;

    scoreMap = reshape(scoreFlat, Nx, Ny, nComp);

    if reconstructData
        reconstructedValid = scoreValid * coeff.' + meanSpectrumFlat;

        reconstructedFlat = nan(nPixels, nFeatures);
        reconstructedFlat(validMask, :) = reconstructedValid;

        valueRec = reshape( ...
            reconstructedFlat, Nx, Ny, Ns1, Ns2);
    else
        valueRec = [];
    end

    out.scoreMap = scoreMap;
    out.scoreValid = scoreValid;
    out.coeff = coeff;

    out.meanSpectrumFlat = meanSpectrumFlat;
    out.meanSpectrum = reshape(meanSpectrumFlat, Ns1, Ns2);

    out.latent = latentAll(1:nComp);
    out.explained = explainedAll(1:nComp);
    out.cumulativeExplained = cumulativeExplainedAll(1:nComp);

    out.latentAll = latentAll;
    out.explainedAll = explainedAll;
    out.cumulativeExplainedAll = cumulativeExplainedAll;

    out.nComp = nComp;
    out.targetVariance = targetVariance;
    out.valueRec = valueRec;

    out.validMask = validMask;
    out.nValidPixels = sum(validMask);
    out.nInvalidPixels = nPixels - sum(validMask);
end


function suggestedK = estimate_elbow(kList, wcss)
%ESTIMATE_ELBOW Estimate the elbow from the endpoint-connecting line.

    suggestedK = NaN;

    if numel(kList) < 3
        return
    end

    x = (kList(:) - min(kList)) / range(kList);
    y = (wcss(:) - min(wcss)) / range(wcss);

    firstPoint = [x(1), y(1)];
    lastPoint = [x(end), y(end)];
    lineVector = lastPoint - firstPoint;

    distances = abs( ...
        lineVector(1) .* (firstPoint(2) - y) - ...
        lineVector(2) .* (firstPoint(1) - x)) / norm(lineVector);

    distances([1 end]) = -Inf;

    [~, elbowIndex] = max(distances);
    suggestedK = kList(elbowIndex);
end
