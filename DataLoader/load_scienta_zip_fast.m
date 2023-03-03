function MAP = load_scienta_zip_fast(file_path)

    [path, file, ext] = fileparts(file_path);
    folder_path = fullfile(path,[file '_tmp']);
    viewer_path = fullfile(folder_path, 'viewer.ini');

    unzip(file_path,folder_path);

    % extract data header
    fileID = fopen(viewer_path);
    tline = fgetl(fileID);

    while ~startsWith(tline,'width=')
        tline = fgetl(fileID);
    end
    nz = str2num(tline(7:end));
    tline = fgetl(fileID);
    ny = str2num(tline(8:end));
    tline = fgetl(fileID);
    nx = str2num(tline(7:end));

    while ~startsWith(tline,'path=')
        tline = fgetl(fileID);
    end
    bin_path = fullfile(folder_path, tline(6:end));
    tline = fgetl(fileID);

    z0 = str2double(tline(14:end));
    tline = fgetl(fileID);
    dz = str2double(tline(13:end));
    tline = fgetl(fileID);
    tline = fgetl(fileID);

    y0 = str2double(tline(15:end));
    tline = fgetl(fileID);
    dy = str2double(tline(14:end));
    tline = fgetl(fileID);
    tline = fgetl(fileID);

    x0 = str2double(tline(14:end));
    tline = fgetl(fileID);
    dx = str2double(tline(13:end));

    fclose(fileID);


    fileID = fopen([bin_path(1:end-3) 'ini']);
    tline = fgetl(fileID);
    while ~startsWith(tline,'byteperpoint=')
        tline = fgetl(fileID);
    end
    nUnit = str2double(tline(14:end));
    fclose(fileID);
    if nUnit == 4
        Precision = 'single';
    elseif nUnit == 8
        Precision = 'double';
    end

    fileID = fopen(bin_path);
    value = fread(fileID, Precision);
    fclose(fileID);


    z = (1:nz)*dz + z0;
    y = (1:ny)*dy + y0;
    x = (1:nx)*dx + x0;
    value = reshape(value,[nz,ny,nx]);
    value = permute(value,[3 2 1]);
    
    MAP = OxA_MAP(x,y,z,value);
    MAP = MAP.set_contrast();

    while ~rmdir(folder_path,'s')
        pause(0.01);
    end
end

