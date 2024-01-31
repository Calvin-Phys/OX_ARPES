function CUT = load_Soleil_Cassiopee(file_path)
    % Load 2D data from a Scienta text file and return an OxA_CUT object

    % Open the file and read all lines
    fileID = fopen(file_path);
    raw_lines = textscan(fileID, '%s', 'Delimiter', '\n');
    fclose(fileID);
    lines = raw_lines{1};

    % Find the line starting with 'Dimension 1 scale=' and extract the y scale
    y_line = lines{find(startsWith(lines, 'Dimension 1 scale='), 1)};
    y = sscanf(y_line(19:end), '%f')';

    % Find the line starting with 'Dimension 2 scale=' and extract the x scale
    x_line = lines{find(startsWith(lines, 'Dimension 2 scale='), 1)};
    x = sscanf(x_line(19:end), '%f')';

    % Find the line starting with 'Dimension 2 scale=' and extract the x scale
    hv_line = lines{find(startsWith(lines, 'Excitation Energy='), 1)};
    hv = sscanf(hv_line(19:end), '%f');

    % Find the line starting with 'location=' and extract the beamline name
    bmln_line = lines{find(startsWith(lines, 'Location='), 1)};
    bmln = bmln_line(10:end);

    % Find the index of the line starting with '[Data', indicating the start of the data section
    data_start_idx = find(startsWith(lines, '[Run Mode Information'), 1) + 3;

    % Initialize the 'value' matrix and read the data from the lines
    value = zeros(length(x), length(y));
    for i = 1:length(y)
        data_line = sscanf(lines{data_start_idx + i}, '%f');
        value(:, i) = data_line(2:end);
    end

    % Create an OxA_CUT object with the extracted data (x, y, value)
    CUT = OxA_CUT(x', y', value);
    CUT.info.photon_energy = hv;
    CUT.info.workfunction = 4.21; 
%     switch bmln
%         case {'MAXIV','Bloch'}
%             CUT.info.beamline = 'MAXIV_Bloch';
%             x = [25 50 60 110 160 170];
%             y = [4.3907 4.4095 4.4133 4.4667 4.5164 4.5193];
%             CUT.info.workfunction = interp1(x,y,hv,'spline','extrap'); 
%         otherwise
%             CUT.info.workfunction = 4.44; 
%     end

    %% open and read the parameters
    % Open the file and read all lines
    para_path = strrep (file_path,'ROI1_','i');
    fileID = fopen(para_path);
    raw_lines = textscan(fileID, '%s', 'Delimiter', '\n');
    fclose(fileID);
    lines = raw_lines{1};

    x_line = lines{find(startsWith(lines, 'x (mm) :'), 1)};
    CUT.info.sample_X = sscanf(x_line(10:end), '%f')';

    y_line = lines{find(startsWith(lines, 'y (mm) :'), 1)};
    CUT.info.sample_Y = sscanf(y_line(10:end), '%f')';

    z_line = lines{find(startsWith(lines, 'z (mm) :'), 1)};
    CUT.info.sample_Z = sscanf(z_line(10:end), '%f')';

    theta_line = lines{find(startsWith(lines, 'theta (deg) :'), 1)};
    CUT.info.sample_theta = sscanf(theta_line(14:end), '%f')';

    phi_line = lines{find(startsWith(lines, 'phi (deg) :'), 1)};
    CUT.info.sample_phi = sscanf(phi_line(12:end), '%f')';

    tilt_line = lines{find(startsWith(lines, 'tilt (deg) :'), 1)};
    CUT.info.sample_tilt = sscanf(tilt_line(13:end), '%f')';

    pressure_line = lines{find(startsWith(lines, 'P(mbar) :'), 1)};
    CUT.info.vacuum_pressure = sscanf(pressure_line(11:end), '%f')';

    hv_line = lines{find(startsWith(lines, 'hv (eV) :'), 1)};
    CUT.info.photon_energy = sscanf(hv_line(11:end), '%f')';

    polarization_line = lines{find(startsWith(lines, 'Polarisation [0:LV, 1:LH, 2:AV, 3:AH, 4:CR] :'), 1)};
    PL = polarization_line(end);
    switch PL
        case '0'
            CUT.info.polarization = 'LV';
        case '1'
            CUT.info.polarization = 'LH';
        case '2'
            CUT.info.polarization = 'AV';
        case '3'
            CUT.info.polarization = 'AH';
        case '4'
            CUT.info.polarization = 'CR';
    end

    % remove spikes
    CUT.value = medfilt1(CUT.value,2,[],1);
    CUT.value = medfilt1(CUT.value,2,[],2);


end