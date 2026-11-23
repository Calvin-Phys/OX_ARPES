function [data, report] = load_nxmpes(filePath, varargin)
%LOAD_NXMPES Read rectilinear 1D--4D NXmpes/NXmpes_arpes data into OX objects.
%   DATA = LOAD_NXMPES(FILE) returns a scalar object for one NXentry, or a
%   structure keyed by entry name for multiple entries. Options: Entry
%   (absolute path or name), DataGroup (absolute NXdata path). Recognizes
%   ARPES Explorer exports even when they omit the definition field.
%   Native axis values, units, sign and counts are retained; no calibration
%   or interpolation is inferred. Unsupported/missing coordinates error.
%   External metadata and coordinate semantics are recorded in info.nexus.
%   REPORT.validation = 'not_run' refers to full NXDL validation.

    parser = inputParser;
    addRequired(parser,'filePath',@(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser,'Entry','',@(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser,'DataGroup','',@(x) ischar(x) || (isstring(x) && isscalar(x)));
    parse(parser,filePath,varargin{:});
    filePath = char(filePath);
    if ~isfile(filePath), error('OxArpes:FileNotFound','File not found: %s',filePath); end
    entries = nxmpes_io('entries',filePath);
    requested = char(parser.Results.Entry);
    if ~isempty(requested)
        if requested(1) ~= '/', requested = ['/' requested]; end
        if ~ismember(requested,entries)
            error('OxArpes:NexusEntryNotFound','No supported NXmpes entry at %s.',requested);
        end
        entries = {requested};
    end
    if isempty(entries)
        error('OxArpes:UnknownNexusSchema','No NXmpes or ARPES Explorer entries found.');
    end
    if ~isscalar(entries) && ~isempty(parser.Results.DataGroup)
        error('OxArpes:AmbiguousNexusData','Select Entry when using DataGroup in a multi-entry file.');
    end
    report = struct('source',filePath,'validation','not_run','entries',struct([]),'warnings',{{}});
    loaded = cell(1,numel(entries));
    entryReports = cell(1,numel(entries));
    for i = 1:numel(entries)
        [loaded{i},entryReports{i}] = read_entry(filePath,entries{i},char(parser.Results.DataGroup));
        report.warnings = [report.warnings entryReports{i}.warnings];
    end
    report.entries = [entryReports{:}];
    if isscalar(entries)
        data = loaded{1};
    else
        keys = cellfun(@(x) x(2:end),entries,'UniformOutput',false);
        keys = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(keys));
        data = cell2struct(loaded,keys,2);
    end
end

function [data,report] = read_entry(file,entry,requestedGroup)
    group = select_data_group(file,entry,requestedGroup);
    signal = nxmpes_io('text',nxmpes_io('attribute',file,group,'signal','data'));
    signalPath = resolve_path(group,signal);
    shape = nxmpes_io('shape',file,signalPath);
    rank = numel(shape);
    if rank < 1 || rank > 4
        error('OxArpes:UnsupportedNexusDimension','Only rank 1--4 signals are supported.');
    end
    axesValue = nxmpes_io('attribute',file,group,'axes',{});
    if ischar(axesValue)
        % Older NeXus files sometimes use colon-separated axis names.
        axesNames = strsplit(strtrim(axesValue),':');
    else
        axesNames = cellstr(string(axesValue(:))).';
    end
    axesNames = cellfun(@(x) nxmpes_io('text',x),axesNames,'UniformOutput',false);
    if numel(axesNames) ~= rank || any(strcmp(axesNames,'.')) || ...
            numel(unique(axesNames)) ~= rank
        error('OxArpes:UnsupportedNexusAxes', ...
            'NXdata must declare one distinct coordinate vector for each signal dimension.');
    end
    axesValues = cell(1,rank);
    axisMetadata = cell(1,rank);
    for i = 1:rank
        index = nxmpes_io('attribute',file,group,[axesNames{i} '_indices'],i-1);
        if ~isnumeric(index) || ~isscalar(index) || index ~= i-1
            error('OxArpes:UnsupportedNexusAxes','Axis indices must agree with NXdata axes order.');
        end
        axisPath = resolve_path(group,axesNames{i});
        axis = nxmpes_io('read',file,axisPath);
        if ~isnumeric(axis) || ~isvector(axis) || numel(axis) ~= shape(i)
            error('OxArpes:UnsupportedNexusAxes', ...
                'Coordinate %s must be a numeric vector matching dimension %d (bin edges and meshes are unsupported).', ...
                axesNames{i},i);
        end
        axesValues{i} = axis(:).';
        axisMetadata{i} = struct('name',axesNames{i}, ...
            'label',nxmpes_io('text',nxmpes_io('attribute',file,axisPath,'long_name',axesNames{i})), ...
            'units',nxmpes_io('text',nxmpes_io('attribute',file,axisPath,'units','')), ...
            'type',nxmpes_io('text',nxmpes_io('attribute',file,axisPath,'type','')), ...
            'energy_convention',nxmpes_io('text',nxmpes_io('attribute',file,axisPath,'ox_energy_convention','')));
    end
    values = nxmpes_io('read',file,signalPath);
    if ~(isnumeric(values) || islogical(values)) || ~isreal(values)
        error('OxArpes:InvalidNexusSignal','NXdata signal must be real numeric/logical data.');
    end
    if rank == 1, values = values(:); end
    own = nxmpes_io('exists',file,[entry '/ox_arpes']);
    explorer = nxmpes_io('exists',file,[entry '/arpes_explorer']);
    warnings = {};
    if own
        extension = [entry '/ox_arpes'];
        if nxmpes_io('attribute',file,extension,'schema_version',0) ~= 1
            error('OxArpes:UnsupportedNexusVersion','Unsupported OX NeXus metadata version.');
        end
        className = nxmpes_io('text',nxmpes_io('attribute',file,extension,'data_class',''));
        order = 1:rank;
    elseif explorer
        pythonClass = nxmpes_io('text',nxmpes_io('attribute',file,[entry '/arpes_explorer'],'python_class',''));
        switch pythonClass
            case 'ARPESCutData'
                className = 'OxA_CUT'; expectedAxes = {'angular0','energy'};
            case 'ARPESMapData'
                className = 'OxA_MAP'; expectedAxes = {'angular0','angular1','energy'};
            case 'ARPESKzData'
                className = 'OxA_KZ'; expectedAxes = {'photon_energy','angular0','energy'};
            case 'ARPES2DScanData'
                className = 'OxArpes_4D_Data'; expectedAxes = {'spatial0','spatial1','angular0','energy'};
            otherwise
                className = base_class(rank); expectedAxes = axesNames;
        end
        [present,order] = ismember(expectedAxes,axesNames);
        if rank ~= numel(expectedAxes) || ~all(present)
            error('OxArpes:UnsupportedNexusAxes','Explorer class and NXdata axes disagree.');
        end
        warnings = {'ARPES Explorer layout imported; full NXmpes compliance is not established.'};
    else
        [className,order] = infer_class(axesNames,axisMetadata);
    end
    data = construct_object(className,rank);
    [properties,~] = nxmpes_io('layout',data);
    for i = 1:rank
        data.(properties{i}) = axesValues{order(i)};
        data.([properties{i} '_name']) = axisMetadata{order(i)}.label;
        data.([properties{i} '_unit']) = axisMetadata{order(i)}.units;
    end
    if rank > 1, values = permute(values,order); end
    data.value = values;
    data.info = struct(); % Never introduce constructor calibration defaults.
    data.name = read_text(file,[entry '/title'],entry(2:end));
    if own
        data.info = nxmpes_io('read_metadata',file,[extension '/info']);
        data.name = nxmpes_io('read_metadata',file,[extension '/name']);
        labels = nxmpes_io('read_metadata',file,[extension '/labels']);
        names = fieldnames(labels);
        allowedLabels = [strcat(properties,'_name') strcat(properties,'_unit') {'v_name','v_unit'}];
        for i = 1:numel(names)
            if ismember(names{i},allowedLabels) && isprop(data,names{i})
                data.(names{i}) = labels.(names{i});
            end
        end
        valueClass = nxmpes_io('text',nxmpes_io('attribute',file,signalPath,'ox_matlab_class',class(values)));
        allowed = {'double','single','logical','int8','int16','int32','int64','uint8','uint16','uint32','uint64'};
        if ~ismember(valueClass,allowed), error('OxArpes:InvalidNexusSignal','Unsupported stored value class.'); end
        originalShape = double(nxmpes_io('attribute',file,signalPath,'ox_matlab_size',size(values)));
        data.value = reshape(cast(values,valueClass),originalShape(:).');
    else
        [data.info,unreadable] = read_standard_metadata(file,entry);
        context = struct('source',file,'entry',entry,'data_group',group, ...
            'definition',read_text(file,[entry '/definition'],''), ...
            'axes',{axisMetadata},'signal_units',nxmpes_io('text', ...
                nxmpes_io('attribute',file,signalPath,'units','')), ...
            'validation','not_run');
        if explorer
            metadataPath = [entry '/arpes_explorer/metadata'];
            if nxmpes_io('exists',file,metadataPath)
                [context.explorer_metadata,extraUnreadable] = read_explorer_metadata(file,metadataPath);
                unreadable = [unreadable extraUnreadable];
                data = apply_explorer_labels(data,context.explorer_metadata,rank);
            end
        end
        context.unreadable_metadata = unreadable;
        if ~isempty(unreadable)
            warnings{end+1} = sprintf(['%d optional metadata fields use a newer HDF5 datatype than this MATLAB supports; ' ...
                'their source paths are retained in info.nexus.unreadable_metadata.'],numel(unreadable));
        end
        data.info.nexus = context;
    end
    if isprop(data,'v_unit') && ~own
        data.v_unit = nxmpes_io('text',nxmpes_io('attribute',file,signalPath,'units',''));
    end
    data.validate();
    report = struct('entry',entry,'data_group',group,'class',class(data), ...
        'axes',{axesNames},'permutation',order,'validation','not_run','warnings',{warnings});
end

function group = select_data_group(file,entry,requested)
    if ~isempty(requested)
        group = requested;
        if ~startsWith(group,[entry '/'])
            error('OxArpes:InvalidNexusDataGroup','DataGroup must be an absolute path inside Entry.');
        end
    else
        preferred = nxmpes_io('text',nxmpes_io('attribute',file,entry,'default',''));
        if ~isempty(preferred)
            group = resolve_path(entry,preferred);
        elseif nxmpes_io('exists',file,[entry '/data'])
            group = [entry '/data'];
        elseif nxmpes_io('exists',file,[entry '/measurement'])
            group = [entry '/measurement'];
        else
            children = nxmpes_io('children',file,entry);
            groups = {};
            for i = 1:numel(children)
                if children(i).is_group && strcmp(nxmpes_io('text', ...
                        nxmpes_io('attribute',file,children(i).path,'NX_class','')),'NXdata')
                    groups{end+1} = children(i).path; %#ok<AGROW>
                end
            end
            if numel(groups) ~= 1
                error('OxArpes:AmbiguousNexusData','Select a DataGroup explicitly.');
            end
            group = groups{1};
        end
    end
    if ~strcmp(nxmpes_io('text',nxmpes_io('attribute',file,group,'NX_class','')),'NXdata')
        error('OxArpes:InvalidNexusDataGroup','Selected group is not NXdata.');
    end
end

function result = resolve_path(group,name)
    if startsWith(name,'/'), result = name;
    else, result = [group '/' name]; end
end

function value = read_text(file,location,fallback)
    if nxmpes_io('exists',file,location), value = nxmpes_io('text',h5read(file,location));
    else, value = fallback; end
end

function [className,order] = infer_class(names,metadata)
    rank = numel(names);
    className = base_class(rank);
    order = 1:rank;
    energy = find(strcmp(names,'energy'));
    angle = find(strcmp(names,'angular0'));
    photon = find(strcmp(names,'photon_energy'));
    otherAngle = find(strcmp(names,'angular1'));
    if isempty(energy), return; end
    kinetic = strcmp(metadata{energy}.type,'kinetic') && ...
        ~strcmp(metadata{energy}.energy_convention,'relative');
    anglesInDegrees = ~isempty(angle) && ismember(metadata{angle}.units,{'deg','degree','degrees'});
    energyInEV = strcmpi(metadata{energy}.units,'eV');
    if rank == 2 && ~isempty(angle) && kinetic && anglesInDegrees && energyInEV
        className = 'OxA_CUT'; order = [angle energy];
    elseif rank == 3 && ~isempty(angle) && ~isempty(otherAngle) && kinetic && anglesInDegrees && energyInEV && ...
            ismember(metadata{otherAngle}.units,{'deg','degree','degrees'})
        className = 'OxA_MAP'; order = [otherAngle angle energy];
    elseif rank == 3 && ~isempty(angle) && ~isempty(photon) && ...
            strcmp(metadata{energy}.energy_convention,'relative') && anglesInDegrees && energyInEV && ...
            strcmpi(metadata{photon}.units,'eV')
        className = 'OxA_KZ'; order = [photon angle energy];
    end
end

function name = base_class(rank)
    name = sprintf('OxArpes_%dD_Data',rank);
end

function data = construct_object(name,rank)
    allowed = {'OxArpes_1D_Data','OxArpes_2D_Data','OxArpes_3D_Data', ...
        'OxArpes_4D_Data','OxA_CUT','OxA_MAP','OxA_MAP_ToF','OxA_KZ','OxA_RSImage'};
    if ~ismember(name,allowed)
        error('OxArpes:UnsupportedNexusClass','Unsupported OX class %s.',name);
    end
    data = feval(name);
    properties = nxmpes_io('layout',data);
    if numel(properties) ~= rank
        error('OxArpes:UnsupportedNexusDimension','Stored OX class and signal rank disagree.');
    end
end

function [metadata,unreadable] = read_standard_metadata(file,entry)
    metadata = struct();
    unreadable = {};
    mapping = {'start_time','start_time';'sample_name','sample/name'; ...
        'photon_energy','instrument/beam_probe/incident_energy'; ...
        'workfunction','instrument/electronanalyzer/work_function'; ...
        'beamline','instrument/name'; ...
        'lens_mode','instrument/electronanalyzer/collection_column/lens_mode'; ...
        'pass_energy','instrument/electronanalyzer/energy_dispersion/pass_energy'};
    for i = 1:size(mapping,1)
        location = [entry '/' mapping{i,2}];
        if nxmpes_io('exists',file,location)
            value = nxmpes_io('read',file,location);
            if iscell(value) || isstring(value) || ischar(value)
                value = nxmpes_io('text',value);
                if ismember(lower(value),{'none','unknown',''}), continue; end
            end
            if isnumeric(value)
                unit = nxmpes_io('text',nxmpes_io('attribute',file,location,'units',''));
                % OX numerical calibration fields require eV. Retain other
                % units under nexus instead of silently treating them as eV.
                if ~strcmpi(unit,'eV'), continue; end
                if isvector(value), value = value(:).'; end
            end
            metadata.(mapping{i,1}) = value;
        end
    end
    for group = {'instrument','sample'}
        location = [entry '/' group{1}];
        if nxmpes_io('exists',file,location)
            [metadata.(['nexus_' group{1}]),extraUnreadable] = read_tree(file,location);
            unreadable = [unreadable extraUnreadable]; %#ok<AGROW>
        end
    end
end

function [result,unreadable] = read_explorer_metadata(file,location)
    children = nxmpes_io('children',file,location);
    result = struct();
    unreadable = {};
    % Main arrays already come from NXdata; avoid duplicating bulk data.
    skip = {'std_value','value','raw_value','raw_data','std_x','std_y','std_z','std_t','std_e'};
    for i = 1:numel(children)
        name = children(i).name;
        if ismember(name,skip), continue; end
        child = [location '/' name];
        if ~children(i).readable
            result.(matlab.lang.makeValidName(name)) = struct( ...
                'status','unsupported_hdf5_datatype','source_path',child);
            unreadable{end+1} = child; %#ok<AGROW>
            continue
        end
        original = nxmpes_io('text',nxmpes_io('attribute',file,child,'arpes_explorer_original_name',name));
        if children(i).is_group
            [value,extraUnreadable] = read_tree(file,child);
            unreadable = [unreadable extraUnreadable]; %#ok<AGROW>
        else
            value = nxmpes_io('read',file,child);
        end
        result.(matlab.lang.makeValidName(original)) = value;
    end
end

function [result,unreadable] = read_tree(file,location,depth)
% Preserve foreign metadata as values plus attributes, without interpreting it.
    if nargin < 3, depth = 0; end
    unreadable = {};
    attributes = nxmpes_io('attributes',file,location);
    result = struct('attributes',{attributes},'fields',struct(),'groups',struct());
    if depth >= 16 || strcmp(nxmpes_io('text', ...
            nxmpes_io('attribute',file,location,'NX_class','')),'NXdata')
        result.source_path = location;
        return
    end
    children = nxmpes_io('children',file,location);
    for i = 1:numel(children)
        name = matlab.lang.makeValidName(children(i).name);
        child = children(i).path;
        if ~children(i).readable
            result.fields.(name) = struct('status','unsupported_hdf5_datatype','source_path',child);
            unreadable{end+1} = child; %#ok<AGROW>
        elseif children(i).is_group
            [result.groups.(name),extraUnreadable] = read_tree(file,child,depth+1);
            unreadable = [unreadable extraUnreadable]; %#ok<AGROW>
        else
            attributes = nxmpes_io('attributes',file,child);
            result.fields.(name) = struct('value',{nxmpes_io('read',file,child)}, ...
                'attributes',{attributes});
        end
    end
end

function data = apply_explorer_labels(data,metadata,rank)
    if rank == 4, sources = {'std_x','std_z','std_t','std_e'};
    else, sources = {'std_x','std_y','std_z'}; end
    properties = nxmpes_io('layout',data);
    for i = 1:rank
        for suffix = {'_name','_unit'}
            key = [sources{i} suffix{1}];
            if isfield(metadata,key)
                data.([properties{i} suffix{1}]) = nxmpes_io('text',metadata.(key));
            end
        end
    end
end
