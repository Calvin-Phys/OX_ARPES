function DATA = load_DLS_io9_HAXPES(file_path)
%LOAD_DLS_IO9 Summary of this function goes here
%   Detailed explanation goes here
     
    %   -------------------------
    info = h5info(file_path);
    region_name = info.Groups.Groups(1).Name;
    scan_command = h5read(file_path,'/entry/scan_command');
    photon_energy = h5read(file_path,[region_name,'/excitation_energy']);


    Benergy = h5read(file_path,[region_name,'/energies']);
    pes_total = h5read(file_path,[region_name,'/image_data']);

    DATA = OxArpes_1D_Data(Benergy,pes_total);
    DATA.x_name = 'Binding Energy';
    DATA.x_unit = 'eV';


    DATA.info.scan_command = scan_command;
    DATA.info.photon_energy = photon_energy;

    
end

