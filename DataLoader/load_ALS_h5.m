function DATA = load_ALS_h5(file_path)
%LOAD_ALS_H5 Read supported ALS HDF5 swept-spectra data.
%   Converts the swept-spectra dataset and scale attributes into an OX MAP
%   object. Unsupported dimensionality warns and returns [] without adding
%   partial metadata.
    value = h5read(file_path,'/2D_Data/Swept_Spectra15');

    if ndims(value) == 3 % KZ

        x = h5read(file_path,'/0D_Data/Slit Defl');
        
        scaleOffset = h5readatt(file_path, '/2D_Data/Swept_Spectra15', 'scaleOffset');
        scaleDelta = h5readatt(file_path, '/2D_Data/Swept_Spectra15', 'scaleDelta');

        y = scaleOffset(1) + scaleDelta(1)*((1:size(value,2))-1);
        y = (y-mean(y))*0.02;

        z = scaleOffset(2) + scaleDelta(2)*((1:size(value,3))-1);

        DATA = OxA_MAP(x,y,z,value);

    else
        warning('OxArpes:UnsupportedALSH5Dimension', ...
            'ALS H5 loader supports only 3-D Swept_Spectra15 data; received %d-D.', ...
            ndims(value));
        DATA = [];
        return
    end

    % ------- add Info
    DATA.info.workfunction = 4.5;
    DATA.info.photon_energy = mean(h5read(file_path,'/0D_Data/Mono EnergyDAQ'));
    DATA.info.temperature = mean(h5read(file_path,'/0D_Data/Cryostat_A'));

    DATA.z = DATA.z + DATA.info.photon_energy - DATA.info.workfunction;
    
end
