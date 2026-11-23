function [data, report] = load_arpes(filePath, varargin)
%LOAD_ARPES Load one ARPES file without UI or base-workspace side effects.
%   DATA = LOAD_ARPES(FILEPATH) selects a reader from the extension and file
%   schema. [DATA,REPORT] also returns the chosen reader and elapsed time.
%
%   DATA = LOAD_ARPES(FILEPATH,'Format',LOADER) selects an approved reader
%   explicitly. Unsupported but readable scan types return [] with a warning;
%   file, schema, and reader failures raise an error with their cause attached.
%   NXmpes accepts 'Entry' and 'DataGroup' selectors. REPORT.validated checks
%   OX data contracts; REPORT.nexus.validation describes NXDL validation.

    parser = inputParser;
    addRequired(parser, 'filePath', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'Format', 'auto', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'Validate', true, @(x) islogical(x) && isscalar(x));
    addParameter(parser, 'Entry', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser, 'DataGroup', '', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    parse(parser, filePath, varargin{:});

    filePath = char(parser.Results.filePath);
    requestedFormat = char(parser.Results.Format);
    if ~isfile(filePath)
        error('OxArpes:FileNotFound', 'File not found: %s', filePath);
    end

    [~,~,ext] = fileparts(filePath);
    ext = lower(ext);
    report = struct('source', filePath, 'extension', ext, ...
        'loader', '', 'warnings', {{}}, 'elapsed_seconds', NaN, ...
        'validated', false);
    startTime = tic;

    if strcmpi(requestedFormat, 'auto')
        [loaderName, candidates] = detect_loader(filePath, ext);
    else
        supportedLoaders = {'load_mat_file','load_scienta_txt', ...
            'load_Soleil_Cassiopee','load_Soleil_Cassiopee_folder', ...
            'load_scienta_zip','load_solaris_spin_zip', ...
            'load_Elettra_Spectromicroscopy','load_SSRL_BL52', ...
            'load_PSI_ULTRA','load_PSI_ADRESS','load_ALS_h5','load_ALBA_LOREA', ...
            'load_DLS_io5_nano','load_DLS_io5_HR','load_DLS_io9_kPEEM', ...
            'load_DLS_io9_HAXPES','load_scienta_IBW','load_Specs_itx', ...
            'load_ALS_Maestro_fits','load_ALBA_krx','load_ALBA_krx_S','load_nxmpes'};
        match = find(strcmpi(requestedFormat,supportedLoaders),1);
        if isempty(match)
            error('OxArpes:UnknownLoader', ...
                'Unknown or disallowed loader "%s".', requestedFormat);
        end
        loaderName = supportedLoaders{match};
        candidates = {loaderName};
    end

    try
        if strcmp(loaderName, 'load_nxmpes')
            [data, report.nexus] = load_nxmpes(filePath, ...
                'Entry', parser.Results.Entry, 'DataGroup', parser.Results.DataGroup);
            report.warnings = report.nexus.warnings;
        elseif ~isempty(parser.Results.Entry) || ~isempty(parser.Results.DataGroup)
            error('OxArpes:InvalidLoaderOptions','Entry and DataGroup apply only to load_nxmpes.');
        elseif strcmp(loaderName, 'load_mat_file')
            data = load(filePath);
        elseif numel(candidates) == 1
            data = feval(loaderName, filePath);
        else
            % KRX is retained as the one legacy ambiguous family until a
            % representative spin/non-spin fixture is available for probing.
            [data, loaderName] = try_krx_loaders(filePath, candidates);
        end
    catch cause
        failure = MException('OxArpes:LoadFailed', ...
            'Failed to load "%s" using %s.', filePath, strjoin(candidates, ', '));
        failure = addCause(failure, cause);
        throwAsCaller(failure);
    end

    report.loader = loaderName;
    report.elapsed_seconds = toc(startTime);
    if isempty(data) || (isstruct(data) && isempty(fieldnames(data)))
        message = sprintf('No supported data were found in "%s" using %s.', ...
            filePath, loaderName);
        report.warnings = {message};
        return
    end

    if ~ismember(loaderName, {'load_mat_file','load_nxmpes'})
        % NeXus exchange restores the stored metadata exactly, including
        % legacy aliases; facility readers retain boundary normalization.
        data = normalise_loaded_metadata(data);
    end

    if parser.Results.Validate && ~strcmp(loaderName, 'load_mat_file')
        validate_loaded_data(data);
        report.validated = true;
    end
end

function data = normalise_loaded_metadata(data)
%NORMALISE_LOADED_METADATA Add canonical names for known legacy metadata aliases.
    if isobject(data) && isprop(data, 'info')
        if isempty(data.info)
            data.info = struct();
        end
        if isfield(data.info, 'lens_mod') && ~isfield(data.info, 'lens_mode')
            data.info.lens_mode = data.info.lens_mod;
        elseif isfield(data.info, 'len_mode') && ~isfield(data.info, 'lens_mode')
            data.info.lens_mode = data.info.len_mode;
        end
        if isfield(data.info, 'acquisition_mod') && ~isfield(data.info, 'acquisition_mode')
            data.info.acquisition_mode = data.info.acquisition_mod;
        end
        return
    end

    if isstruct(data)
        fields = fieldnames(data);
        for iField = 1:numel(fields)
            if isobject(data.(fields{iField}))
                data.(fields{iField}) = normalise_loaded_metadata(data.(fields{iField}));
            end
        end
    end
end

function [loaderName, candidates] = detect_loader(filePath, ext)
%DETECT_LOADER Select a reader using the file extension and format markers.
    candidates = {};
    if ismember(ext,{'.nxs','.nx5','.nexus','.h5','.hdf5','.hdf'}) && ...
            ~isempty(nxmpes_io('entries',filePath))
        loaderName = 'load_nxmpes';
        candidates = {loaderName};
        return
    end
    switch ext
        case '.mat'
            loaderName = 'load_mat_file';
        case '.txt'
            if endsWith(filePath, '_ROI1_.txt', 'IgnoreCase', true)
                loaderName = 'load_Soleil_Cassiopee';
            elseif endsWith(filePath, '_i.txt', 'IgnoreCase', true)
                loaderName = 'load_Soleil_Cassiopee_folder';
            else
                loaderName = 'load_scienta_txt';
            end
        case '.zip'
            loaderName = probe_zip_loader(filePath);
        case '.hdf5'
            loaderName = 'load_Elettra_Spectromicroscopy';
        case '.h5'
            if has_h5_path(filePath, '/Electron Analyzer/Image Data')
                loaderName = 'load_PSI_ULTRA';
            elseif has_igor_wave_schema(filePath)
                loaderName = 'load_PSI_ADRESS';
            elseif has_h5_path(filePath, '/UserSettings')
                loaderName = 'load_SSRL_BL52';
            elseif has_h5_path(filePath, '/2D_Data/Swept_Spectra15')
                loaderName = 'load_ALS_h5';
            else
                error('OxArpes:UnknownH5Schema', ...
                    'The HDF5 file does not match a supported .h5 schema.');
            end
        case '.nxs'
            if has_h5_path(filePath, '/entry1/data/data')
                loaderName = 'load_ALBA_LOREA';
            elseif has_h5_path(filePath, '/entry1/analyser/smx') || ...
                    has_h5_path(filePath, '/entry1/analyser/smy')
                loaderName = 'load_DLS_io5_nano';
            elseif has_h5_path(filePath, '/entry1/before_scan')
                loaderName = 'load_DLS_io9_kPEEM';
            elseif has_h5_path(filePath, '/entry1/analyser/data')
                loaderName = 'load_DLS_io5_HR';
            elseif has_h5_path(filePath, '/entry/scan_command')
                loaderName = 'load_DLS_io9_HAXPES';
            else
                error('OxArpes:UnknownNexusSchema', ...
                    'The Nexus file does not match a supported beamline schema.');
            end
        case '.ibw'
            loaderName = 'load_scienta_IBW';
        case '.itx'
            loaderName = 'load_Specs_itx';
        case '.fits'
            loaderName = 'load_ALS_Maestro_fits';
        case '.krx'
            candidates = {'load_ALBA_krx','load_ALBA_krx_S'};
            loaderName = candidates{1};
        otherwise
            error('OxArpes:UnsupportedExtension', ...
                'Unsupported file extension "%s".', ext);
    end

    if isempty(candidates)
        candidates = {loaderName};
    end
end

function tf = has_igor_wave_schema(filePath)
%HAS_IGOR_WAVE_SCHEMA Identify ADRESS Igor HDF5 waves by dataset attributes.
    tf = false;
    if ~has_h5_path(filePath, '/Matrix')
        return
    end
    matrixInfo = h5info(filePath, '/Matrix');
    attributeNames = {matrixInfo.Attributes.Name};
    requiredAttributes = {'IGORWaveScaling','IGORWaveNote','IGORWaveUnits'};
    tf = all(ismember(requiredAttributes, attributeNames));
end

function loaderName = probe_zip_loader(filePath)
%PROBE_ZIP_LOADER Select a ZIP reader from viewer.ini format markers.
%   Extraction errors propagate as file errors; no alternate reader is tried
%   unless the archive has a recognized spin-channel configuration.
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@() remove_probe_folder(folder)); %#ok<NASGU>
    unzip(filePath, folder);

    viewerPath = fullfile(folder, 'viewer.ini');
    if ~isfile(viewerPath)
        error('OxArpes:UnknownZipSchema', ...
            'The archive has no root viewer.ini file.');
    end
    text = fileread(viewerPath);

    hasSpinMarkers = ~isempty(regexpi(text, ...
        'current_region\s*=.*[\r\n]+[\s\S]*channel_list\s*=', 'once'));
    hasMapMarkers = ~isempty(regexpi(text, ...
        '(^|[\r\n])\s*width\s*=\s*\d+', 'once'));

    if hasSpinMarkers
        loaderName = 'load_solaris_spin_zip';
    elseif hasMapMarkers
        loaderName = 'load_scienta_zip';
    else
        error('OxArpes:UnknownZipSchema', ...
            'The viewer.ini file does not match a supported ZIP schema.');
    end
end

function remove_probe_folder(folder)
%REMOVE_PROBE_FOLDER Clean the temporary folder used for a ZIP schema probe.
    if isfolder(folder)
        rmdir(folder, 's');
    end
end

function tf = has_h5_path(filePath, objectPath)
%HAS_H5_PATH Check a dataset or group path without treating file errors as misses.
    fileInfo = h5info(filePath);
    target = normalize_h5_path(objectPath);
    tf = group_has_h5_path(fileInfo, target);
end

function tf = group_has_h5_path(groupInfo, target)
%GROUP_HAS_H5_PATH Search an HDF5 group tree for the requested full path.
    groupPath = normalize_h5_path(groupInfo.Name);
    if strcmp(groupPath, target)
        tf = true;
        return
    end

    tf = false;
    for iDataset = 1:numel(groupInfo.Datasets)
        datasetName = groupInfo.Datasets(iDataset).Name;
        if startsWith(datasetName, '/')
            datasetPath = normalize_h5_path(datasetName);
        elseif strcmp(groupPath, '/')
            datasetPath = normalize_h5_path(['/' datasetName]);
        else
            datasetPath = normalize_h5_path([groupPath '/' datasetName]);
        end
        if strcmp(datasetPath, target)
            tf = true;
            return
        end
    end

    for iGroup = 1:numel(groupInfo.Groups)
        if group_has_h5_path(groupInfo.Groups(iGroup), target)
            tf = true;
            return
        end
    end
end

function value = normalize_h5_path(value)
%NORMALIZE_H5_PATH Standardize separators and leading/trailing slashes.
    value = strrep(char(value), '\', '/');
    value = regexprep(value, '/+', '/');
    if isempty(value)
        value = '/';
    elseif value(1) ~= '/'
        value = ['/' value];
    end
    if numel(value) > 1 && value(end) == '/'
        value(end) = [];
    end
end

function [data, loaderName] = try_krx_loaders(filePath, candidates)
%TRY_KRX_LOADERS Retain the legacy two-reader attempt and keep both causes.
    causes = cell(1, numel(candidates));
    for iLoader = 1:numel(candidates)
        try
            data = feval(candidates{iLoader}, filePath);
            loaderName = candidates{iLoader};
            return
        catch cause
            causes{iLoader} = cause;
        end
    end

    failure = MException('OxArpes:NoMatchingKRXLoader', ...
        'Neither KRX reader accepted "%s".', filePath);
    for iLoader = 1:numel(causes)
        failure = addCause(failure, causes{iLoader});
    end
    throw(failure);
end

function validate_loaded_data(data)
%VALIDATE_LOADED_DATA Check returned OX objects and channel structures.
    if isobject(data)
        if ismethod(data, 'validate')
            data.validate();
        end
        return
    end

    % Solaris spin archives return a structure of channel objects.
    if isstruct(data)
        fields = fieldnames(data);
        for iField = 1:numel(fields)
            item = data.(fields{iField});
            if isobject(item) && ismethod(item, 'validate')
                item.validate();
            end
        end
        return
    end

    error('OxArpes:InvalidLoaderOutput', ...
        'A loader must return an OX data object or a structure of channel objects.');
end
