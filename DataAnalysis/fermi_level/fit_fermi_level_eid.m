function [results, figureHandle] = fit_fermi_level_eid(data, varargin)
%FIT_FERMI_LEVEL_EID Fit Fermi edges in EID quantile profiles.
%
%   RESULTS = FIT_FERMI_LEVEL_EID(EID) fits every quantile stored in
%   EID.info.eid_bkgd.  Name-value options are Temperature, Resolution,
%   FitWindow, FitResolution, QuantileIndex, and Plot.

    if ~isobject(data) || ~isprop(data,'info') || ~isfield(data.info,'eid_q') || ...
            ~isfield(data.info,'eid_bkgd')
        error('OxArpes:InvalidEID', ...
            'Input data must contain info.eid_q and info.eid_bkgd.');
    end

    parser = inputParser;
    defaultTemperature = [];
    if isfield(data.info,'temperature')
        defaultTemperature = data.info.temperature;
    end
    addParameter(parser,'Temperature',defaultTemperature);
    addParameter(parser,'Resolution',0.05);
    addParameter(parser,'FitWindow',0.2);
    addParameter(parser,'FitResolution',false);
    addParameter(parser,'QuantileIndex',1:numel(data.info.eid_q));
    addParameter(parser,'Plot',false);
    parse(parser,varargin{:});
    opt = parser.Results;

    if isempty(opt.Temperature)
        error('OxArpes:MissingTemperature', ...
            'Temperature is required for EID Fermi-edge fitting.');
    end

    qIndex = unique(opt.QuantileIndex(:).','stable');
    qIndex = qIndex(qIndex >= 1 & qIndex <= numel(data.info.eid_q));
    if isempty(qIndex)
        error('OxArpes:InvalidQuantileIndex', 'No valid quantile indices were selected.');
    end

    template = fit_fermi_edge_ox([],[]);
    results = repmat(template,1,numel(qIndex));
    for iResult = 1:numel(qIndex)
        iQ = qIndex(iResult);
        results(iResult) = fit_fermi_edge_ox(data.y,data.info.eid_bkgd(:,iQ), ...
            'Temperature',opt.Temperature, ...
            'Resolution',opt.Resolution, ...
            'FitWindow',opt.FitWindow, ...
            'FixTemperature',true, ...
            'FixResolution',~logical(opt.FitResolution), ...
            'Debug',false);
    end

    figureHandle = gobjects(0);
    if logical(opt.Plot)
        figureHandle = figure('Name','EID Fermi-level fits');
        axesHandle = axes(figureHandle);
        imagesc(axesHandle,data.x,data.y,data.value.');
        set(axesHandle,'YDir','normal');
        hold(axesHandle,'on');
        for iResult = 1:numel(qIndex)
            iQ = qIndex(iResult);
            plot(axesHandle,data.info.eid_bkgd(:,iQ),data.y);
            if results(iResult).isValid
                intensityAtEF = interp1(data.y,data.info.eid_bkgd(:,iQ), ...
                    results(iResult).EF,'linear');
                scatter(axesHandle,intensityAtEF,results(iResult).EF,'filled');
            end
        end
        hold(axesHandle,'off');
    end
end
