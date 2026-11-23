function varargout = nxmpes_io(action, varargin)
%NXMPES_IO Shared HDF5 primitives; numeric arrays use NeXus/C axis order.
    switch action
        case 'attribute'
            varargout{1} = read_attribute(varargin{:});
        case 'exists'
            varargout{1} = exists(varargin{:});
        case 'text'
            varargout{1} = text_value(varargin{1});
        case 'read'
            varargout{1} = read_array(varargin{:});
        case 'write'
            write_array(varargin{:});
        case 'group'
            make_group(varargin{:});
        case 'write_metadata'
            write_metadata(varargin{:});
        case 'read_metadata'
            varargout{1} = read_metadata(varargin{:});
        case 'entries'
            varargout{1} = find_entries(varargin{:});
        case 'layout'
            [varargout{1:nargout}] = object_layout(varargin{:});
        case 'children'
            varargout{1} = list_children(varargin{:});
        case 'shape'
            varargout{1} = dataset_shape(varargin{:});
        case 'attributes'
            varargout{1} = list_attributes(varargin{:});
        case 'unsupported_type'
            varargout{1} = unsupported_type(varargin{1});
        otherwise
            error('OxArpes:NexusInternal','Unknown NeXus operation.');
    end
end

function value = read_attribute(file, location, name, fallback)
    id = H5F.open(file, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    c1 = onCleanup(@() H5F.close(id));
    node = H5O.open(id,location,'H5P_DEFAULT');
    c2 = onCleanup(@() H5O.close(node));
    value = fallback;
    info = H5O.get_info(node);
    for i = 1:info.num_attrs
        attribute = H5A.open_by_idx(node,'.','H5_INDEX_NAME','H5_ITER_INC',i-1);
        c3 = onCleanup(@() H5A.close(attribute));
        if strcmp(H5A.get_name(attribute),name)
            % The high-level attribute reader also decodes fixed-width string
            % arrays; unlike h5info it does not traverse child datasets.
            value = h5readatt(file,location,name);
            return
        end
        clear c3
    end
end

function tf = exists(file, location)
    id = H5F.open(file, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    cleanup = onCleanup(@() H5F.close(id));
    % H5L.exists can error when an intermediate group is absent.
    parts = strsplit(location, '/');
    current = '';
    tf = true;
    for i = 1:numel(parts)
        if isempty(parts{i}), continue; end
        current = [current '/' parts{i}]; %#ok<AGROW>
        if ~H5L.exists(id, current, 'H5P_DEFAULT')
            tf = false;
            return
        end
    end
end

function value = text_value(value)
    if iscell(value) && isscalar(value), value = value{1}; end
    value = char(string(value));
    value(value == char(0)) = [];
    value = strtrim(value);
end

function value = read_array(file, location)
    shape = dataset_shape(file,location);
    rank = numel(shape);
    id = H5F.open(file, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    c1 = onCleanup(@() H5F.close(id));
    dataset = H5D.open(id,location);
    c2 = onCleanup(@() H5D.close(dataset));
    datatype = H5D.get_type(dataset);
    c3 = onCleanup(@() H5T.close(datatype));
    if H5T.get_class(datatype) == H5ML.get_constant_value('H5T_ENUM')
        % h5py's boolean enum is not supported by high-level h5info in R2024a.
        count = H5T.get_nmembers(datatype);
        names = cell(1,count);
        for i = 1:count, names{i} = H5T.get_member_name(datatype,i-1); end
        if count ~= 2 || ~all(ismember({'FALSE','TRUE'},names))
            error('OxArpes:UnsupportedNexusType','Only boolean HDF5 enums are supported.');
        end
        value = logical(H5D.read(dataset,datatype,'H5S_ALL','H5S_ALL','H5P_DEFAULT'));
    else
        value = h5read(file, location);
    end
    if isnumeric(value) || islogical(value)
        if rank > 1
            value = reshape(value, fliplr(shape));
            value = permute(value, rank:-1:1);
        end
    end
end

function shape = dataset_shape(file,location)
    id = H5F.open(file,'H5F_ACC_RDONLY','H5P_DEFAULT');
    c1 = onCleanup(@() H5F.close(id));
    dataset = H5D.open(id,location);
    c2 = onCleanup(@() H5D.close(dataset));
    space = H5D.get_space(dataset);
    c3 = onCleanup(@() H5S.close(space));
    [~,shape] = H5S.get_simple_extent_dims(space);
    shape = double(shape(:).');
end

function children = list_children(file,location)
    id = H5F.open(file,'H5F_ACC_RDONLY','H5P_DEFAULT');
    c1 = onCleanup(@() H5F.close(id));
    group = H5G.open(id,location);
    c2 = onCleanup(@() H5G.close(group));
    info = H5G.get_info(group);
    children = repmat(struct('name','','path','','is_group',false,'readable',true),1,info.nlinks);
    for i = 1:info.nlinks
        name = H5L.get_name_by_idx(group,'.','H5_INDEX_NAME','H5_ITER_INC',i-1,'H5P_DEFAULT');
        readable = true;
        isGroup = false;
        try
            node = H5O.open(group,name,'H5P_DEFAULT');
            nodeInfo = H5O.get_info(node);
            H5O.close(node);
            isGroup = nodeInfo.type == H5ML.get_constant_value('H5G_GROUP');
        catch cause
            if ~unsupported_type(cause), rethrow(cause); end
            % Newer HDF5 datatype messages cannot be decoded by older MATLAB.
            % Keep the path so optional metadata can retain a source reference.
            readable = false;
        end
        if strcmp(location,'/'), prefix = ''; else, prefix = location; end
        children(i) = struct('name',name,'path',[prefix '/' name], ...
            'is_group',isGroup,'readable',readable);
    end
end

function tf = unsupported_type(cause)
    tf = contains(cause.message,'bad version number for datatype message');
end

function attributes = list_attributes(file,location)
    id = H5F.open(file,'H5F_ACC_RDONLY','H5P_DEFAULT');
    c1 = onCleanup(@() H5F.close(id));
    node = H5O.open(id,location,'H5P_DEFAULT');
    c2 = onCleanup(@() H5O.close(node));
    info = H5O.get_info(node);
    attributes = repmat(struct('Name','','Value',[]),1,info.num_attrs);
    for i = 1:info.num_attrs
        attribute = H5A.open_by_idx(node,'.','H5_INDEX_NAME','H5_ITER_INC',i-1);
        c3 = onCleanup(@() H5A.close(attribute));
        attributes(i).Name = H5A.get_name(attribute);
        attributes(i).Value = h5readatt(file,location,attributes(i).Name);
        clear c3
    end
end

function make_group(file, location, nxclass)
    id = H5F.open(file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
    cleanup = onCleanup(@() H5F.close(id));
    group = H5G.create(id, location, 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5G.close(group);
    if ~isempty(nxclass), h5writeatt(file, location, 'NX_class', nxclass); end
end

function write_array(file, location, value, shape, compression)
    if ischar(value) || isstring(value)
        % Scalar UTF-8 NX_CHAR, independent of MATLAB character array shape.
        id = H5F.open(file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
        c1 = onCleanup(@() H5F.close(id));
        datatype = H5T.copy('H5T_C_S1');
        c2 = onCleanup(@() H5T.close(datatype));
        H5T.set_size(datatype, 'H5T_VARIABLE');
        H5T.set_cset(datatype, 'H5T_CSET_UTF8');
        space = H5S.create('H5S_SCALAR');
        c3 = onCleanup(@() H5S.close(space));
        dataset = H5D.create(id, location, datatype, space, 'H5P_DEFAULT');
        c4 = onCleanup(@() H5D.close(dataset));
        H5D.write(dataset, datatype, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', {char(value)});
        return
    end
    if islogical(value), value = uint8(value); end
    options = {'Datatype',class(value)};
    if compression > 0 && prod(shape) > 1
        chunk = shape;
        while prod(chunk) * 8 > 1024^2
            [~, longest] = max(chunk);
            chunk(longest) = ceil(chunk(longest)/2);
        end
        options = [options {'ChunkSize',fliplr(chunk),'Deflate',compression}];
    end
    h5create(file, location, fliplr(shape), options{:});
    if numel(shape) > 1
        value = permute(reshape(value,shape), numel(shape):-1:1);
    else
        value = value(:);
    end
    h5write(file, location, value);
end

function write_metadata(file, location, value)
% Lossless, non-executable encoding of ordinary MATLAB metadata.
    make_group(file, location, 'NXcollection');
    h5writeatt(file, location, 'matlab_class', class(value));
    h5writeatt(file, location, 'matlab_size', uint64(size(value)));
    if isstruct(value)
        names = fieldnames(value);
        h5writeatt(file, location, 'field_names_json', jsonencode(names));
        for i = 1:numel(value)
            item = sprintf('%s/item_%d',location,i);
            make_group(file,item,'NXcollection');
            for j = 1:numel(names)
                write_metadata(file, sprintf('%s/field_%d',item,j), value(i).(names{j}));
            end
        end
    elseif iscell(value) || isstring(value)
        for i = 1:numel(value)
            item = sprintf('%s/item_%d',location,i);
            if iscell(value)
                write_metadata(file,item,value{i});
            elseif ismissing(value(i))
                write_metadata(file,item,[]);
            else
                write_metadata(file,item,char(value(i)));
            end
        end
    elseif isnumeric(value) || islogical(value) || ischar(value)
        if ~isreal(value) || issparse(value)
            error('OxArpes:UnsupportedNexusMetadata', ...
                'Complex or sparse metadata at %s is not supported.',location);
        end
        if ~isempty(value)
            if ischar(value), value = uint16(value); end
            write_array(file,[location '/value'],value,numel(value),0);
        end
    else
        error('OxArpes:UnsupportedNexusMetadata', ...
            'Metadata class %s at %s is not supported. Convert it to a struct, text or numeric array.', ...
            class(value),location);
    end
end

function value = read_metadata(file, location)
    kind = text_value(read_attribute(file,location,'matlab_class',''));
    shape = double(read_attribute(file,location,'matlab_size',[0 0]));
    shape = shape(:).';
    count = prod(shape);
    switch kind
        case 'struct'
            names = cellstr(string(jsondecode(text_value( ...
                read_attribute(file,location,'field_names_json','[]')))));
            value = repmat(cell2struct(cell(numel(names),1),names,1),shape);
            for i = 1:count
                for j = 1:numel(names)
                    value(i).(names{j}) = read_metadata(file, ...
                        sprintf('%s/item_%d/field_%d',location,i,j));
                end
            end
        case {'cell','string'}
            value = cell(shape);
            for i = 1:count
                value{i} = read_metadata(file,sprintf('%s/item_%d',location,i));
            end
            if strcmp(kind,'string')
                missingItems = cellfun(@(x) isnumeric(x) && isempty(x),value);
                value(missingItems) = {''};
                value = string(value);
                value(missingItems) = missing;
            end
        case {'double','single','uint8','uint16','uint32','uint64', ...
                'int8','int16','int32','int64','logical','char'}
            if count == 0
                value = cast(zeros(shape),kind);
            else
                value = reshape(cast(h5read(file,[location '/value']),kind),shape);
            end
        otherwise
            error('OxArpes:UnsupportedNexusMetadata','Unsupported stored metadata class %s.',kind);
    end
end

function entries = find_entries(file)
    children = list_children(file,'/');
    explorer = strcmpi(text_value(read_attribute(file,'/','arpes_explorer_export','')),'true');
    entries = {};
    for i = 1:numel(children)
        node = children(i);
        if ~node.is_group || ~strcmp(text_value(read_attribute(file,node.path,'NX_class','')),'NXentry')
            continue
        end
        definition = '';
        if exists(file,[node.path '/definition'])
            definition = text_value(h5read(file,[node.path '/definition']));
        end
        if ismember(definition,{'NXmpes','NXmpes_arpes'}) || ...
                (explorer && exists(file,[node.path '/arpes_explorer']))
            entries{end+1} = node.path; %#ok<AGROW>
        end
    end
end

function [properties, axisNames] = object_layout(data)
    allowed = {'OxArpes_1D_Data','OxArpes_2D_Data','OxArpes_3D_Data', ...
        'OxArpes_4D_Data','OxA_CUT','OxA_MAP','OxA_MAP_ToF','OxA_KZ','OxA_RSImage'};
    if ~ismember(class(data),allowed)
        error('OxArpes:UnsupportedNexusClass','Unsupported OX class %s.',class(data));
    end
    if isa(data,'OxArpes_4D_Data')
        properties = {'x','y','k','z'};
        axisNames = {'spatial0','spatial1','angular0','energy'};
    elseif isa(data,'OxArpes_3D_Data')
        properties = {'x','y','z'};
        if isa(data,'OxA_KZ')
            axisNames = {'photon_energy','angular0','energy'};
        elseif isa(data,'OxA_RSImage')
            axisNames = {'spatial0','spatial1','energy'};
        elseif isa(data,'OxA_MAP') || isa(data,'OxA_MAP_ToF')
            axisNames = {'angular1','angular0','energy'};
        else
            axisNames = properties;
        end
    elseif isa(data,'OxArpes_2D_Data')
        properties = {'x','y'};
        if isa(data,'OxA_CUT'), axisNames = {'angular0','energy'};
        else, axisNames = properties;
        end
    elseif isa(data,'OxArpes_1D_Data')
        properties = {'x'};
        axisNames = properties;
    else
        error('OxArpes:UnsupportedNexusClass','Expected a scalar OX data object.');
    end
end
