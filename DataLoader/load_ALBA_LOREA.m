function DATA = load_ALBA_LOREA(file_path)
%LOAD_ALBA_LOREA Summary of this function goes here
%   Detailed explanation goes here
    title = h5read(file_path,'/entry1/title');
    
    notes = h5read(file_path,'/entry1/notes');

    switch notes

        case 'spatial scan'
            x = h5read(file_path,'/entry1/data/angles');
            y = h5read(file_path,'/entry1/data/energies');
            value = double(h5read(file_path,'/entry1/data/data'));
            
            DATA = OxA_CUT(x,y,value');
        
            DATA.x_name = 'Angle';
            DATA.x_unit = 'Deg';
            DATA.y_name = 'Kinetic Energy';
            DATA.y_unit = 'eV';

        case {'FS','FM'}
            x = h5read(file_path,'/entry1/data/defl_angles');
            y = h5read(file_path,'/entry1/data/angles');
            z = h5read(file_path,'/entry1/data/energies');
            value = double(h5read(file_path,'/entry1/data/data'));
            
            px = polyfit(1:length(x),x,1);
            x_ = px(2) + px(1) * (0:(length(x)-1));
            py = polyfit(1:length(y),y,1);
            y_ = py(2) + py(1) * (0:(length(y)-1));

            DATA = OxA_MAP(x_,y_,z,permute(value,[3 2 1]));
        
            DATA.x_name = 'Defl Angle';
            DATA.x_unit = 'Deg';
            DATA.y_name = 'Angle';
            DATA.y_unit = 'Deg';
            DATA.z_name = 'Kinetic Energy';
            DATA.z_unit = 'eV';

    end

    


    % ------- add Info
    DATA.info.workfunction = 4.83;
    DATA.info.photon_energy = h5read(file_path,'/entry1/instrument/monochromator/energy');
    DATA.info.polarization = h5read(file_path,'/entry1/instrument/insertion_device/beam/final_polarisation');
    DATA.info.acquisition_mode = h5read(file_path,'/entry1/instrument/analyser/acquisition_mode');
    DATA.info.pass_energy = h5read(file_path,'/entry1/instrument/analyser/pass_energy');
    DATA.info.temperature = h5read(file_path,'/entry1/sample/temperature');
    
    DATA.info.sample_X = h5read(file_path,'/entry1/instrument/manipulator/sax');
    DATA.info.sample_Y = h5read(file_path,'/entry1/instrument/manipulator/say');
    DATA.info.sample_Z = h5read(file_path,'/entry1/instrument/manipulator/saz');
    DATA.info.sample_polar = h5read(file_path,'/entry1/instrument/manipulator/sapolar');
    DATA.info.sample_tilt = h5read(file_path,'/entry1/instrument/manipulator/satilt');
    DATA.info.sample_azimuth = h5read(file_path,'/entry1/instrument/manipulator/saazimuth');

    DATA.info.beamline = 'ALBA_LOREA';

end

