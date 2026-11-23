function [loaded, reports] = loader_UI(varargin)
%LOADER_UI Load ARPES files from a picker or from a script.
%   LOADER_UI() opens the file picker, shows a waitbar, and assigns loaded
%   results to the base workspace for interactive compatibility.
%
%   DATA = LOADER_UI(PATHS) loads one path or a cell/string array of paths.
%   Script calls return data and do not show a waitbar or assign to the base
%   workspace by default.
%
%   Name-value options:
%     'Progress'      'none' (default for scripts), 'text', or 'waitbar'
%     'AssignToBase'  true/false (defaults to true only for picker use)
%     'Format'        Loader name or 'auto', passed to load_arpes
%     'Validate'      Validate returned OX data objects (default true)
%     'Entry'         NXmpes entry name or absolute path (default all)
%     'DataGroup'     Absolute NXdata path inside the selected NXmpes entry
%
%   For multiple files, LOADED and REPORTS are cell arrays in input order.
%   MAT files are returned as structures; when AssignToBase is true, each
%   variable in the MAT file is assigned individually.

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
    addParameter(parser, 'AssignToBase', guiStart, ...
        @(value) islogical(value) && isscalar(value));
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

        if parser.Results.AssignToBase && ~isempty(data)
            if strcmpi(extension, '.mat') && isstruct(data)
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
