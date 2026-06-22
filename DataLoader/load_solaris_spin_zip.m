function DATA = load_solaris_spin_zip(file_path)
%LOAD_SOLARIS_SPIN_ZIP Load spin-ARPES data from a Solaris/Scienta zip file.
%
% Each channel field contains:
%   - x, optionally y, optionally z
%   - value
%   - region, channel, name, path

    % Unzip the input file into a temporary folder
    folder_path = unzip_to_temp_folder(file_path);

    % Ensure the temporary folder is removed when the function exits
    cleanupObj = onCleanup(@() remove_temp_folder(folder_path)); %#ok<NASGU>

    % Parse viewer.ini
    viewer_path = fullfile(folder_path, 'viewer.ini');
    viewer_ini = read_ini_file(viewer_path);

    current_region = strtrim(ini_get(viewer_ini, 'viewer', 'current_region'));
    region_section = ['viewer.' current_region];

    channel_list_raw = ini_get(viewer_ini, region_section, 'channel_list');
    channel_list = split_semicolon_list(channel_list_raw);

    region_name = strtrim(ini_get(viewer_ini, region_section, 'name'));
    meta_path = fullfile(folder_path, [region_name '.ini']);

    % This is currently unused, but keep it if you may need metadata later.
    meta_ini = read_ini_file(meta_path); %#ok<NASGU>

    [~, file_stem, ~] = fileparts(file_path);

    % Preallocate output struct
    DATA = struct();

    for i = 1:numel(channel_list)

        channel = strtrim(channel_list{i});
        if isempty(channel)
            continue;
        end

        channel_section = ['viewer.' current_region '.' channel];

        % Channel-specific fields from viewer.ini
        data_rel = strtrim(ini_get(viewer_ini, channel_section, 'path'));
        data_path = resolve_zip_path(folder_path, data_rel);

        name = strtrim(ini_get(viewer_ini, channel_section, 'name'));

        width = str2double(ini_get(viewer_ini, channel_section, 'width'));
        width_offset = str2double(ini_get(viewer_ini, channel_section, 'width_offset'));
        width_delta = str2double(ini_get(viewer_ini, channel_section, 'width_delta'));
        width_label_raw = ini_get(viewer_ini, channel_section, 'width_label');
        [width_name, width_unit] = parse_axis_label(width_label_raw);

        depth = str2double(ini_get(viewer_ini, channel_section, 'depth'));
        depth_offset = str2double(ini_get(viewer_ini, channel_section, 'depth_offset'));
        depth_delta = str2double(ini_get(viewer_ini, channel_section, 'depth_delta'));
        depth_label_raw = ini_get(viewer_ini, channel_section, 'depth_label');
        [depth_name, depth_unit] = parse_axis_label(depth_label_raw);

        height = str2double(ini_get(viewer_ini, channel_section, 'height'));
        height_offset = str2double(ini_get(viewer_ini, channel_section, 'height_offset'));
        height_delta = str2double(ini_get(viewer_ini, channel_section, 'height_delta'));
        height_label_raw = ini_get(viewer_ini, channel_section, 'height_label');
        [height_name, height_unit] = parse_axis_label(height_label_raw);

        % Axis convention:
        %   depth  -> angle_y
        %   width  -> energy
        %   height -> angle_x
        angle_x = height_offset + height_delta * (0:(height - 1));
        angle_y = depth_offset  + depth_delta  * (0:(depth  - 1));
        energy  = width_offset  + width_delta  * (0:(width  - 1));

        axis_values = {angle_y, energy, angle_x};
        axis_names  = {depth_name, width_name, height_name};
        axis_units  = {depth_unit, width_unit, height_unit};

        dims = [depth, width, height];

        % Read binary data
        values = read_binary_data(data_path);

        expected_numel = depth * width * height;
        if numel(values) ~= expected_numel
            error('Channel "%s" has %d data points, but expected %d from depth*width*height.', ...
                channel, numel(values), expected_numel);
        end

        % Match NumPy reshape(order='C') behaviour:
        %
        % Python:
        %   values.reshape(depth, width, height)
        %
        % MATLAB equivalent:
        %   reshape as [height, width, depth], then permute to [depth, width, height].
        value_3d = reshape(values, [width, depth, height]);
        % value_3d = permute(value_3d, [2 1 3]);

        active_dims = find(dims > 1);
        value_dim = numel(active_dims);

        switch value_dim

            case 1
                out = OxArpes_1D_Data();

                ax = active_dims(1);

                out.x = axis_values{ax};
                out.x_name = axis_names{ax};
                out.x_unit = axis_units{ax};

                out.value = squeeze(value_3d);
                out.value = out.value(:);

                out.v_name = 'Counts';
                out.v_unit = 'arb. unit';

            case 2
                out = OxA_CUT();

                ax1 = active_dims(2);
                ax2 = active_dims(1);

                out.x = axis_values{ax1};
                out.x_name = axis_names{ax1};
                out.x_unit = axis_units{ax1};

                out.y = axis_values{ax2};
                out.y_name = axis_names{ax2};
                out.y_unit = axis_units{ax2};

                out.value = squeeze(value_3d)';

            case 3
                % If OxA_MAP supports the constructor used in your regular loader:
                out = OxA_MAP(axis_values{1}, axis_values{2}, axis_values{3}, value_3d);

                % Add axis labels if these properties exist in your class.
                % If OxA_MAP does not support these properties, remove this block.
                out.x_name = axis_names{1};
                out.x_unit = axis_units{1};

                out.y_name = axis_names{2};
                out.y_unit = axis_units{2};

                out.z_name = axis_names{3};
                out.z_unit = axis_units{3};

                out.v_name = 'Counts';
                out.v_unit = 'arb. unit';

            otherwise
                error('Channel "%s" has no non-singleton data dimension.', channel);

        end

        % Optional metadata
        out.info.region = current_region;
        out.info.channel = channel;
        out.info.name = name;
        out.info.path = data_rel;

        fieldname = matlab.lang.makeValidName(sprintf('%s_%s_%s', current_region, channel, name));
        if isfield(DATA, fieldname)
            fieldname = matlab.lang.makeValidName(sprintf('%s_%s_%s_%d', current_region, channel, name, i));
        end

        DATA.(fieldname) = out;

        % Also create a variable in the base workspace:
        % name = [file_name '_' channel]
        base_var_name = matlab.lang.makeValidName([file_stem '_' channel '_' name]);
        assignin('base', base_var_name, out);

    end

end

function [axis_name, axis_unit] = parse_axis_label(label_raw)

    label_raw = strtrim(label_raw);

    tok = regexp(label_raw, '^(.*?)\s*\[(.*?)\]\s*$', 'tokens', 'once');

    if isempty(tok)
        axis_name = label_raw;
        axis_unit = '';
    else
        axis_name = strtrim(tok{1});
        axis_unit = strtrim(tok{2});
    end

end

% -------------------------------------------------------------------------
function folder_path = unzip_to_temp_folder(file_path)
    [pathstr, file, ~] = fileparts(file_path);
    folder_path = fullfile(pathstr, [file '_tmp']);

    if exist(folder_path, 'dir')
        remove_temp_folder(folder_path);
    end

    unzip(file_path, folder_path);
end

% -------------------------------------------------------------------------
function ini = read_ini_file(file_path)
    txt = fileread(file_path);
    lines = regexp(txt, '\r\n|\n|\r', 'split');

    ini = struct();
    section = '';

    for k = 1:numel(lines)
        line = strtrim(lines{k});

        if isempty(line) || startsWith(line, ';') || startsWith(line, '#')
            continue;
        end

        if startsWith(line, '[') && endsWith(line, ']')
            section = sanitize_ini_name(line(2:end-1));
            if ~isfield(ini, section)
                ini.(section) = struct();
            end
            continue;
        end

        tok = regexp(line, '^([^=]+)=(.*)$', 'tokens', 'once');
        if ~isempty(tok) && ~isempty(section)
            key = sanitize_ini_name(strtrim(tok{1}));
            val = strtrim(tok{2});
            ini.(section).(key) = val;
        end
    end
end

% -------------------------------------------------------------------------
function value = ini_get(ini, section, key)
    section = sanitize_ini_name(section);
    key = sanitize_ini_name(key);

    if ~isfield(ini, section)
        error('INI section not found: %s', section);
    end
    if ~isfield(ini.(section), key)
        error('INI key not found: [%s] %s', section, key);
    end

    value = ini.(section).(key);
end

% -------------------------------------------------------------------------
function name = sanitize_ini_name(name)
    name = regexprep(strtrim(name), '[^a-zA-Z0-9_]', '_');
    if isempty(name)
        name = 'x';
    elseif ~isletter(name(1))
        name = ['x' name];
    end
end

% -------------------------------------------------------------------------
function items = split_semicolon_list(str)
    items = strsplit(str, ';');
    items = items(~cellfun(@isempty, items));
end

% -------------------------------------------------------------------------
function data_path = resolve_zip_path(folder_path, rel_path)
    rel_path = strrep(rel_path, '/', filesep);
    rel_path = strrep(rel_path, '\', filesep);
    data_path = fullfile(folder_path, rel_path);
end

% -------------------------------------------------------------------------
function values = read_binary_data(bin_path)
    fileID = fopen(bin_path, 'rb');
    if fileID < 0
        error('Could not open binary file: %s', bin_path);
    end

    values = fread(fileID, inf, 'single=>single');
    fclose(fileID);
end

% -------------------------------------------------------------------------
function remove_temp_folder(folder_path)
    if exist(folder_path, 'dir')
        rmdir(folder_path, 's');
    end
end