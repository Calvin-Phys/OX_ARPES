function DATA = load_DLS_io5(file_path)
%LOAD_DLS_IO5 Summary of this function goes here
%   Detailed explanation goes here
    
    %   -------------------------
    try
        title = h5read(file_path,'/entry1/title');
    catch
        title = h5read(file_path,'/entry1/scan_command');
    end

    try
        value = double(h5read(file_path,'/entry1/analyser/data'));
    catch
    end

    photon_energy = h5read(file_path,'/entry1/instrument/monochromator/energy');
    pass_energy = h5read(file_path,'/entry1/instrument/analyser/pass_energy');

    try
        end_time = h5read(file_path,'/entry1/end_time');
        if isempty(end_time)
            end_time = h5read(file_path,'/entry1/start_time');
        end
    
        try
            t = datetime(end_time,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS''Z');
        catch
            end_time1 = strsplit(end_time,'+');
            t = datetime(end_time1{1},'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSS');
        end
    
        % the work function can change after certain period of time
        if year(t) <= 2020
            x = [120 144 176 200];
            y = [0.5791 0.4390 0.1696 -0.0296] + 4.5;
            workfunction = interp1(x,y,photon_energy,'spline','extrap');
        elseif year(t)<2023
            if month(t) > 6
                % 2022 11
                workfunction = 5.77602E-6 *photon_energy.^2 + 1.23949E-3 *photon_energy + 4.4144;
            else
                % 2022 5
                x = [30 40 60 90 120 150 180 200];
                y = 4.5 + [0.0942 0.0942 0.0933 0.0927 0.0966 0.0994 0.0685 0.0713];
                workfunction = interp1(x,y,photon_energy,'makima','extrap');
            end
        elseif year(t)<2024
        % 2023
            workfunction = -2.505295708E-10 *photon_energy.^4 +5.376936163E-8 *photon_energy.^3 +9.213495312E-9 *photon_energy.^2  - 0.000146349 *photon_energy +4.443810286;
        elseif year(t)<2025
            % 2024Feb
            x = [30 54 60 90 120 150 180 200];
            y = 4.5 - [0.0847 0.0847 0.0889 0.0927 0.1079 0.1014 0.1106 0.1068];
            % x = [42 60 90 120 150 180 201];
            % y = 4.5 - [0.0581 0.0585 0.0643 0.0559 0.0313 0.0176 0.0126];
            workfunction = interp1(x,y,photon_energy,'makima','extrap');
            % workfunction = 4.5 + 0.*photon_energy;
        else
            x = [20 40 60 80 100 120 140 160];
            y = 4.5 - [0.034 0.0239 0.0067 -0.0023 -0.0184 -0.0505 -0.0738 -0.123];
            workfunction = interp1(x,y,photon_energy,'makima','extrap');
            workfunction = 4.45 + 0.*photon_energy;
        end
    catch
        workfunction = 4.8;
    end

    if contains(title,'static readout')
        
        try 
            x = h5read(file_path,'/entry1/analyser/angles');
            y = h5read(file_path,'/entry1/analyser/energies');
            
            DATA = OxA_CUT(x,y,value');
        catch
            x = h5read(file_path,'/entry1/analyser/location');
            y = h5read(file_path,'/entry1/analyser/energies');
            
            DATA = OxA_CUT(x,y,value');
            DATA.x_name = 'Location';
            DATA.x_unit = 'mm';
        end

        
    elseif contains(title,'scan pathgroup')
        value = permute(value,[3,2,1]);
        x = h5read(file_path,'/entry1/analyser/sapolar');
        y = h5read(file_path,'/entry1/analyser/angles');
        z = h5read(file_path,'/entry1/analyser/energies');
        DATA = OxA_MAP(x,y,z,value);
%         DATA = DATA.set_contrast();
    elseif contains(title,'scan scan_group')
        value = permute(value,[3,2,1]);
        x = h5read(file_path,'/entry1/analyser/sapolar');
        y = h5read(file_path,'/entry1/analyser/angles');
        z = mean(h5read(file_path,'/entry1/analyser/energies'),2);
        DATA = OxA_MAP(x,y,z,value);
    elseif contains(title,'scan deflector_x')
        value = permute(value,[3,2,1]);
        x = h5read(file_path,'/entry1/analyser/deflector_x');
        y = h5read(file_path,'/entry1/analyser/angles');
        z = mean(h5read(file_path,'/entry1/analyser/energies'),2);
        DATA = OxA_MAP(x,y,z,value);
%         DATA = DATA.set_contrast();

    % polar map
    elseif contains(title,'scan sapolar')
        value = permute(value,[3,2,1]);
        x = h5read(file_path,'/entry1/analyser/sapolar');
        y = h5read(file_path,'/entry1/analyser/angles');
        z = h5read(file_path,'/entry1/analyser/energies');
        DATA = OxA_MAP(x,y,z,value);

    % old KZ scan
    elseif contains(title,'scan energy_group')
        value = flip(permute(value,[3,2,1]),1);
        x = flip(h5read(file_path,'/entry1/analyser/value'));
        y = h5read(file_path,'/entry1/analyser/angles');

        ZZ = h5read(file_path,'/entry1/analyser/energies');
        HHVV = repmat(x',size(ZZ,1),1);
%         WW = repmat(workfunction',size(ZZ,1),1);
        z = mean(ZZ - HHVV,2) + workfunction;

        DATA = OxA_KZ(x,y,z,value);
%         DATA = DATA.set_contrast();

    % new KZ scan
    elseif contains(title,'scan energy') && ~contains(title,'scan energy_group')
        value = permute(value,[3,2,1]);
        x = transpose(h5read(file_path,'/entry1/analyser/energy'));
        y = transpose(h5read(file_path,'/entry1/analyser/angles'));

        ZZ = h5read(file_path,'/entry1/analyser/energies');
        HHVV = repmat(photon_energy',size(ZZ,1),1);
        WW = repmat(workfunction',size(ZZ,1),1);

        %% interpolate
        ZZ_mean_dz = mean(ZZ,2);
        nz = length(ZZ_mean_dz);
        P = polyfit(1:nz,ZZ_mean_dz,1);
        dz = P(1);

        % photon_energy
        % workfunction
        EEF = ZZ - (HHVV - WW);
        EEF_min = min(EEF,[],"all");
        EEF_max = max(EEF,[],"all");
        EEF_new = EEF_min:dz:EEF_max;

        [EEFF, YY] = meshgrid(EEF_new,y);

        VALUE_NEW = zeros(length(x),length(y),length(EEF_new));
        for i = 1:length(x)
            VALUE_NEW(i,:,:) = interp2(EEF(:,i),y,squeeze(value(i,:,:)),EEFF,YY,'spline',0);
        end
        DATA = OxA_KZ(x,y,EEF_new,VALUE_NEW);
        %         DATA = DATA.set_contrast();


    elseif contains(title,'scan say')
        x = flip(h5read(file_path,'/entry1/analyser/say'));
        value = h5read(file_path,'/entry1/analyser/analyser');
        DATA = OxArpes_1D_Data(x,value);
        DATA.x_name = 'say';
        DATA.x_unit = 'mm';
    elseif contains(title,'scan sax')
        x = flip(h5read(file_path,'/entry1/analyser/sax'));
        try
            value = h5read(file_path,'/entry1/analyser/analyser');
        catch
            value = double(h5read(file_path,'/entry1/analyser/data'));
            value = sum(value, [1 2]);
            value = value(:);
        end
        DATA = OxArpes_1D_Data(x,value);
        DATA.x_name = 'sax';
        DATA.x_unit = 'mm';
    elseif contains(title,'scan salong')
        x = flip(h5read(file_path,'/entry1/analyser/salong'));
        try
            value = h5read(file_path,'/entry1/analyser/analyser');
        catch
            value = double(h5read(file_path,'/entry1/analyser/data'));
            value = sum(value, [1 2]);
            value = value(:);
        end
        DATA = OxArpes_1D_Data(x,value);
        DATA.x_name = 'salong';
        DATA.x_unit = 'mm';
    elseif (contains(title,'scan sax') && contains(title,'saz'))
        x = mean(flip(h5read(file_path,'/entry1/analyser/sax')),1)';
        y = mean(h5read(file_path,'/entry1/analyser/saz'),2);
        z = mean(h5read(file_path,'/entry1/analyser/energies'),[2 3]);
        value = squeeze(sum(h5read(file_path,'/entry1/analyser/data'),2));
        value = permute(value,[3,2,1]);
        DATA = OxA_RSImage(x,y,z,value);
        DATA.x_name = 'sax';
        DATA.x_unit = 'mm';
        DATA.y_name = 'saz';
        DATA.y_unit = 'mm';
        DATA.z_name = 'kinetic Energy';
        DATA.z_unit = 'eV';

        % save 4D data
        DATA_4D.x = x;
        DATA_4D.y = y;
        DATA_4D.z = z;
        DATA_4D.k = h5read(file_path,'/entry1/analyser/angles');
        DATA_4D.value = permute(h5read(file_path,'/entry1/analyser/data'),[4 3 2 1]);
        [~, varname, ~] = fileparts(file_path);
        varname = strrep(varname,'-','_');
        assignin('base',append('DATA_4D_',varname),DATA_4D);
    elseif (contains(title,'scan saz') && contains(title,'sax'))
        x = mean(flip(h5read(file_path,'/entry1/analyser/sax')),2)';
        y = mean(h5read(file_path,'/entry1/analyser/saz'),1);
        z = mean(h5read(file_path,'/entry1/analyser/energies'),[2 3]);
        value = squeeze(sum(h5read(file_path,'/entry1/analyser/data'),2));
        value = permute(value,[3,2,1]);
        DATA = OxA_RSImage(x,y,z,value);
        DATA.x_name = 'sax';
        DATA.x_unit = 'mm';
        DATA.y_name = 'saz';
        DATA.y_unit = 'mm';
        DATA.z_name = 'kinetic Energy';
        DATA.z_unit = 'eV';

        % save 4D data
        DATA_4D.x = x;
        DATA_4D.y = y;
        DATA_4D.z = z;
        DATA_4D.k = h5read(file_path,'/entry1/analyser/angles');
        DATA_4D.value = permute(h5read(file_path,'/entry1/analyser/data'),[3 4 2 1]);
        DATA_4D.value = medfilt1(DATA_4D.value,5,[],3);
        DATA_4D.value = medfilt1(DATA_4D.value,5,[],4);
        assignin('base',append('DATA_4D_',string(t,'HH_mm_ss')),DATA_4D);
    else
        DATA = [];
    end

    % ------- add Info
    DATA.info.workfunction = workfunction;
    DATA.info.photon_energy = h5read(file_path,'/entry1/instrument/monochromator/energy');
    DATA.info.polarization = h5read(file_path,'/entry1/instrument/insertion_device/beam/final_polarisation_label');
    DATA.info.acquisition_mode = h5read(file_path,'/entry1/instrument/analyser/acquisition_mode');
    try
        DATA.info.acquire_time = h5read(file_path,'/entry1/instrument/analyser/acquire_time');
    catch
    end
    DATA.info.pass_energy = h5read(file_path,'/entry1/instrument/analyser/pass_energy');
    try
        DATA.info.center_energy = h5read(file_path,'/entry1/instrument/analyser/kinetic_energy_center');
    catch
    end
    DATA.info.temperature = h5read(file_path,'/entry1/sample/temperature');
    DATA.info.exit_slit = h5read(file_path,'/entry1/instrument/monochromator/exit_slit_size');
    
    DATA.info.sample_X = h5read(file_path,'/entry1/instrument/manipulator/sax');
    DATA.info.sample_Y = h5read(file_path,'/entry1/instrument/manipulator/say');
    DATA.info.sample_Z = h5read(file_path,'/entry1/instrument/manipulator/saz');
    DATA.info.sample_polar = h5read(file_path,'/entry1/instrument/manipulator/sapolar');
    DATA.info.sample_tilt = h5read(file_path,'/entry1/instrument/manipulator/satilt');
    DATA.info.sample_azimuth = h5read(file_path,'/entry1/instrument/manipulator/saazimuth');

    try
        DATA.info.time_measured = t;
    catch
    end
    DATA.info.time_loaded = datetime("now");
    DATA.info.beamline = 'DLS_i05_HR';

%     remove spikes
    if (strcmp(DATA.info.acquisition_mode,'Fixed') || strcmp(DATA.info.acquisition_mode,'Dither')) && ( strcmp(class(DATA),'OxA_MAP') || strcmp(class(DATA),'OxA_CUT') || strcmp(class(DATA),'OxA_KZ') )
        switch ndims(value)
            case 2
                DATA.value = medfilt1(DATA.value,3,[],1);
                DATA.value = medfilt1(DATA.value,3,[],2);
            case 3
                DATA.value = medfilt1(DATA.value,3,[],2);
                DATA.value = medfilt1(DATA.value,3,[],3);
%                 DATA.value = filloutliers(DATA.value,'linear','mean',3);
%                 DATA.value(:,17,91) = zeros(size(DATA.value,1),1);
        end
    end
end

