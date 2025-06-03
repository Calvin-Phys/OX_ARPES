function DATA = load_ALBA_krx(filename, v_3Dflag)
% LOAD_KRX_DEFLECTOR_MAP Load Scienta Omicron .krx files with 2D or 3D output
%
% Usage:
%   krx = load_krx_deflector_map('file.krx', 0);  % for 2D output
%   krx = load_krx_deflector_map('file.krx', 1);  % for 3D stack
%
% Output:
%   krx - struct with image(s), metadata, axis scaling, and options

    if nargin < 2
        v_3Dflag = 0;
    end

    krx = struct();
    fid = fopen(filename, 'rb');
    assert(fid > 0, 'Could not open file.');

    % -- Detect 64-bit or 32-bit pointer array --
    fseek(fid, 4, 'bof');
    v0 = fread(fid, 1, 'uint32=>uint32');
    Is64bit = (v0 == 0);
    krx.is64bit = Is64bit;

    % -- Read first pointer triplet to get n_images and dimensions --
    fseek(fid, 0, 'bof');
    if Is64bit
        ptr_type = 'uint64=>uint64';
        v1 = fread(fid, 1, ptr_type);
        n_images = double(v1 / 3);
        fseek(fid, 8, 'bof'); image_pos = fread(fid, 1, ptr_type);
        fseek(fid, 16, 'bof'); image_sizeY = fread(fid, 1, ptr_type);
        fseek(fid, 24, 'bof'); image_sizeX = fread(fid, 1, ptr_type);
    else
        ptr_type = 'uint32=>uint32';
        v1 = fread(fid, 1, ptr_type);
        n_images = double(v1 / 3);
        fseek(fid, 4, 'bof'); image_pos = fread(fid, 1, ptr_type);
        fseek(fid, 8, 'bof'); image_sizeY = fread(fid, 1, ptr_type);
        fseek(fid, 12, 'bof'); image_sizeX = fread(fid, 1, ptr_type);
    end
    krx.n_images = n_images;
    krx.sizeX = image_sizeX;
    krx.sizeY = image_sizeY;

    % -- Read first image header --
    header_offset = (double(image_pos) + image_sizeX * image_sizeY + 1) * 4;
    fseek(fid, header_offset, 'bof');
    header_raw = fread(fid, 4096, '*char')';
    header_str = string(header_raw);
    data_idx = strfind(header_str, 'DATA:');
    if isempty(data_idx)
        header_short = header_str;
    else
        header_short = extractBefore(header_str, data_idx);
    end
    % header_short = header_str;

    krx.header = header_short;

    % -- Parse metadata --
    lines = regexp(header_short, '\r\n|\n|\r', 'split');
    metadata = struct();
    for i = 1:numel(lines)
        parts = split(lines(i), '	');
        if numel(parts) == 2
            key = matlab.lang.makeValidName(strtrim(parts{1}));
            val = strtrim(parts{2});
            numval = str2double(val);
            if ~isnan(numval)
                metadata.(key) = numval;
            else
                metadata.(key) = val;
            end
        end
    end
    krx.metadata = metadata;

    % -- Extract axes from metadata --
    if isfield(metadata, 'StartK_E_') && isfield(metadata, 'EndK_E_')
        e0 = metadata.StartK_E_;
        e1 = metadata.EndK_E_;
    else
        e0 = 0; e1 = image_sizeX - 1;
    end

    if isfield(metadata, 'ScaleMin') && isfield(metadata, 'ScaleMax')
        x0 = metadata.ScaleMin;
        x1 = metadata.ScaleMax;
    elseif isfield(metadata, 'XScaleMin') && isfield(metadata, 'XScaleMax')
        x0 = metadata.XScaleMin;
        x1 = metadata.XScaleMax;
    else
        x0 = 0; x1 = image_sizeY - 1;
    end

    if isfield(metadata, 'MapStartX') && isfield(metadata, 'MapEndX')
        y0 = metadata.MapStartX;
        y1 = metadata.MapEndX;
    elseif isfield(metadata, 'YScaleMin') && isfield(metadata, 'YScaleMax')
        y0 = metadata.YScaleMin;
        y1 = metadata.YScaleMax;
    else
        y0 = 0; y1 = 1;
    end

    % -- Allocate output image or cube --
    if v_3Dflag && n_images > 1
        image_cube = zeros(image_sizeY, n_images, image_sizeX, 'single');
    else
        image_list = cell(1, n_images);
    end

    % -- Allocate read buffer --
    databuffer = zeros(image_sizeY, image_sizeX, 'single');

    % -- Loop over each image --
    for ii = 0:n_images-1
        if Is64bit
            fseek(fid, (ii*3 + 1) * 8, 'bof');
            image_pos = fread(fid, 1, 'uint64=>uint64');
        else
            fseek(fid, (ii*3 + 1) * 4, 'bof');
            image_pos = fread(fid, 1, 'uint32=>uint32');
        end

        % -- Read image data --
        fseek(fid, double(image_pos) * 4, 'bof');
        raw = fread(fid, image_sizeX * image_sizeY, 'float32=>single');
        databuffer(:,:) = reshape(raw, [image_sizeX, image_sizeY])';

        % -- Store image --
        if v_3Dflag && n_images > 1
            image_cube(:, ii+1, :) = databuffer;
        else
            image_list{ii+1} = databuffer;
        end
    end

    fclose(fid);

    % -- Output data --
    if v_3Dflag && n_images > 1
        krx.image = image_cube;
    else
        krx.image = image_list{1};
    end

    krx.energy = linspace(e0, e1, image_sizeX);
    krx.angle = linspace(x0, x1, image_sizeY);
    krx.deflector = [y0, y1];  % optional 3rd axis scaling

    DATA = OxA_CUT(krx.angle, krx.energy, krx.image);

    DATA.info = krx.metadata;
    DATA.x_name = 'Angle';
    DATA.x_unit = 'Deg';
    DATA.y_name = 'Kinetic Energy';
    DATA.y_unit = 'eV';

end
