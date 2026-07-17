function DATA = load_DLS_io5_nano(file_path)
% LOAD_DLS_IO5_nano
%   Cheng Peng, Oxford Physics
%   2026 July
    
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
    
        else
            DATA = [];
        end

    catch
        DATA = [];
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

