function KMAP = kconvert_v3(obj)

    % Constants
    CONST = 0.512316722; % [sqrt(2m)/hbar] * 1/sqrt(eV)

    % Kx = CONST * sqrt(Ek) .* cosd(Y0) .* sind(X0);
    % Ky = CONST * sqrt(Ek) .* sind(Y0);

    

    % Theta offset
    y_offset = obj.y - obj.info.thetay_offset;
    x_offset = obj.x - obj.info.thetax_offset;

    % Find K's boundary
    thetax_max = max(x_offset);
    thetax_min = min(x_offset);
    thetay_max = max(y_offset);
    thetay_min = min(y_offset);
    energy_min = min(obj.z);
    energy_max = max(obj.z);

    % Precompute azimuth offset sines and cosines
    % keep -45<azimuth_offset<45
    azimuth_cos = cosd(obj.info.azimuth_offset);
    azimuth_sin = sind(obj.info.azimuth_offset);

    % Calculate Kx, Ky boundaries
    common_term = CONST * sqrt(energy_min);
    if thetax_max > 0 && thetax_min < 0 && thetay_max > 0 && thetay_min < 0 % Common case

        if obj.info.azimuth_offset == 0 % no rotation
            kx_max = common_term * sind(thetax_max);
            kx_min = common_term * sind(thetax_min);
            ky_max = common_term * sind(thetay_max);
            ky_min = common_term * sind(thetay_min);

            kxn = length(x_offset);
            kyn = length(y_offset);

        else
            CRNR_D = [thetax_min, thetax_min, thetax_max, thetax_max; ...
                      thetay_min, thetay_max, thetay_max, thetay_min];
            CRNR_K = common_term * [ cosd(CRNR_D(2,:)) .* sind(CRNR_D(1,:)); ...
                                     sind(CRNR_D(2,:))];
            CRNR_KR = [azimuth_cos, azimuth_sin; ...
                       -azimuth_sin,  azimuth_cos] * CRNR_K;

            kx_max = max(CRNR_KR(1,:),[],"all");
            kx_min = min(CRNR_KR(1,:),[],"all");
            ky_max = max(CRNR_KR(2,:),[],"all");
            ky_min = min(CRNR_KR(2,:),[],"all");

            kxn = length(x_offset)*2;
            kyn = length(y_offset);
            
            
        end
    else % Special case
        % Calculate Kx, Ky boundaries for the special case
        % (omitted for brevity)
    end

    % Create Kx, Ky grids
    kx = linspace(kx_min, kx_max, kxn);
    ky = linspace(ky_min, ky_max, kyn);
    [KY, KX] = meshgrid(ky, kx);
    
    % Rotate by azimuth offset
    KY_r =  azimuth_cos * KY + azimuth_sin * KX;
    KX_r = -azimuth_sin * KY + azimuth_cos * KX;

    % Resample data
    data_new = zeros(kxn,kyn,length(obj.z));
    for i = 1:length(obj.z)
        Eki = obj.z(i);

        % Calculate new thetay (Y0) and thetax (X0)
        Y0 = asind(KY_r / CONST ./ sqrt(Eki));
        X0 = asind(KX_r / CONST / sqrt(Eki) ./ cosd(Y0));

        % Interpolate data
        data_new(:,:,i) = interp2(y_offset, x_offset, obj.value(:,:,i), Y0, X0, 'spline', 0);
    end
    data_new(data_new < 0) = 0;

    % Calculate binding energy
    be = obj.z - (obj.info.photon_energy - obj.info.workfunction);

    % Create KMAP
    KMAP = OxA_MAP(kx, ky, be, data_new);
    % (Set KMAP properties)
    KMAP.x_name = '{\it k}_x';
    KMAP.x_unit = 'Å^{-1}';
    KMAP.y_name = '{\it k}_y';
    KMAP.y_unit = 'Å^{-1}';
    KMAP.z_name = '{\it E}-{\it E}_F';
    KMAP.z_unit = 'eV';
    KMAP.name = [obj.name '_ksp'];
    KMAP.info = obj.info;



end
