function [figCluster, figPCA] = visualize_PCA_cluster( ...
    DATA_in, result, nCluster)
%VISUALIZE_PCA_CLUSTER Display a selected cluster map and PCA results.
%
% Syntax
%   [figCluster, figPCA] = visualize_PCA_cluster( ...
%       DATA_in, result, nCluster)
%
% Example
%   visualize_PCA_cluster(DATA_in, result, 4);

    nDisplayedPCs = min(4, result.pca.nComp);
    if nDisplayedPCs < 1
        error('OxArpes:NoPrincipalComponents', ...
            'The PCA result contains no principal components to display.');
    end

    clusterIndex = find( ...
        [result.clustering.nClusters] == nCluster, 1);

    if isempty(clusterIndex)
        error( ...
            'No clustering result is available for k = %d.', ...
            nCluster);
    end

    clusterResult = result.clustering(clusterIndex);

    xLabel = sprintf( ...
        '%s (%s)', DATA_in.x_name, DATA_in.x_unit);

    yLabel = sprintf( ...
        '%s (%s)', DATA_in.y_name, DATA_in.y_unit);

    %% Spatial cluster map

    figCluster = figure( ...
        'Name', 'Spatial cluster map', ...
        'Color', 'w', ...
        'Units', 'pixels', ...
        'Position', [100 100 500 400]);

    axCluster = axes(figCluster);
    clusterMap = clusterResult.map.';

    hImage = imagesc( ...
        axCluster, DATA_in.x, DATA_in.y, clusterMap);

    hImage.AlphaData = isfinite(clusterMap);

    set(axCluster, 'YDir', 'normal');
    axis(axCluster, 'image');

    xlabel(axCluster, xLabel);
    ylabel(axCluster, yLabel);

    title( ...
        axCluster, ...
        sprintf('Spatial cluster map, k = %d', nCluster));

    colormap(axCluster, turbo(nCluster));
    clim(axCluster, [0.5 nCluster + 0.5]);

    cbCluster = colorbar(axCluster);
    cbCluster.Ticks = 1:nCluster;
    cbCluster.Label.String = 'Cluster';

    box(axCluster, 'on');

    %% Elbow method and PCA maps

    figPCA = figure( ...
        'Name', 'PCA analysis', ...
        'Color', 'w', ...
        'Units', 'pixels', ...
        'Position', [600 100 700 400]);

    layout = tiledlayout( ...
        figPCA, 2, 3, ...
        'Padding', 'compact', ...
        'TileSpacing', 'compact');

    %% Elbow curve

    axElbow = nexttile(layout, [1 2]);

    plot( ...
        axElbow, ...
        result.elbow.kList, ...
        result.elbow.wcss, ...
        '-o', ...
        'LineWidth', 1.5, ...
        'MarkerSize', 5);

    hold(axElbow, 'on');

    xline( ...
        axElbow, nCluster, '--', ...
        sprintf('Displayed k = %d', nCluster), ...
        'LabelVerticalAlignment', 'bottom');

    suggestedK = result.elbow.suggestedK;

    if isfinite(suggestedK) && suggestedK ~= nCluster
        xline( ...
            axElbow, suggestedK, ':', ...
            sprintf('Estimated k = %d', suggestedK), ...
            'LabelVerticalAlignment', 'top');
    end

    hold(axElbow, 'off');

    xlabel(axElbow, 'Number of clusters, k');
    ylabel(axElbow, 'Within-cluster sum of squares');
    title(axElbow, 'Elbow method');

    xticks(axElbow, result.elbow.kList);
    grid(axElbow, 'on');
    box(axElbow, 'on');

    %% PCA score maps

    axPC = gobjects(nDisplayedPCs, 1);

    for iPC = 1:nDisplayedPCs
        axPC(iPC) = nexttile(layout);

        scoreMap = result.pca.scoreMap(:, :, iPC).';

        hImage = imagesc( ...
            axPC(iPC), DATA_in.x, DATA_in.y, scoreMap);

        hImage.AlphaData = isfinite(scoreMap);

        set(axPC(iPC), 'YDir', 'normal');
        axis(axPC(iPC), 'image');
        axis(axPC(iPC), 'off');

        title( ...
            axPC(iPC), ...
            sprintf( ...
                'PC%d score map (%.2f%%)', ...
                iPC, result.pca.explained(iPC)));

        colormap(axPC(iPC), parula(256));
    end

    sgtitle( ...
        layout, ...
        sprintf( ...
            'PCA analysis: %d components retained, %.2f%% variance explained', ...
            result.pca.nComp, ...
            result.pca.cumulativeExplained(end)));

    drawnow;

    for iPC = 1:nDisplayedPCs
        colorbar(axPC(iPC));
    end
end
