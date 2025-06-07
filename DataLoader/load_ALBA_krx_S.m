function DATA = load_ALBA_krx_S(filename)
% LOAD_KRX_DEFLECTOR_MAP Load Scienta Omicron .krx files with 2D or 3D output
%
% Usage:
%   krx = load_krx_deflector_map('file.krx', 0);  % for 2D output
%   krx = load_krx_deflector_map('file.krx', 1);  % for 3D stack
%
% Output:
%   krx - struct with image(s), metadata, axis scaling, and options

    krx = struct();
    fid = fopen(filename, 'rb');
    assert(fid > 0, 'Could not open file.');

    % part credit to HK Chen
    % --- Step 1: Read PAS ---
    fseek(fid, 0, 'bof');       % Move to end of file
    PAS = fread(fid, 1, 'uint64');  % Number of 64-bit words in pointer array
    
    % --- Step 2: Read Image Pointers and Sizes ---
    ptrs = zeros(PAS/3, 3);  % [Ptr, Y size, X size] for each image
    for i = 1:PAS/3
        ptrs(i,1) = fread(fid, 1, 'uint64');  % Ptr
        ptrs(i,2) = fread(fid, 1, 'uint64');  % Y size
        ptrs(i,3) = fread(fid, 1, 'uint64');  % X size
    end
    
    krx.n_images = PAS/3;
    krx.sizeX = ptrs(1,3);
    krx.sizeY = ptrs(1,2);

    % --- Step 3: Read Dimension Size, L, MSA entries ---
    krx.dimSize = fread(fid, 1, 'uint64'); % 4 - ARPES, 5 - SPIN
    krx.L = fread(fid, 1, 'uint64');
    krx.msa = fread(fid, krx.L, 'uint64');

    % --- Step 4: Read image #0 using its pointer ---
%     image0_offset = ptrs(1,1);  % in 64-bit words
%     fseek(fid, image0_offset * 4, 'bof');  % convert to bytes
%     ysize = ptrs(1,2);
%     xsize = ptrs(1,3);
%     % Read float32 image data (assuming row-major, as implied)
%     image0_data = fread(fid, [xsize, ysize], 'float32');
%     image0_data = image0_data';  % transpose for (y,x) display
    
    % --- Optional: Read text header after image0 ---
    % (Assuming it's right after image0 data)
    header_offset = (double(ptrs(1,1)) + ptrs(1,2)*ptrs(1,3) + 1) *4;
    fseek(fid, header_offset, 'bof');
    header_raw = fread(fid, 2048, '*char')';

    header_str = string(header_raw);
    data_idx = strfind(header_str, 'DATA:');
    if isempty(data_idx)
        header_short = header_str;
    elseif size(data_idx) == 1
        header_short = extractBefore(header_str, data_idx);
    else
        header_short = extractBefore(header_str, data_idx(1));
    end
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
        e0 = 0; e1 = krx.sizeX - 1;
    end

    if isfield(metadata, 'ScaleMin') && isfield(metadata, 'ScaleMax')
        x0 = metadata.ScaleMin;
        x1 = metadata.ScaleMax;
%     elseif isfield(metadata, 'XScaleMin') && isfield(metadata, 'XScaleMax')
%         x0 = metadata.XScaleMin;
%         x1 = metadata.XScaleMax;
    else
        x0 = 0; x1 = krx.sizeY - 1;
    end

%     if isfield(metadata, 'MapStartX') && isfield(metadata, 'MapEndX')
%         y0 = metadata.MapStartX;
%         y1 = metadata.MapEndX;
%     elseif isfield(metadata, 'YScaleMin') && isfield(metadata, 'YScaleMax')
%         y0 = metadata.YScaleMin;
%         y1 = metadata.YScaleMax;
%     else
%         y0 = 0; y1 = 1;
%     end

    % spin components
    field = {'SpinComp_0','SpinComp_1','SpinComp_2','SpinComp_3','SpinComp_4','SpinComp_5','SpinComp_6','SpinComp_7'};
    TF = isfield(metadata,field); 


    % -- Allocate output image or cube --
    image_cube = zeros(krx.sizeX, krx.sizeY, krx.n_images, 'single');

    % -- Allocate read buffer --
    databuffer = zeros(krx.sizeY, krx.sizeX, 'single');

    % -- Loop over each image --
    for ii = 0:(krx.n_images-1)
        fseek(fid, (ii*3 + 1) * 8, 'bof');
        image_pos = fread(fid, 1, 'uint64=>uint64');

        % -- Read image data --
        fseek(fid, double(image_pos) * 4, 'bof');
        raw = fread(fid, krx.sizeX * krx.sizeY, 'float32=>single');
        databuffer(:,:) = reshape(raw, [krx.sizeX, krx.sizeY])';

        % -- Store image --
        image_cube(:, :, ii+1) = databuffer;
    end

    fclose(fid);

    % -- Output data --
    krx.image = permute(reshape(image_cube,[krx.msa(1)*krx.msa(2), krx.msa(3)*krx.msa(4), krx.msa(5)]),[3 2 1]);


    krx.energy = linspace(e0, e1, krx.msa(1)*krx.msa(2));
    krx.angle = linspace(x0, x1, krx.msa(3)*krx.msa(4));
    krx.spin = 1:krx.msa(5);  % optional 3rd axis scaling

    DATA = OxA_MAP(krx.spin, krx.angle, krx.energy, krx.image);

    DATA.info = krx.metadata;
    DATA.x_name = 'Spin';
    DATA.x_unit = 'XYZ';
    DATA.y_name = 'Angle';
    DATA.y_unit = 'Deg';
    DATA.z_name = 'Kinetic Energy';
    DATA.z_unit = 'eV';

end
