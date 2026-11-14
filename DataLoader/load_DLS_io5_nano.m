function DATA = load_DLS_io5_nano(file_path)
%LOAD_DLS_IO5_NANO Read supported DLS i05 nanoARPES NeXus scans.
%   Dispatches by scan title and constructs the corresponding CUT, MAP, or
%   higher-dimensional data object, then attaches acquisition metadata.
    
    %   -------------------------
    title = h5read(file_path,'/entry1/title');
    % title = h5read(file_path,'/entry1/scan_command');

    value = double(h5read(file_path,'/entry1/analyser/data'));

    photon_energy = h5read(file_path,'/entry1/instrument/monochromator/energy');
    pass_energy = h5read(file_path,'/entry1/instrument/analyser/pass_energy');

    workfunction = 4.27;

    % cut
    try

        if contains(title,'static readout')
            
            x = h5read(file_path,'/entry1/analyser/angles');
            y = h5read(file_path,'/entry1/analyser/energies');
            DATA = OxA_CUT(x,y,value');
    
        % deflector map
        elseif contains(title,'scan deflector_x')
    
            value = permute(value,[3,2,1]);
            x = h5read(file_path,'/entry1/analyser/deflector_x');
            try
                y = h5read(file_path,'/entry1/analyser/angles');
            catch
                y = h5read(file_path,'/entry1/analyser/location');
            end
            z = mean(h5read(file_path,'/entry1/analyser/energies'),2);
            DATA = OxA_MAP(x,y,z,value);
    
        % anapolar map
        elseif contains(title,'scan anapolar')
            value = permute(value,[3,2,1]);
            x = h5read(file_path,'/entry1/analyser/analyser_polar_angle');
            y = h5read(file_path,'/entry1/analyser/angles');
            z = h5read(file_path,'/entry1/analyser/energies');
            DATA = OxA_MAP(x,y,z,value);
    
        % kz
        elseif contains(title,'scan scan_group')
            value = permute(value,[3,2,1]);
            x = h5read(file_path,'/entry1/analyser/centre_energy');
            hv = h5read(file_path,'/entry1/instrument/monochromator/energy');
            x = x + hv - x(1);
            y = h5read(file_path,'/entry1/analyser/angles');
            z = mean(h5read(file_path,'/entry1/analyser/energies'),2);
            DATA = OxA_KZ(x,y,z,value);

        % 2D scan
        elseif (contains(title,'scan') && contains(title,'smx') && contains(title,'smy'))
            if ~contains(title,'smy_fly')
                x = mean(flip(h5read(file_path,'/entry1/analyser/smx')),1)';
                y = mean(h5read(file_path,'/entry1/analyser/smy'),2);
                z = mean(h5read(file_path,'/entry1/analyser/energies'),[2 3]);
                k = h5read(file_path,'/entry1/analyser/angles');
                % Normalize source dimensions to the package order (x,y,k,z).
                value = permute(h5read(file_path,'/entry1/analyser/data'),[4 3 2 1]);
                DATA = OxArpes_4D_Data(x,y,z,k,value);
                DATA.x_name = 'smx';
                DATA.x_unit = 'mm';
                DATA.y_name = 'smy';
                DATA.y_unit = 'mm';
                DATA.k_name = 'angle';
                DATA.k_unit = 'deg';
                DATA.z_name = 'kinetic Energy';
                DATA.z_unit = 'eV';
            else
                x = mean(flip(h5read(file_path,'/entry1/analyser/smx')),1)';
                y = mean(h5read(file_path,'/entry1/analyser/value'),2);
                z = mean(h5read(file_path,'/entry1/analyser/energies'),[2 3]);
                k = h5read(file_path,'/entry1/analyser/angles');
                % Normalize source dimensions to the package order (x,y,k,z).
                value = permute(h5read(file_path,'/entry1/analyser/data'),[4 3 2 1]);
                DATA = OxArpes_4D_Data(x,y,z,k,value);
                DATA.x_name = 'smx';
                DATA.x_unit = 'mm';
                DATA.y_name = 'smy';
                DATA.y_unit = 'mm';
                DATA.k_name = 'angle';
                DATA.k_unit = 'deg';
                DATA.z_name = 'kinetic Energy';
                DATA.z_unit = 'eV';

            end
    
        else
            warning('OxArpes:UnsupportedNanoScan', ...
                'Unsupported DLS i05 nano scan command: %s', char(string(title)));
            DATA = [];
            return
        end

    catch cause
        failure = MException('OxArpes:NanoLoadFailed', ...
            'Failed to interpret DLS i05 nano file "%s".', file_path);
        failure = addCause(failure, cause);
        throwAsCaller(failure);
    end

    % ------- add Info
    DATA.info.workfunction = mean(workfunction);
    DATA.info.photon_energy = h5read(file_path,'/entry1/instrument/monochromator/energy');
    DATA.info.polarization = h5read(file_path,'/entry1/instrument/insertion_device/beam/final_polarisation_label');
    DATA.info.acquisition_mode = h5read(file_path,'/entry1/instrument/analyser/acquisition_mode');
    DATA.info.acquire_time = h5read(file_path,'/entry1/instrument/analyser/acquire_time');
    DATA.info.pass_energy = double(h5read(file_path,'/entry1/instrument/analyser/pass_energy'));
    DATA.info.center_energy = h5read(file_path,'/entry1/instrument/analyser/kinetic_energy_center');
    DATA.info.temperature = h5read(file_path,'/entry1/sample/temperature');
    DATA.info.exit_slit = h5read(file_path,'/entry1/instrument/monochromator/exit_slit_size');
    
    DATA.info.sample_X = h5read(file_path,'/entry1/instrument/manipulator/smx');
    DATA.info.sample_Y = h5read(file_path,'/entry1/instrument/manipulator/smy');
    DATA.info.sample_Z = h5read(file_path,'/entry1/instrument/manipulator/smz');
    DATA.info.sample_polar = h5read(file_path,'/entry1/instrument/manipulator/smpolar');
    DATA.info.sample_defocus = h5read(file_path,'/entry1/instrument/manipulator/smdefocus');
    DATA.info.sample_azimuth = h5read(file_path,'/entry1/instrument/manipulator/smazimuth');

    DATA.info.time_loaded = datetime("now");
    DATA.info.beamline = 'DLS_i05_nano';

end
