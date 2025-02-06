function DATA = load_DLS_io9_kPEEM(file_path)
%LOAD_DLS_IO9 Summary of this function goes here
%   Detailed explanation goes here
    
    %   -------------------------
    scan_command = h5read(file_path,'/entry1/scan_command');
    photon_energy = 1000*h5read(file_path,'/entry1/before_scan/jenergy_s/jenergy_s');
    polarization = h5read(file_path,'/entry1/before_scan/polarisation/polarisation');
    workfunction = 4.28;
    if contains(scan_command, 'Benergy', 'IgnoreCase', true)
        if contains(scan_command, 'dld_total', 'IgnoreCase', true)
    
            Benergy = h5read(file_path,'/entry1/instrument/Benergy/Benergy');
            dld_total = h5read(file_path,'/entry1/instrument/dld_total/mcp_roi_total');
        
            DATA = OxArpes_1D_Data(Benergy,dld_total);
            DATA.x_name = 'Binding Energy';
            DATA.x_unit = 'eV';
    
        elseif contains(scan_command, 'dld', 'IgnoreCase', true)
    
            Benergy = h5read(file_path,'/entry1/instrument/Benergy/Benergy');
            dld_total = h5read(file_path,'/entry1/instrument/dld/mcp_roi_total');
            
            [filepath,name,ext] = fileparts(file_path);
            dld_file_path = fullfile(filepath,[replace(name,'i09-2-','dld-'),'.hdf']);
    
            value = double(h5read(dld_file_path,'/entry/data/data'));
    
    
            DATA = OxA_MAP(1:size(value,1),1:size(value,2),photon_energy - Benergy - workfunction,value);
    
            DATA.x_name = 'X';
            DATA.x_unit = 'Pixel';
            DATA.y_name = 'Y';
            DATA.y_unit = 'Pixel';
            DATA.z_name = 'Kinetic Energy';
            DATA.z_unit = 'eV';
    

        end

        DATA.info.scan_command = scan_command;
        DATA.info.photon_energy = photon_energy;
        DATA.info.polarization = polarization;

    else
        DATA = [];
    end

    


    
end

