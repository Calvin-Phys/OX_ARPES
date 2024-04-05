function DATA = load_Specs_itx(file_path)
% The function load_SPECS_itx(filepath) is designed
% to load the SPECS Prodigy itx data files into the workspace.
% Input varargin{1} is a string that contain the full filename
% with its path
% by Jiabao Yang, jiabao.yang@mpi-halle.mpg.de

%start reading
fid = fopen(file_path);

% define empty cell_data for main data
cell_data = {};
% define empty info.struct for infomation
info= struct();
% define inital logical number
start_reading_data = false;

% start loading
line = fgetl(fid);  
while ischar(line)  % 当还有数据时
    if startsWith(line, 'X //Acquisition Parameters:')
        start_reading_data = true;
    end    
    % 开始读取头文件
    if start_reading_data
        if contains(line, '//') && contains(line, '=')
            [key, value] = strtok(line, '=');
            key = regexprep(key, '[^a-zA-Z0-9_]', '_');
            value = strtrim(value(2:end));  
            % 将键和值存储到结构体中
            info.(key) = value;
        end
        if startsWith(line, 'WAVES')
            % 使用正则表达式匹配行内括号中的数值
            tokens = regexp(line, '\((\d+(?:,\d+)*)\)', 'tokens');
            % 如果找到匹配项
            if ~isempty(tokens)
                % 提取括号中的数值
                dims = str2double(strsplit(tokens{1}{1}, ','));
                % 存储到结构体中
                info.WAVES_dims = dims;
            end
        end
    end
    if strcmp(line, 'BEGIN')  % 如果遇到 "BEGIN"，开始提取数据
        data_row = {};  % 初始化一个新的数据行
        line = fgetl(fid);  % 读取下一行数据
        while ~strcmp(line, 'END') && ischar(line)  % 当不是 "END" 且还有数据时
            if isempty(line)
                % 如果是空行，创建一个新行
                cell_data{end+1} = data_row;  % 添加之前的数据行到 cell 数组
                data_row = {};  % 创建一个新的数据行
            else
                % 如果不是空行，将数据添加到当前行
                data_row{end+1} = str2num(line);  % 将子元素添加到当前行
            end
            line = fgetl(fid);  % 读取下一行数据
        end
        % 添加最后一行数据到 cell 数组
        cell_data{end+1} = data_row;
    end
    if strcmp(line, 'END') %如果遇到end
        line = fgetl(fid);
        while start_reading_data && ~isequal(line, -1)
            tokens = regexp(line, 'X SetScale/I\s+(\w+),\s*([^,]+),\s*([^,]+),\s*"([^"]+)",\s*''([^'']+)''', 'tokens');
%             disp(tokens)
            if ~isempty(tokens)
    %             提取双引号内的字符串和等号后的数值部分
                field_name = tokens{1}{4};
                field_name = regexprep(field_name, '[^a-zA-Z0-9_]', '_');
                value_str1 = tokens{1}{2}; 
                value_str2 = tokens{1}{3};   % 数值部分字符串
                info.(field_name) = [str2double(value_str1), str2double(value_str2)];
            end
            line = fgetl(fid);

        end
    end
    line = fgetl(fid);  % 读取下一行数据
end

% 关闭文件
fclose(fid);


% disp(cell_data);
% disp(info);
all_fields = fieldnames(info);
idx_waves_dims = find(strcmp(all_fields, 'WAVES_dims'));

%判断是cut还是fs文件
channel = info.WAVES_dims;
if numel(channel) == 1 %spin_data_1D
    x_dim = channel(1);
    if idx_waves_dims < numel(all_fields)
        % 获取 WAVES_dims 后面的字段名
        desired_field = all_fields{idx_waves_dims + 1};
        % 然后使用该字段名来读取对应的值
        x_boundry = info.(desired_field);
    end
    x = linspace(x_boundry(1), x_boundry(2), x_dim);
    matrix_data = cell_data{1};
    DATA = struct('value', matrix_data, 'x', x);
elseif numel(channel) == 2  % cut
    x_dim = channel(1);
    z_dim = channel(2);
    if idx_waves_dims < numel(all_fields)
        % 获取 WAVES_dims 后面的字段名
        desired_field = all_fields{idx_waves_dims + 1};
        % 然后使用该字段名来读取对应的值
        x_boundry = info.(desired_field);
        % 继续找下一个字段
        desired_field = all_fields{idx_waves_dims + 2};
        z_boundry = info.(desired_field);
    end

    x = linspace(x_boundry(1), x_boundry(2), x_dim);
    z = linspace(z_boundry(1), z_boundry(2), z_dim);
    matrix_data = zeros(x_dim, z_dim);
    current_element = cell_data{1};
    for i = 1:x_dim
        matrix_data(i, :) = current_element{i};
    end
    DATA = OxA_CUT(x,z,matrix_data);
    DATA.info.raw = info;

elseif numel(channel) == 3  %FS
    x_dim = channel(1);
    z_dim = channel(2);
    y_dim = channel(3);
    if idx_waves_dims < numel(all_fields)
        % 获取 WAVES_dims 后面的字段名
        desired_field = all_fields{idx_waves_dims + 1};
        % 然后使用该字段名来读取对应的值
        x_boundry = info.(desired_field);
        % 继续找下一个字段
        desired_field = all_fields{idx_waves_dims + 2};
        z_boundry = info.(desired_field);
        % 继续找下一个字段
        desired_field = all_fields{idx_waves_dims + 3};
        y_boundry = info.(desired_field);
    end
    x = linspace(x_boundry(1), x_boundry(2), x_dim);
    z = linspace(z_boundry(1), z_boundry(2), z_dim);
    y = linspace(y_boundry(1), y_boundry(2), y_dim);
    matrix_data = zeros(x_dim, z_dim, numel(cell_data));
    for i = 1:numel(cell_data)
        matrix_data(:, :, i) = cell2mat(cell_data{i}');
    end
    matrix_data_transposed = permute(matrix_data, [1, 3, 2]);
    DATA = OxA_MAP(x,y,z,matrix_data_transposed);
    DATA.info.raw = info;
end

    DATA.info.photon_energy = info.X___Excitation_Energy_;
    DATA.info.workfunction = 0;
    DATA.info.pass_energy = info.X___Pass_Energy_______;
    DATA.info.acquisition_mode = info.X___Scan_Mode_________;

end