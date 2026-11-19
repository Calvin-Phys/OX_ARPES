function report = ox_data_process_workspace(sourceName, action, options, outputNames, overwrite)
%OX_DATA_PROCESS_WORKSPACE Process a named base-workspace dataset safely.
%   REPORT = OX_DATA_PROCESS_WORKSPACE(NAME,ACTION,OPTIONS) calls the same
%   backend as the GUI and creates new workspace variables. Default suffixes
%   are retained; collisions append _2, _3, ... . The input is never replaced.
%   Optional OUTPUTNAMES is a name or cell array of names (two for derivative).
%   Explicit existing names are rejected unless OVERWRITE is true (default
%   false). All output names/conflicts are checked before any assignment.
%   REPORT contains SourceName, OutputNames, Outputs and Details. Does not
%   open an app, plot, reset controls, or alter any selected workspace input.
    if nargin < 3, options = struct(); end
    if nargin < 4, outputNames = {}; end
    if nargin < 5, overwrite = false; end
    sourceName = char(string(sourceName));
    if ~isvarname(sourceName)
        error('OxArpes:ProcessSelection','Source must be one valid workspace variable name.');
    end
    names = evalin('base','who');
    if ~ismember(sourceName,names)
        error('OxArpes:ProcessSelection','Workspace variable %s no longer exists. Refresh the list.',sourceName);
    end
    validateattributes(overwrite, {'logical','numeric'}, {'scalar','real','finite','binary'});
    data = evalin('base',sourceName); % identifier validated above
    [outputs, details] = ox_data_process(data,action,options);
    if isempty(outputNames)
        outputNames = repmat({''},1,numel(outputs));
        for iOutput = 1:numel(outputs)
            suffix = details.Suffixes{iOutput};
            stem = [sourceName(1:min(numel(sourceName),namelengthmax-numel(suffix))) suffix];
            candidate = stem;
            count = 2;
            while ismember(candidate,[names;outputNames(:)])
                ending = ['_' num2str(count)];
                candidate = [stem(1:min(numel(stem),namelengthmax-numel(ending))) ending];
                count = count + 1;
            end
            outputNames{iOutput} = candidate;
        end
    elseif ischar(outputNames) || isstring(outputNames)
        outputNames = cellstr(outputNames);
    end
    if ~(iscellstr(outputNames) || isstring(outputNames)) || numel(outputNames) ~= numel(outputs) || ...
            ~all(cellfun(@isvarname,outputNames)) || numel(unique(outputNames)) ~= numel(outputNames)
        error('OxArpes:ProcessOutput','Supply %d distinct valid output names.',numel(outputs));
    end
    if any(strcmp(sourceName,outputNames))
        error('OxArpes:ProcessOutput','The source variable cannot be an output.');
    end
    if ~overwrite && any(ismember(outputNames,names))
        error('OxArpes:ProcessOutput','An output already exists. Choose a new name or explicitly enable overwrite.');
    end
    for iOutput = 1:numel(outputs)
        assignin('base',outputNames{iOutput},outputs{iOutput});
    end
    report = struct('SourceName',sourceName,'OutputNames',{outputNames}, ...
        'Outputs',{outputs},'Details',details);
end
