function DATA = load_ALS_Maestro_fits(file_path)
%LOAD_ALS_MAESTRO_FITS load .fits data from ALS Maestro beamline BL 10 & 7
% into pre-defined objects
%   Detailed explanation goes here
% added support for nanoARPES
    
    info = fitsinfo(file_path);

    keywords_primary = info.PrimaryData.Keywords;

    keywords_binarytable = info.BinaryTable.Keywords;
    fitsdata = fitsread(file_path,'binarytable');

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
        case {'Slit Defl','Slit Defl.','Alpha'} % deflector map
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
            end
        elseif strcmp(keyword,'BL_E')
            beamline_energy = keywords_primary{ii,2};
            monochromator_energy = keywords_primary{ii+1,2};
            undulator_energy = keywords_primary{ii+2,2};
            photon_energy = round(mean([beamline_energy,monochromator_energy,undulator_energy]),2);
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

    switch data_type
        case 'null' % cut
            DATA.y = DATA.y + DATA.info.photon_energy;
        case {'Slit Defl','Slit Defl.','Alpha'} % deflector map
            DATA.z = DATA.z + DATA.info.photon_energy;
    end




%     % Initialize variables
%     travel = []; % Initial random value
%     tdelt = [];
%     
%     % Iterate through the keywords in the binary table of the FITS file
%     % Extract values associated with keywords TDIM, TRVAL, and TDELT
%     for ii = 1:size(keywords_binarytable,1)
%         keyword = keywords_binarytable{ii,1};
%         if strncmp(keyword,'TDIM',4)
%             tmp = sscanf(keywords_binarytable{ii,2},'(%d,%d)');
%             nx = tmp(1);
%             ny = tmp(2);
%             number = keyword (5);
%             travel = ['TRVAL',number];
%             tdelt = ['TDELT',number];
%         elseif strncmp(keyword,travel,6)
%             tmp = sscanf(keywords_binarytable{ii,2},'(%f,%f)');
%             x0 = tmp(1);
%             y0 = tmp(2);
%         elseif strncmp(keyword,tdelt,6)
%             tmp = sscanf(keywords_binarytable{ii,2},'(%f,%f)');
%             dx = tmp(1);
%             dy = tmp(2);
%         end
%     end
%     
%     % Calculate x-axis values and convert from pixels to degrees
%     xend = x0+dx*(nx-1);
%     anglePerPixel = 0.04631; % Constant to convert from pixels to degrees
%     centerPixel = (x0+xend)/2;
%     XX = (linspace(x0,xend,nx) - centerPixel).*anglePerPixel;
%     
%     % Calculate y-axis values
%     yend = y0+dy*(ny-1);
%     YY = linspace(y0,yend,ny);
% 
%     % Determine the dimensionality of the data (2D or 3D)
%     if size(fitsdata{2},1) == 1
%         data_dim = 2;
%     else
%         data_dim = 3;
%     end
% 
%     % Process the data based on its dimensionality
%     switch data_dim
%         case 2
%             % For 2D data, reshape the data into a 2D array
%             VALUE = reshape(fitsdata{end},nx,ny);
% 
%             DATA = OxA_CUT(XX,YY,VALUE);
% 
%         case 3
%             % For 3D data, update axis values and reshape the data into a 3D array
%             nz = ny;
%             ny = nx;
%             nx = length(fitsdata{2});
%             VALUE = reshape(fitsdata{end},nx,ny,nz);
% 
%             DATA = OxA_MAP(fitsdata{2}',XX,YY,VALUE);
%     end

end

