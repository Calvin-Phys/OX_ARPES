function [loaded, reports] = loader_UI(varargin)
%LOADER_UI Load ARPES files from a picker or from a script.
%   LOADER_UI() opens the file picker, shows a waitbar, and assigns loaded
%   results to the base workspace for interactive compatibility.
%
%   DATA = LOADER_UI(PATHS) loads one path or a cell/string array of paths.
%   Script calls do not show a waitbar. NeXus calls also assign each dataset
%   directly to the base workspace by default; other scripted formats return
%   data only. Use 'AssignToBase',false for a return-only NeXus call.
%
%   Name-value options:
%     'Progress'      'none' (default for scripts), 'text', or 'waitbar'
%     'AssignToBase'  true/false (default true for picker use or NeXus files)
%     'Format'        Loader name or 'auto', passed to load_arpes
%     'Validate'      Validate returned OX data objects (default true)
%     'Entry'         NXmpes entry name or absolute path (default all)
%     'DataGroup'     Absolute NXdata path inside the selected NXmpes entry
%
%   For multiple files, LOADED and REPORTS are cell arrays in input order.
%   MAT files are returned as structures; when AssignToBase is true, each
%   variable in the MAT file is assigned individually.
%   NeXus entries are always assigned individually when assignment is enabled.
%   Original dataset names are made valid and unique, preserving existing
%   workspace variables. For NeXus, REPORTS.workspace_variables lists names.

    guiStart = isempty(varargin);
    if guiStart
        persistent lastPath
        if isempty(lastPath)
            lastPath = pwd;
        end

        [selectedFiles, selectedPath] = uigetfile_with_lastpath(lastPath);
        if isequal(selectedFiles, 0) || isequal(selectedPath, 0)
            loaded = {};
            reports = {};
            return
        end
        lastPath = selectedPath;

        if iscell(selectedFiles)
            filePaths = cellfun(@(name) fullfile(selectedPath, name), ...
                selectedFiles, 'UniformOutput', false);
        else
            filePaths = {fullfile(selectedPath, selectedFiles)};
        end
        optionArgs = {};
    else
        filePaths = normalize_file_paths(varargin{1});
        optionArgs = varargin(2:end);
    end

    parser = inputParser;
    addParameter(parser, 'Progress', default_progress(guiStart), ...
        @(value) ischar(value) || (isstring(value) && isscalar(value)));
    addParameter(parser, 'AssignToBase', [], ...
        @(value) isempty(value) || (islogical(value) && isscalar(value)));
    addParameter(parser, 'Format', 'auto', ...
        @(value) ischar(value) || (isstring(value) && isscalar(value)));
    addParameter(parser, 'Validate', true, ...
        @(value) islogical(value) && isscalar(value));
    addParameter(parser, 'Entry', '', ...
        @(value) ischar(value) || (isstring(value) && isscalar(value)));
    addParameter(parser, 'DataGroup', '', ...
        @(value) ischar(value) || (isstring(value) && isscalar(value)));
    parse(parser, optionArgs{:});

    progressMode = lower(char(parser.Results.Progress));
    if ~ismember(progressMode, {'none','text','waitbar'})
        error('OxArpes:InvalidProgressMode', ...
            'Progress must be ''none'', ''text'', or ''waitbar''.');
    end
    if ~guiStart && strcmp(progressMode, 'waitbar')
        error('OxArpes:WaitbarRequiresGUI', ...
            'The waitbar is available only when loader_UI starts the file picker.');
    end

    numFiles = numel(filePaths);
    loadedItems = cell(1, numFiles);
    reports = cell(1, numFiles);
    waitbarHandle = [];

    if strcmp(progressMode, 'waitbar')
        waitbarHandle = waitbar(0, 'Preparing to load ARPES data...');
        waitbarHandle.Children.Title.Interpreter = 'none';
        waitbarCleanup = onCleanup(@() close_waitbar(waitbarHandle)); %#ok<NASGU>
    end

    for iFile = 1:numFiles
        filePath = filePaths{iFile};
        [~, baseName, extension] = fileparts(filePath);
        message = sprintf('Loading %s (%d/%d)', [baseName extension], iFile, numFiles);

        if strcmp(progressMode, 'waitbar') && isgraphics(waitbarHandle)
            waitbar(iFile / numFiles, waitbarHandle, message);
        elseif strcmp(progressMode, 'text')
            fprintf('%s\n', message);
        end

        [data, reports{iFile}] = load_arpes(filePath, ...
            'Format', parser.Results.Format, 'Validate', parser.Results.Validate, ...
            'Entry', parser.Results.Entry, 'DataGroup', parser.Results.DataGroup);
        loadedItems{iFile} = data;
        isNexus = ismember(lower(extension), {'.nxs','.nx5','.nexus'}) || ...
            strcmp(reports{iFile}.loader, 'load_nxmpes');
        assignToBase = parser.Results.AssignToBase;
        if isempty(assignToBase), assignToBase = guiStart || isNexus; end
        reports{iFile}.workspace_variables = {};

        if assignToBase && ~isempty(data)
            if isNexus
                reports{iFile}.workspace_variables = assign_nexus_datasets(data, baseName);
            elseif strcmpi(extension, '.mat') && isstruct(data)
                variableNames = fieldnames(data);
                for iName = 1:numel(variableNames)
                    assignin('base', variableNames{iName}, data.(variableNames{iName}));
                end
            else
                if isobject(data) && isprop(data, 'name')
                    data.name = matlab.lang.makeValidName(baseName);
                    loadedItems{iFile} = data;
                end
                assignin('base', matlab.lang.makeValidName(baseName), data);
            end
        end
    end

    if numFiles == 1
        loaded = loadedItems{1};
        reports = reports{1};
    else
        loaded = loadedItems;
    end
    if nargout == 0
        % Workspace-only calls should not also return a container as ANS.
        clear loaded
    end
end

function names = assign_nexus_datasets(data, fallbackName)
%ASSIGN_NEXUS_DATASETS Publish individual objects without a container variable.
    if isstruct(data)
        items = struct2cell(data);
        names = fieldnames(data);
    else
        items = {data};
        names = {fallbackName};
    end
    for i = 1:numel(items)
        item = items{i};
        if ~isobject(item) || ~isscalar(item) || ~isprop(item, 'value')
            error('OxArpes:InvalidLoaderOutput', ...
                'Each NeXus entry must contain a scalar OX data object.');
        end
        if isprop(item, 'name') && ...
                (ischar(item.name) || (isstring(item.name) && isscalar(item.name))) && ...
                ~ismissing(string(item.name)) && strlength(strtrim(string(item.name))) > 0
            names{i} = char(item.name);
        end
    end
    names = matlab.lang.makeValidName(names);
    names = matlab.lang.makeUniqueStrings(names, evalin('base', 'who'), namelengthmax);
    for i = 1:numel(items)
        assignin('base', names{i}, items{i});
    end
    names = names(:).';
end

function mode = default_progress(guiStart)
%DEFAULT_PROGRESS Select waitbar progress for picker use, none for scripts.
    if guiStart
        mode = 'waitbar';
    else
        mode = 'none';
    end
end

function filePaths = normalize_file_paths(inputPaths)
%NORMALIZE_FILE_PATHS Convert supported path inputs to a row cell array.
    if ischar(inputPaths) || (isstring(inputPaths) && isscalar(inputPaths))
        filePaths = {char(inputPaths)};
    elseif isstring(inputPaths)
        filePaths = cellstr(inputPaths(:)).';
    elseif iscell(inputPaths)
        filePaths = cell(1, numel(inputPaths));
        for iPath = 1:numel(inputPaths)
            item = inputPaths{iPath};
            if ~(ischar(item) || (isstring(item) && isscalar(item)))
                error('OxArpes:InvalidPathInput', ...
                    'Each path must be a character vector or scalar string.');
            end
            filePaths{iPath} = char(item);
        end
    else
        error('OxArpes:InvalidPathInput', ...
            'Paths must be a character vector, string array, or cell array of paths.');
    end

    if isempty(filePaths)
        error('OxArpes:EmptyPathList', 'At least one file path is required.');
    end
    for iPath = 1:numel(filePaths)
        if isempty(filePaths{iPath}) || ~isfile(filePaths{iPath})
            error('OxArpes:FileNotFound', 'File not found: %s', filePaths{iPath});
        end
    end
end

function [file, path] = uigetfile_with_lastpath(lastPath)
%UIGETFILE_WITH_LASTPATH Open the supported-format picker at a chosen folder.
    [file, path] = uigetfile({'*.*', 'All Files (*.*)'; ...
        '*.txt;*.zip', 'Scienta CUT/MAP (*.txt, *.zip)'; ...
        '*.hdf5', 'Elettra Spectromicroscopy (*.hdf5)'; ...
        '*.h5', 'SSRL; PSI ULTRA; PSI ADRESS; ALS (*.h5)'; ...
        '*.nxs;*.nx5;*.nexus', 'NXmpes; DLS i05/i09; ALBA LOREA (*.nxs, *.nx5, *.nexus)'; ...
        '*.ibw', 'Igor binary wave (*.ibw)'; ...
        '*.itx', 'SPECS Igor text (*.itx)'; ...
        '*.fits', 'ALS MAESTRO (*.fits)'; ...
        '*.krx', 'ALBA KRX (*.krx)'; ...
        '*.mat', 'MAT-files (*.mat)'}, ...
        'Select One or More Files', 'MultiSelect', 'on', lastPath);
end

function close_waitbar(handle)
%CLOSE_WAITBAR Close a waitbar if it is still open.
    if ~isempty(handle) && isgraphics(handle)
        close(handle);
    end
end
