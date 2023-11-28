function DATA = load_DLS_io5(file_path)
%LOAD_DLS_IO5 Summary of this function goes here
%   Detailed explanation goes here
    
    %   -------------------------
    title = h5read(file_path,'/entry1/title');
    try
        value = double(h5read(file_path,'/entry1/analyser/data'));
    catch

    end

    photon_energy = h5read(file_path,'/entry1/instrument/monochromator/energy');
    pass_energy = h5read(file_path,'/entry1/instrument/analyser/pass_energy');
%     if pass_energy == 50
        
%     elseif pass_energy == 20
%         workfunction = 5.77602E-6 *photon_energy.^2 + 1.23949E-3 *photon_energy + 4.4144;
%     else
%         workfunction = 5.77602E-6 *photon_energy.^2 + 1.23949E-3 *photon_energy + 4.4144;
%     end
%     workfunction = 4.5 + 0 *photon_energy;

    workfunction = -2.505295708E-10 *photon_energy.^4 +5.376936163E-8 *photon_energy.^3 +9.213495312E-9 *photon_energy.^2  - 0.000146349 *photon_energy +4.443810286;

    if contains(title,'static readout')
        x = h5read(file_path,'/entry1/analyser/angles');
        y = h5read(file_path,'/entry1/analyser/energies');
        
        DATA = OxA_CUT(x,y,value');
%         DATA = DATA.set_contrast();
        
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
    elseif contains(title,'scan salong')
        x = flip(h5read(file_path,'/entry1/analyser/salong'));
        value = h5read(file_path,'/entry1/analyser/analyser');
        DATA = OxArpes_1D_Data(x,value);
        DATA.x_name = 'salong';
        DATA.x_unit = 'mm';
    elseif contains(title,'scan sax') && contains(title,'saz')
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
    else
        DATA = [];
    end

    % ------- add Info
    DATA.info.workfunction = workfunction;
    DATA.info.photon_energy = h5read(file_path,'/entry1/instrument/monochromator/energy');
    DATA.info.polarization = h5read(file_path,'/entry1/instrument/insertion_device/beam/final_polarisation_label');
    DATA.info.acquisition_mode = h5read(file_path,'/entry1/instrument/analyser/acquisition_mode');
    DATA.info.acquire_time = h5read(file_path,'/entry1/instrument/analyser/acquire_time');
    DATA.info.pass_energy = h5read(file_path,'/entry1/instrument/analyser/pass_energy');
    DATA.info.center_energy = h5read(file_path,'/entry1/instrument/analyser/kinetic_energy_center');
    DATA.info.temperature = h5read(file_path,'/entry1/sample/temperature');
    DATA.info.exit_slit = h5read(file_path,'/entry1/instrument/monochromator/exit_slit_size');
    
    DATA.info.sample_X = h5read(file_path,'/entry1/instrument/manipulator/sax');
    DATA.info.sample_Y = h5read(file_path,'/entry1/instrument/manipulator/say');
    DATA.info.sample_Z = h5read(file_path,'/entry1/instrument/manipulator/saz');
    DATA.info.sample_polar = h5read(file_path,'/entry1/instrument/manipulator/sapolar');
    DATA.info.sample_tilt = h5read(file_path,'/entry1/instrument/manipulator/satilt');
    DATA.info.sample_azimuth = h5read(file_path,'/entry1/instrument/manipulator/saazimuth');


%     remove spikes
    if strcmp(DATA.info.acquisition_mode,'Fixed') || strcmp(DATA.info.acquisition_mode,'Dither')
        switch ndims(value)
            case 2
                DATA.value = medfilt1(DATA.value,5,[],1);
                DATA.value = medfilt1(DATA.value,5,[],2);
            case 3
                DATA.value = medfilt1(DATA.value,5,[],2);
                DATA.value = medfilt1(DATA.value,5,[],3);
%                 DATA.value = filloutliers(DATA.value,'linear','mean',3);
%                 DATA.value(:,17,91) = zeros(size(DATA.value,1),1);
        end
    end
end

