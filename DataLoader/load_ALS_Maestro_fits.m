function DATA = load_ALS_Maestro_fits(file_path)
%LOAD_ALS_MAESTRO_FITS load .fits data from ALS Maestro beamline BL 10 & 7
% into pre-defined objects
%   Detailed explanation goes here
% added support for nanoARPES

    % -------------------------------------------------------------------
    % get raw data
    % -------------------------------------------------------------------
    info = fitsinfo(file_path);

    keywords_primary = info.PrimaryData.Keywords;

    keywords_binarytable = info.BinaryTable.Keywords;
    fitsdata = fitsread(file_path,'binarytable');

    % -------------------------------------------------------------------
    % arpes data
    % -------------------------------------------------------------------
    % Iterate through the keywords in the binary table of the FITS file
    % Extract values associated with keywords TDIM, TRVAL, and TDELT
    num_col = 0;
    for ii = 1:size(keywords_binarytable,1)
        keyword = keywords_binarytable{ii,1};
        if strncmp(keyword,'TDIM',4)
            tmp = sscanf(keywords_binarytable{ii,2},'(%d,%d)');
            nx = tmp(1);
            ny = tmp(2);

            tmp = sscanf(keywords_binarytable{ii+3,2},'(%f,%f)');
            x0 = tmp(1);
            y0 = tmp(2);

            tmp = sscanf(keywords_binarytable{ii+4,2},'(%f,%f)');
            dx = tmp(1);
            dy = tmp(2);

            num_col = str2num(keyword(5:end));

            break
        end
    end

    if num_col ~= 0
        anglePerPixel = 0.04631; % Constant to convert from pixels to degrees
        centerPixel = 514;
        cXX = ( x0 + dx*(0:(nx-1)) - centerPixel) * anglePerPixel;
        cYY = y0 + dy*(0:(ny-1));
    
        NL = size(fitsdata{1,num_col},1);
        if NL == 1
            VALUE = reshape(fitsdata{1,num_col},nx,ny);
        else
            LL = round(fitsdata{1,2}',1);
            VALUE = reshape(fitsdata{1,num_col},NL,nx,ny);
        end
    else % corelevel
        for ii = 1:size(keywords_binarytable,1)
            keyword = keywords_binarytable{ii,1};
            if strncmp(keyword,'TRVAL',5)

                ny = sscanf(keywords_binarytable{ii-4,2},'%dD');
                y0 = keywords_binarytable{ii,2};
                dy = keywords_binarytable{ii+1,2};
    
                num_col = str2num(keyword(6:end));

                cYY = y0 + dy*(0:(ny-1));
                cXX = [-1, 0, 1];
                VALUE = [fitsdata{1,num_col};fitsdata{1,num_col};fitsdata{1,num_col}];
                break
            end
        end
    end

   

    % -------------------------------------------------------------------
    % set parameters
    % -------------------------------------------------------------------
    % check data type
    for ii = 1:size(keywords_primary,1)
        if strcmp(keywords_primary{ii,1},'NM_0_0')
            data_type = keywords_primary{ii,2};
            break
        end
    end

    switch data_type
        case 'null' % cut
            DATA = OxA_CUT(cXX,cYY,VALUE);
        case {'Slit Defl','Slit Defl.','Alpha'} %  map
            DATA = OxA_MAP(LL,cXX,cYY,VALUE);
        case 'mono_eV' % photon energy scan
            DATA = OxA_KZ(LL,cXX,cYY,VALUE);
    end

    % add info
    
    for ii = 1:size(keywords_primary,1)
        keyword = keywords_primary{ii,1};

        if strcmp(keyword,'HOST') || strcmp(keyword,'HOST0')
            if startsWith(keywords_primary{ii,2},'HERS')
                DATA.info.beamline = 'ALS_BL10';
                DATA.info.workfunction = 4.51;

            elseif startsWith(keywords_primary{ii,2},'uARPES.mfast')
                DATA.info.beamline = 'ALS_BL07_uARPES';
                DATA.info.workfunction = 4.5;
            elseif startsWith(keywords_primary{ii,2},'nARPES')
                DATA.info.beamline = 'ALS_BL07_nARPES';
                DATA.info.workfunction = 4.3;

            end
        elseif strcmp(keyword,'BL_E')
            beamline_energy = keywords_primary{ii,2};
            monochromator_energy = keywords_primary{ii+1,2};
            % undulator_energy = keywords_primary{ii+2,2};
            % photon_energy = round(mean([beamline_energy,monochromator_energy,undulator_energy]),2);
            photon_energy = round(mean([beamline_energy,monochromator_energy]),2);
            DATA.info.photon_energy = photon_energy;
        elseif strcmp(keyword,'MONOEV')
            photon_energy = round(keywords_primary{ii,2},2);
            DATA.info.photon_energy = photon_energy;
        elseif strcmp(keyword,'SSPE_0')
            DATA.info.pass_energy = keywords_primary{ii,2};
        elseif strcmp(keyword,'SSLNM0')
            DATA.info.len_mode = keywords_primary{ii,2};
        end
    end

    DATA.info.raw = keywords_primary;

    switch DATA.info.beamline
        case 'ALS_BL10'
            switch data_type
                case 'null' % cut
                    DATA.y = DATA.y + DATA.info.photon_energy;
                case {'Slit Defl','Slit Defl.','Alpha'} % deflector map
                    DATA.z = DATA.z + DATA.info.photon_energy;
            end
        case {'ALS_BL07_uARPES','ALS_BL07_nARPES'}
            switch data_type
                case 'null' % cut
                    DATA.y = DATA.y + DATA.info.photon_energy - DATA.info.workfunction;
                case {'Slit Defl','Slit Defl.','Alpha'} % deflector map
                    DATA.z = DATA.z + DATA.info.photon_energy - DATA.info.workfunction;
            end
    end

end

