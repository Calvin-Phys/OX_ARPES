function DATA = load_solaris_spin_zip(file_path)
%LOAD_SCIENTA_SPIN_ZIP Load spin-ARPES data from a Scienta zip file.
%
% Each channel field contains:
%   - x, y, and optionally z
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
    region_section  = ['viewer.' current_region];

    channel_list_raw = ini_get(viewer_ini, region_section, 'channel_list');
    channel_list = split_semicolon_list(channel_list_raw);

    region_name = strtrim(ini_get(viewer_ini, region_section, 'name'));
    meta_path = fullfile(folder_path, [region_name '.ini']);
    meta_ini = read_ini_file(meta_path);

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

        name   = strtrim(ini_get(viewer_ini, channel_section, 'name'));
        width  = str2double(ini_get(viewer_ini, channel_section, 'width'));
        depth  = str2double(ini_get(viewer_ini, channel_section, 'depth'));
        height = str2double(ini_get(viewer_ini, channel_section, 'height'));

        % Axes from the region metadata ini
        thx_low  = str2double(ini_get(meta_ini, 'Run Mode Information', 'Thetax_Low'));
        thx_high = str2double(ini_get(meta_ini, 'Run Mode Information', 'Thetax_High'));
        thy_low  = str2double(ini_get(meta_ini, 'Run Mode Information', 'Thetay_Low'));
        thy_high = str2double(ini_get(meta_ini, 'Run Mode Information', 'Thetay_High'));
        e_low    = str2double(ini_get(meta_ini, 'SES', 'Low Energy'));
        e_high   = str2double(ini_get(meta_ini, 'SES', 'High Energy'));

        angles_x = linspace(thx_low, thx_high, width);
        angles_y = linspace(thy_low, thy_high, depth);
        energies = linspace(e_low, e_high, height);

        % Read binary data
        values = read_binary_data(data_path);

        % Match NumPy reshape(order='C') behaviour used in the Python code
        if depth == 1
            % Python:
            % values.reshape(height, width)
            %
            % MATLAB equivalent:
            % reshape to [width, height] then transpose
            value = reshape(values, [width, height]).';

            out = struct();
            out.x = angles_x;     % cut direction
            out.y = energies;
            out.value = value;

        else
            % Python:
            % values.reshape(depth, width, height)
            %
            % MATLAB equivalent:
            % reshape to [height, width, depth] then permute
            value = reshape(values, [height, width, depth]);
            value = permute(value, [3 2 1]);

            out = struct();
            out.x = angles_y;
            out.y = angles_x;    % cut direction
            out.z = energies;
            out.value = value;
        end

        out.region = current_region;
        out.channel = channel;
        out.name = name;
        out.path = data_rel;

        fieldname = matlab.lang.makeValidName(sprintf('%s_%s_%s', current_region, channel, name));
        if isfield(DATA, fieldname)
            fieldname = matlab.lang.makeValidName(sprintf('%s_%s_%s_%d', current_region, channel, name, i));
        end

        DATA.(fieldname) = out;

        % Also create a variable in the base workspace
        [~, file_stem, ~] = fileparts(file_path);
        base_var_name = matlab.lang.makeValidName([file_stem '_' channel]);
        assignin('base', base_var_name, OxA_CUT(out));
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