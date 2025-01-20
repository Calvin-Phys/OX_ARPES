function DATA = load_SSRL_BL52(file_path)
%LOAD_SSRL_BL52 Summary of this function goes here
%   Detailed explanation goes here
    data_info = h5info(file_path);
    
    data_type = h5readatt(file_path,'/Details/CommandSettings','Type');

    if strcmp(data_type,'Spectrum2D')
        xn = h5readatt(file_path,'/Data/Axes1','Count');
        dx = h5readatt(file_path,'/Data/Axes1','Delta');
        x0 = h5readatt(file_path,'/Data/Axes1','Offset');

        x = x0 + double(0:(xn-1)).*dx;
        x_unit = h5readatt(file_path,'/Data/Axes1','Unit');
        x_label = h5readatt(file_path,'/Data/Axes1','Label');

        yn = h5readatt(file_path,'/Data/Axes0','Count');
        dy = h5readatt(file_path,'/Data/Axes0','Delta');
        y0 = h5readatt(file_path,'/Data/Axes0','Offset');

        y = y0 + double(0:(yn-1))*dy;
        y_unit = h5readatt(file_path,'/Data/Axes0','Unit');
        y_label = h5readatt(file_path,'/Data/Axes0','Label');

        count = h5read(file_path,'/Data/Count');
        exp_t = h5read(file_path,'/Data/Time');

        DATA = OxA_CUT(x,y,count./exp_t);
        DATA.x_unit = x_unit;
        DATA.x_name = x_label;
        DATA.y_unit = y_unit;
        DATA.y_name = y_label;


    elseif strcmp(data_type,'Spectrum3D') % map

        yn = h5readatt(file_path,'/Data/Axes1','Count');
        dy = h5readatt(file_path,'/Data/Axes1','Delta');
        y0 = h5readatt(file_path,'/Data/Axes1','Offset');

        y = y0 + double(0:(yn-1))*dy;
        y_unit = h5readatt(file_path,'/Data/Axes1','Unit');
        y_label = h5readatt(file_path,'/Data/Axes1','Label');

        zn = h5readatt(file_path,'/Data/Axes0','Count');
        dz = h5readatt(file_path,'/Data/Axes0','Delta');
        z0 = h5readatt(file_path,'/Data/Axes0','Offset');

        z = z0 + double(0:(zn-1)).*dz;
        z_unit = h5readatt(file_path,'/Data/Axes0','Unit');
        z_label = h5readatt(file_path,'/Data/Axes0','Label');

        xn = h5readatt(file_path,'/Data/Axes2','Count');
        dx = h5readatt(file_path,'/Data/Axes2','Delta');
        x0 = h5readatt(file_path,'/Data/Axes2','Offset');

        x = x0 + double(0:(xn-1))*dx;
        x_unit = h5readatt(file_path,'/Data/Axes2','Unit');
        x_label = h5readatt(file_path,'/Data/Axes2','Label');

        count = h5read(file_path,'/Data/Count');
        exp_t = h5read(file_path,'/Data/Time');

        DATA = OxA_MAP(x,y,z,count./exp_t);
        DATA.x_unit = x_unit;
        DATA.x_name = x_label;
        DATA.y_unit = y_unit;
        DATA.y_name = y_label;
        DATA.z_unit = z_unit;
        DATA.z_name = z_label;

    elseif strcmp(data_type,'Map1D') % KZ

        x = double(h5read(file_path,'/MapInfo/Beamline:energy'));
        x_unit = h5readatt(file_path,'/Data/Axes2','Unit');
        x_label = h5readatt(file_path,'/Data/Axes2','Label');

        yn = h5readatt(file_path,'/Data/Axes1','Count');
        dy = h5readatt(file_path,'/Data/Axes1','Delta');
        y0 = h5readatt(file_path,'/Data/Axes1','Offset');

        y = y0 + double(0:(yn-1))*dy;
        y_unit = h5readatt(file_path,'/Data/Axes1','Unit');
        y_label = h5readatt(file_path,'/Data/Axes1','Label');

        zn = h5readatt(file_path,'/Data/Axes0','Count');
        % dz = h5readatt(file_path,'/Data/Axes0','Delta');
        dz = mean(h5read(file_path,'/MapInfo/Data:Axes0:Delta'));
        z0_ = h5read(file_path,'/MapInfo/Data:Axes0:Offset');
        z0 = mean(z0_- x + h5readatt(file_path,'/UserSettings','WorkFunction'));

        z = double(z0) + double(0:(zn-1)).*double(dz);
        z_unit = h5readatt(file_path,'/Data/Axes0','Unit');
        z_label = h5readatt(file_path,'/Data/Axes0','Label');

        count = h5read(file_path,'/Data/Count');
        exp_t = h5read(file_path,'/Data/Time');

        DATA = OxA_KZ(x,y,z,double(count./exp_t));
        DATA.x_unit = x_unit;
        DATA.x_name = 'Photon Energy';
        DATA.y_unit = y_unit;
        DATA.y_name = y_label;
        DATA.z_unit = z_unit;
        DATA.z_name = '{\it E}-{\it E}_F';
    else
        DATA = [];
    end

    DATA.value(isnan(DATA.value)) = 0;

    % ------- add Info
    DATA.info.photon_energy = h5readatt(file_path,'/Beamline','energy');
    DATA.info.polarization = h5readatt(file_path,'/Beamline','polarization');
    switch DATA.info.polarization
        case 0
            DATA.info.polarization = 'LH';
        case 0.5
            DATA.info.polarization = 'LV';
    end
    DATA.info.exit_slit = h5readatt(file_path,'/Beamline','pexit');
    DATA.info.pass_energy = h5readatt(file_path,'/Measurement','PassEnergy');
    DATA.info.lens_mod = h5readatt(file_path,'/Measurement','LensModeName');
    DATA.info.acquisition_mode = h5readatt(file_path,'/Measurement','Description');
    DATA.info.temperature_coldhead = h5readatt(file_path,'/Temperature','TA');
    DATA.info.temperature_sample_stage = h5readatt(file_path,'/Temperature','TB');
    DATA.info.sample_X = h5readatt(file_path,'/Manipulator','X');
    DATA.info.sample_Y = h5readatt(file_path,'/Manipulator','Y');
    DATA.info.sample_Z = h5readatt(file_path,'/Manipulator','Z');
    DATA.info.sample_T = h5readatt(file_path,'/Manipulator','T');
    DATA.info.sample_F = h5readatt(file_path,'/Manipulator','F');
    DATA.info.sample_A = h5readatt(file_path,'/Manipulator','A');
    DATA.info.workfunction = h5readatt(file_path,'/UserSettings','WorkFunction');
    DATA.info.resolution_total = h5readatt(file_path,'/Resolution','TotalResolution');
    DATA.info.resolution_beamline = h5readatt(file_path,'/Resolution','BeamlineResolution');
    DATA.info.resolution_analyser = h5readatt(file_path,'/Resolution','AnalyserResolution');
    DATA.info.beamline = h5readatt(file_path,'/UserSettings','Location');
    DATA.info.beamline = h5readatt(file_path,'/Details','CreationTime');
    DATA.info.raw = data_info;

    
end

