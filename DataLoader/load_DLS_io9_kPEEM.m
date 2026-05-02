function DATA = load_DLS_io9_kPEEM(file_path)
%LOAD_DLS_IO9 Summary of this function goes here
%   Detailed explanation goes here
    
    %   -------------------------
    scan_command = h5read(file_path,'/entry1/scan_command');
    photon_energy = 1000*h5read(file_path,'/entry1/before_scan/jenergy_s/jenergy_s');
    photon_energy2 = 1000*h5read(file_path,'/entry1/before_scan/pgmenergy/pgmenergy');
    photon_energy3 = 1000*h5read(file_path,'/entry1/pgm/pgmenergy');


    polarization = h5read(file_path,'/entry1/before_scan/polarisation/polarisation');
    temperature = h5read(file_path,'/entry1/before_scan/ss2/ss2temp1');
    workfunction = 4.28;

    if contains(scan_command, 'Benergy', 'IgnoreCase', true)
        if contains(scan_command, 'dld_total', 'IgnoreCase', true)
    
            Benergy = h5read(file_path,'/entry1/instrument/Benergy/Benergy');
            Benergy2 = h5read(file_path,'/entry1/dld_total/Benergy');

            dld_total = h5read(file_path,'/entry1/instrument/dld_total/mcp_roi_total');
        
            DATA = OxArpes_1D_Data(Benergy,dld_total);
            DATA.x_name = 'Binding Energy';
            DATA.x_unit = 'eV';
            DATA.v_name = 'Counts';
            DATA.v_unit = 'arb. unit';

            DATA.info.dld_Benergy = Benergy2;
    
        elseif contains(scan_command, 'dld', 'IgnoreCase', true)
    
            Benergy = h5read(file_path,'/entry1/instrument/Benergy/Benergy');
            Benergy2 = h5read(file_path,'/entry1/dld/Benergy');
            dld_total = h5read(file_path,'/entry1/instrument/dld/mcp_roi_total');
            
            [filepath,name,ext] = fileparts(file_path);
            dld_file_path = fullfile(filepath,[replace(name,'i09-2-','dld-'),'.hdf']);
    
            value = double(h5read(dld_file_path,'/entry/data/data'));
    
    
            DATA = OxA_MAP_ToF(1:size(value,1),1:size(value,2),photon_energy - Benergy - workfunction,value);
    
            DATA.x_name = 'X';
            DATA.x_unit = 'Pixel';
            DATA.y_name = 'Y';
            DATA.y_unit = 'Pixel';
            DATA.z_name = 'Kinetic Energy';
            DATA.z_unit = 'eV';

            DATA.info.dld_total = dld_total;
            DATA.info.dld_Benergy = Benergy2;

            DATA = DATA.Gaussian_smoothen_XY(3,3);

            % angle calibration
            p2a_x_idx = 0.02;
            p2a_y_idx = 0.02;
            DATA.x = (DATA.x - mean(DATA.x,"all")).* p2a_x_idx;
            DATA.y = (DATA.y - mean(DATA.y,"all")).* p2a_y_idx;
            DATA.x_name = 'Angle X';
            DATA.x_unit = 'deg';
            DATA.y_name = 'Angle Y';
            DATA.y_unit = 'deg';

        end

        DATA.info.scan_command = scan_command;
        DATA.info.photon_energy = photon_energy;
        DATA.info.pgm_energy = photon_energy2;
        DATA.info.beam_energy = photon_energy3;
        DATA.info.polarization = polarization;
        DATA.info.temperature = temperature;
        DATA.info.workfunction = workfunction;

    else
        DATA = [];
    end

    


    
end

