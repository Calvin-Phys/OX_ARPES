function result = ox_data_process_agent(action, request)
%OX_DATA_PROCESS_AGENT Public facade for the entire Data Process panel.
%   RESULT = OX_DATA_PROCESS_AGENT(ACTION,REQUEST) accepts a scalar struct.
%   Unknown fields are rejected. No pixel automation or callback internals
%   are needed. Read/list never create a window or reset control values.
%
%   open/read/refresh/resetcrop: optional App handle to choose a live panel.
%   list: no fields; returns compatible base-workspace names/classes/shapes.
%   select: SourceName, optional App. Validates one existing OX 2-D/3-D input.
%   preview: optional SourceName, App. Opens one new independent preview.
%   process: Operation, optional Parameters (backend defaults), SourceName
%       (else current selection), OutputNames, Overwrite=false, App.
%       Explicit SourceName can run without opening a panel. A live panel is
%       refreshed afterward while retaining selection. Output report is the
%       same as ox_data_process_workspace. No numerical formulas are copied.
%
%   open raises one existing panel, or creates one. Other GUI actions require
%   a live panel. Multiple panels require explicit App. state.Parameters
%   returned by read can be passed to process to use current GUI settings.
    if nargin < 2, request = struct(); end
    action = validatestring(action,{'open','read','list','refresh','select','resetcrop','preview','process'});
    if strcmp(action,'list')
        mergeRequest(struct(),request);
        result = workspaceList();
        return
    end
    if strcmp(action,'process')
        options = mergeRequest(struct('App',[],'Operation','','Parameters',struct(), ...
            'SourceName','','OutputNames',{{}},'Overwrite',false),request);
        app = resolveApp(options.App,false);
        source = options.SourceName;
        if isempty(source) || (isstring(source) && isscalar(source) && strlength(source) == 0)
            if isempty(app)
                error('OxArpes:ProcessSelection','Supply SourceName or open and select a dataset first.');
            end
            state = app.readState();
            source = state.Selected;
        end
        result = ox_data_process_workspace(source,options.Operation,options.Parameters,options.OutputNames,options.Overwrite);
        if ~isempty(app), app.refreshData(); end
        return
    end
    if ismember(action,{'select','preview'})
        options = mergeRequest(struct('App',[],'SourceName',''),request);
    else
        options = mergeRequest(struct('App',[]),request);
    end
    app = resolveApp(options.App,strcmp(action,'open'));
    if isempty(app)
        error('OxArpes:ProcessApp','Open the panel with ox_data_process_agent(''open'') first.');
    end
    switch action
        case 'open'
            figure(app.UIFigure);
        case 'select'
            app.selectData(options.SourceName);
        case 'refresh'
            app.refreshData();
        case 'resetcrop'
            app.resetCrop();
        case 'preview'
            if strlength(string(options.SourceName)) > 0, app.selectData(options.SourceName); end
            result = app.preview();
            return
    end
    result = app.readState();
end

function app = resolveApp(explicit, create)
    if ~isempty(explicit)
        if ~isa(explicit,'OxArpes_DataProcess') || ~isscalar(explicit) || ...
                ~isvalid(explicit) || ~isvalid(explicit.UIFigure)
            error('OxArpes:ProcessApp','App must be one live OxArpes_DataProcess handle.');
        end
        app = explicit;
        return
    end
    figures = findall(groot,'Type','figure');
    matches = {};
    for k = 1:numel(figures)
        if isappdata(figures(k),'OxArpesDataProcessApp')
            candidate = getappdata(figures(k),'OxArpesDataProcessApp');
            if isa(candidate,'OxArpes_DataProcess') && isvalid(candidate)
                matches{end+1} = candidate; %#ok<AGROW>
            end
        end
    end
    if numel(matches) > 1
        error('OxArpes:ProcessApp','Multiple Data Process panels are open. Supply an explicit App handle.');
    elseif isscalar(matches)
        app = matches{1};
    elseif create
        app = OxArpes_DataProcess;
    else
        app = [];
    end
end

function options = mergeRequest(defaults, supplied)
    if ~isstruct(supplied) || ~isscalar(supplied)
        error('OxArpes:ProcessOptions','Request must be a scalar struct.');
    end
    names = fieldnames(supplied);
    unknown = setdiff(names,fieldnames(defaults));
    if ~isempty(unknown)
        error('OxArpes:ProcessOptions','Unknown request field: %s.',unknown{1});
    end
    options = defaults;
    for k = 1:numel(names), options.(names{k}) = supplied.(names{k}); end
end

function result = workspaceList()
    variables = evalin('base','whos');
    names = strings(0,1); classes = strings(0,1); shapes = strings(0,1);
    for k = 1:numel(variables)
        if ~isequal(variables(k).size,[1 1]), continue; end
        candidate = evalin('base',variables(k).name);
        if isa(candidate,'OxArpes_2D_Data') || isa(candidate,'OxArpes_3D_Data')
            names(end+1,1) = string(variables(k).name); %#ok<AGROW>
            classes(end+1,1) = string(variables(k).class); %#ok<AGROW>
            sampleCounts = [numel(candidate.x) numel(candidate.y)];
            if isa(candidate,'OxArpes_3D_Data'), sampleCounts(3) = numel(candidate.z); end
            shapes(end+1,1) = strjoin(string(sampleCounts),' x '); %#ok<AGROW>
        end
    end
    result = sortrows(table(names,classes,shapes,'VariableNames',{'Name','Class','Size'}),'Name');
end
