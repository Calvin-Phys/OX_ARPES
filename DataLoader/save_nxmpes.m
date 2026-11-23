function report = save_nxmpes(filePath, data, varargin)
%SAVE_NXMPES Export OX arrays and metadata to a NeXus NXmpes HDF5 file.
%   REPORT = SAVE_NXMPES(FILE, DATA) accepts one scalar OX object or a
%   structure of named scalar OX objects (one NXentry per field).
%   Options: Metadata (scalar struct, overrides acquisition fields),
%   AxisNames (cell/string vector for a single object), EnergyConvention
%   ('auto','kinetic','binding','relative','unknown'), Compression (0..9,
%   default 4), SignalUnits (default unknown), Overwrite (default false).
%   No interpolation is performed.
%   Missing acquisition fields are omitted and listed in REPORT.entries.
%   REPORT.validation is 'not_run': this adapter is not an NXDL validator.
%   Ordinary numeric/logical/text/cell/struct INFO is preserved losslessly.

    parser = inputParser;
    addRequired(parser,'filePath',@(x) ischar(x) || (isstring(x) && isscalar(x)));
    addRequired(parser,'data');
    addParameter(parser,'Metadata',struct(),@(x) isstruct(x) && isscalar(x));
    addParameter(parser,'AxisNames',{},@(x) iscellstr(x) || isstring(x));
    addParameter(parser,'EnergyConvention','auto',@(x) ischar(x) || isstring(x));
    addParameter(parser,'SignalUnits','',@(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(parser,'Compression',4,@(x) isnumeric(x) && isscalar(x) && ...
        isfinite(x) && x >= 0 && x <= 9 && x == fix(x));
    addParameter(parser,'Overwrite',false,@(x) islogical(x) && isscalar(x));
    parse(parser,filePath,data,varargin{:});
    options = parser.Results;
    convention = validatestring(options.EnergyConvention, ...
        {'auto','kinetic','binding','relative','unknown'});
    filePath = char(filePath);
    if isfile(filePath) && ~options.Overwrite
        error('OxArpes:NexusFileExists','File already exists: %s',filePath);
    end
    if isstruct(data)
        if ~isscalar(data), error('OxArpes:InvalidNexusInput','The named input structure must be scalar.'); end
        names = fieldnames(data);
        objects = struct2cell(data);
    else
        names = {'entry'};
        objects = {data};
    end
    if isempty(objects) || (~isempty(options.AxisNames) && numel(objects) ~= 1)
        error('OxArpes:InvalidNexusInput','Provide data; AxisNames requires a single object.');
    end
    for i = 1:numel(objects)
        if ~isscalar(objects{i}) || ~isobject(objects{i})
            error('OxArpes:UnsupportedNexusClass','Each entry must be a scalar OX data object.');
        end
        nxmpes_io('layout',objects{i});
        objects{i}.validate();
        if ~isreal(objects{i}.value) || issparse(objects{i}.value)
            error('OxArpes:InvalidNexusSignal','Signal must be a real, full numeric/logical array.');
        end
    end
    [folder,~,~] = fileparts(filePath);
    if isempty(folder), folder = pwd; end
    temporary = [tempname(folder) '.nxs'];
    cleanup = onCleanup(@() delete_temporary(temporary));
    id = H5F.create(temporary,'H5F_ACC_EXCL','H5P_DEFAULT','H5P_DEFAULT');
    H5F.close(id);
    h5writeatt(temporary,'/','NX_class','NXroot');
    h5writeatt(temporary,'/','creator','OX_ARPES');
    h5writeatt(temporary,'/','file_name',filePath);
    h5writeatt(temporary,'/','file_time',char(datetime('now','TimeZone','UTC', ...
        'Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")));
    h5writeatt(temporary,'/','default',names{1});
    report = struct('file',filePath,'definition','NXmpes', ...
        'validation','not_run','entries',struct([]));
    entryReports = cell(1,numel(objects));
    for i = 1:numel(objects)
        entryReports{i} = write_entry(temporary,['/' names{i}],objects{i},options,convention);
    end
    report.entries = [entryReports{:}];
    % Publish only after all arrays and metadata have been written successfully.
    if isfile(filePath) && ~options.Overwrite
        error('OxArpes:NexusFileExists','File appeared during export: %s',filePath);
    end
    [ok,message] = movefile(temporary,filePath,'f');
    if ~ok, error('OxArpes:NexusWriteFailed','%s',message); end
end

function report = write_entry(file, entry, data, options, convention)
    nxmpes_io('group',file,entry,'NXentry');
    write_text(file,[entry '/definition'],'NXmpes');
    h5writeatt(file,[entry '/definition'],'version','2026.01');
    write_text(file,[entry '/title'],char(string(data.name)));
    write_text(file,[entry '/program_name'],'OX_ARPES');
    h5writeatt(file,entry,'default','data');
    nxmpes_io('group',file,[entry '/instrument'],'NXinstrument');
    nxmpes_io('group',file,[entry '/instrument/beam_probe'],'NXbeam');
    analyzer = [entry '/instrument/electronanalyzer'];
    nxmpes_io('group',file,analyzer,'NXelectronanalyzer');
    nxmpes_io('group',file,[analyzer '/collection_column'],'NXcollectioncolumn');
    nxmpes_io('group',file,[analyzer '/energy_dispersion'],'NXenergydispersion');
    nxmpes_io('group',file,[analyzer '/detector'],'NXelectron_detector');
    nxmpes_io('group',file,[entry '/sample'],'NXsample');
    metadata = data.info;
    if isempty(metadata), metadata = struct(); end
    if ~isstruct(metadata) || ~isscalar(metadata)
        error('OxArpes:InvalidNexusMetadata','info must be empty or a scalar structure.');
    end
    overrides = fieldnames(options.Metadata);
    for i = 1:numel(overrides), metadata.(overrides{i}) = options.Metadata.(overrides{i}); end
    % Each row: OX info field, relative NeXus path, units, required here.
    mapping = {
        'start_time','start_time','',true;
        'sample_name','sample/name','',true;
        'photon_energy','instrument/beam_probe/incident_energy','eV',true;
        'collection_column_scheme','instrument/electronanalyzer/collection_column/scheme','',true;
        'energy_dispersion_scheme','instrument/electronanalyzer/energy_dispersion/scheme','',true;
        'workfunction','instrument/electronanalyzer/work_function','eV',false;
        'beamline','instrument/name','',false;
        'lens_mode','instrument/electronanalyzer/collection_column/lens_mode','',false;
        'pass_energy','instrument/electronanalyzer/energy_dispersion/pass_energy','eV',false;
        'detector_type','instrument/electronanalyzer/detector/detector_type','',false};
    missingFields = {};
    for i = 1:size(mapping,1)
        key = mapping{i,1};
        if ~isfield(metadata,key) || is_missing(metadata.(key))
            if mapping{i,4}, missingFields{end+1} = mapping{i,2}; end %#ok<AGROW>
            continue
        end
        value = metadata.(key);
        target = [entry '/' mapping{i,2}];
        if isempty(mapping{i,3})
            if ~(ischar(value) || (isstring(value) && isscalar(value)))
                error('OxArpes:InvalidNexusMetadata','info.%s must be text.',key);
            end
            write_text(file,target,char(value));
        else
            validateattributes(value,{'numeric'},{'real','finite','vector','nonempty'},mfilename,key);
            nxmpes_io('write',file,target,value,numel(value),0);
            h5writeatt(file,target,'units',mapping{i,3});
        end
    end
    [properties,axisNames] = nxmpes_io('layout',data);
    if ~isempty(options.AxisNames), axisNames = cellstr(options.AxisNames); end
    if numel(axisNames) ~= numel(properties) || numel(unique(axisNames)) ~= numel(axisNames) || ...
            any(~cellfun(@(x) ~isempty(regexp(x,'^[A-Za-z][A-Za-z0-9_]*$','once')),axisNames)) || ...
            any(ismember(axisNames,{'data','ox_arpes'}))
        error('OxArpes:InvalidNexusAxes','AxisNames must be unique simple HDF5 names, one per dimension.');
    end
    group = [entry '/data'];
    nxmpes_io('group',file,group,'NXdata');
    shape = zeros(1,numel(properties));
    labels = struct();
    for i = 1:numel(properties)
        prop = properties{i};
        label = data.([prop '_name']);
        unit = data.([prop '_unit']);
        if isempty(options.AxisNames)
            axisNames{i} = semantic_name(axisNames{i},label,unit,prop);
        end
        target = [group '/' axisNames{i}];
        shape(i) = numel(data.(prop));
        nxmpes_io('write',file,target,data.(prop),shape(i),0);
        if ~isempty(unit), h5writeatt(file,target,'units',char(unit)); end
        if ~isempty(label), h5writeatt(file,target,'long_name',char(label)); end
        h5writeatt(file,group,[axisNames{i} '_indices'],int32(i-1));
        labels.([prop '_name']) = label;
        labels.([prop '_unit']) = unit;
        if strcmp(axisNames{i},'energy')
            energyConvention = energy_convention(label,convention,metadata);
            if strcmp(energyConvention,'unknown')
                missingFields{end+1} = 'data/energy@type'; %#ok<AGROW>
            else
                kind = energyConvention;
                if strcmp(kind,'relative'), kind = 'kinetic'; end
                h5writeatt(file,target,'type',kind);
                h5writeatt(file,target,'ox_energy_convention',energyConvention);
                if strcmp(energyConvention,'relative')
                    h5writeatt(file,target,'reference','Fermi level; E-E_F');
                end
            end
        end
    end
    h5writeatt(file,group,'signal','data');
    h5writeatt(file,group,'axes',string(axisNames));
    nxmpes_io('write',file,[group '/data'],data.value,shape,options.Compression);
    h5writeatt(file,[group '/data'],'ox_matlab_class',class(data.value));
    h5writeatt(file,[group '/data'],'ox_matlab_size',uint64(size(data.value)));
    signalUnit = char(options.SignalUnits);
    if isempty(signalUnit) && isfield(metadata,'intensity_units')
        signalUnit = char(metadata.intensity_units);
    end
    if isprop(data,'v_name')
        labels.v_name = data.v_name;
        labels.v_unit = data.v_unit;
        if isempty(signalUnit), signalUnit = char(data.v_unit); end
    end
    if is_missing(signalUnit)
        missingFields{end+1} = 'data/data@units';
    else
        h5writeatt(file,[group '/data'],'units',signalUnit);
    end
    extension = [entry '/ox_arpes'];
    nxmpes_io('group',file,extension,'NXcollection');
    h5writeatt(file,extension,'schema_version',int32(1));
    h5writeatt(file,extension,'data_class',class(data));
    h5writeatt(file,extension,'validation','not_run');
    h5writeatt(file,extension,'missing_required_json',jsonencode(missingFields));
    nxmpes_io('write_metadata',file,[extension '/info'],data.info);
    nxmpes_io('write_metadata',file,[extension '/name'],data.name);
    nxmpes_io('write_metadata',file,[extension '/labels'],labels);
    nxmpes_io('write_metadata',file,[extension '/export_metadata'],options.Metadata);
    report = struct('entry',entry,'missing_required',{missingFields}, ...
        'validation','not_run','axes',{axisNames});
end

function name = semantic_name(name,label,unit,fallback)
    label = lower(string(label));
    unit = lower(string(unit));
    if isempty(label), label = ""; end
    if isempty(unit), unit = ""; end
    if contains(label,'energy') && ~contains(label,'photon') && ...
            (strcmp(unit,'ev') || strcmp(unit,'mev'))
        name = 'energy';
    elseif startsWith(name,'angular') && ~ismember(unit,{'deg','degree','degrees','rad'})
        name = fallback;
    end
    if contains(label,'k}_x') || strcmp(label,'kx'), name = 'kx'; end
    if contains(label,'k}_y') || strcmp(label,'ky'), name = 'ky'; end
    if contains(label,'k}_z') || strcmp(label,'kz'), name = 'kz'; end
end

function convention = energy_convention(label,requested,metadata)
    convention = requested;
    if ~strcmp(convention,'auto'), return; end
    labelText = lower(string(label));
    if isempty(labelText), labelText = ""; end
    if isfield(metadata,'energy_convention')
        convention = validatestring(metadata.energy_convention,{'kinetic','binding','relative','unknown'});
    elseif contains(labelText,'kinetic')
        convention = 'kinetic';
    elseif contains(labelText,'binding')
        convention = 'binding';
    elseif strlength(labelText) > 0 && ~isempty(regexp(char(labelText),'e.*-.*e.*f','once'))
        convention = 'relative';
    else
        convention = 'unknown';
    end
end

function tf = is_missing(value)
    tf = isempty(value) || ((ischar(value) || (isstring(value) && isscalar(value))) && ...
        (ismissing(string(value)) || any(strcmpi(strtrim(string(value)),["","none","unknown"]))));
end

function write_text(file,location,value)
    nxmpes_io('write',file,location,value,[],0);
end

function delete_temporary(file)
    if isfile(file), delete(file); end
end
