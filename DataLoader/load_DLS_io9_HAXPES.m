function DATA = load_DLS_io9_HAXPES(file_path)
    %LOAD_DLS_IO9 load 1D/2D data at i09 HAXPES beamline, DLS
    %   08/06/2026 Cheng Peng, University of Oxford
     
    %   -------------------------
    info = h5info(file_path);
    region_name = info.Groups.Groups(1).Name;
    scan_command = h5read(file_path,'/entry/scan_command');
    photon_energy = h5read(file_path,[region_name,'/excitation_energy']);


    Benergy = h5read(file_path,[region_name,'/energies']);
    image_data = h5read(file_path,[region_name,'/image_data']);
    dims = size(image_data);

    if dims(1)==1 || dims(2)==1
        pes_total = image_data;

        DATA = OxArpes_1D_Data(Benergy,pes_total);
        DATA.x_name = 'Binding Energy';
        DATA.x_unit = 'eV';
    
        DATA.info.scan_command = scan_command;
        DATA.info.photon_energy = photon_energy;

    else
        angles = h5read(file_path,[region_name,'/angles']);

        DATA = OxA_CUT(angles,-Benergy,image_data');

        DATA.x_name = 'Angle';
        DATA.x_unit = 'deg';

        DATA.y_name = '{\itE} - {\itE}_F';
        DATA.y_unit = 'eV';
    
        DATA.info.scan_command = scan_command;
        DATA.info.photon_energy = photon_energy;

    end

end

