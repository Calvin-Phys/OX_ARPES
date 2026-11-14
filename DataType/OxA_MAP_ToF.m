 classdef OxA_MAP_ToF < OxArpes_3D_Data
    %OXA_MAP_TOF Data object for time-of-flight angular maps.
    %   The axes are two emission angles and kinetic energy; kconvert applies
    %   the configured angular offsets and azimuthal rotation before mapping
    %   the intensity onto an in-plane momentum grid.
    
    properties
    end
    
    methods
        function obj = OxA_MAP_ToF(varargin)
            %OXA_MAP_TOF Construct a time-of-flight map and initialize axes.
            obj@OxArpes_3D_Data(varargin{:});

            obj.name = 'MAP';
            obj.x_name = 'Angle X';
            obj.x_unit = 'deg';
            obj.y_name = 'Angle Y';
            obj.y_unit = 'deg';
            obj.z_name = 'Kinetic Energy';
            obj.z_unit = 'eV';

            obj.info.thetax_offset = 0;
            obj.info.thetay_offset = 0;
            obj.info.azimuth_offset = 0;
        end
        
        function KMAP = kconvert(obj)
            %KCONVERT Convert angular coordinates to an in-plane momentum map.

            obj.validate();
            requiredInfo = {'thetax_offset','thetay_offset','azimuth_offset', ...
                'photon_energy','workfunction'};
            for iField = 1:numel(requiredInfo)
                if ~isfield(obj.info, requiredInfo{iField}) || ...
                        isempty(obj.info.(requiredInfo{iField}))
                    error('OxArpes:MissingMetadata', ...
                        'ToF MAP k conversion requires info.%s.', requiredInfo{iField});
                end
            end
            for iField = 1:numel(requiredInfo)
                validateattributes(obj.info.(requiredInfo{iField}), {'numeric'}, ...
                    {'scalar','real','finite'}, mfilename, ['info.' requiredInfo{iField}]);
            end
            if any(obj.z <= 0)
                error('OxArpes:InvalidKineticEnergy', ...
                    'ToF MAP k conversion requires strictly positive kinetic energies.');
            end
            if ~(all(diff(obj.x) > 0) || all(diff(obj.x) < 0)) || ...
                    ~(all(diff(obj.y) > 0) || all(diff(obj.y) < 0))
                error('OxArpes:InvalidAxis', ...
                    'ToF MAP angular axes must be strictly monotonic.');
            end

            % Precompute azimuth offset sines and cosines
            % keep -45<azimuth_offset<45
            azimuth_cos = cosd(obj.info.azimuth_offset);
            azimuth_sin = sind(obj.info.azimuth_offset);

            sampleX = obj.x;
            sampleY = obj.y;
            sampleValue = obj.value;
            if sampleX(1) > sampleX(end)
                sampleX = fliplr(sampleX);
                sampleValue = flip(sampleValue,1);
            end
            if sampleY(1) > sampleY(end)
                sampleY = fliplr(sampleY);
                sampleValue = flip(sampleValue,2);
            end
            
            [DY, DX] = meshgrid(obj.y,obj.x);

            % Rotate by azimuth offset
            DY_r =  azimuth_cos * DY + azimuth_sin * DX;
            DX_r = -azimuth_sin * DY + azimuth_cos * DX;
        
            % Resample data
            data_new = zeros(size(obj.value));
            for i = 1:length(obj.z)
                % Interpolate data
                data_new(:,:,i) = interp2(sampleY, sampleX, sampleValue(:,:,i), DY_r, DX_r, 'spline', 0);
            end

            % Theta offset
            DY_new =  azimuth_cos * obj.info.thetay_offset + azimuth_sin * obj.info.thetax_offset;
            DX_new = -azimuth_sin * obj.info.thetay_offset + azimuth_cos * obj.info.thetax_offset;

            % Constants
            CONST = 0.512316722; % [sqrt(2m)/hbar] * 1/sqrt(eV)
        
            % Kx = CONST * sqrt(Ek) .* cosd(Y0) .* sind(X0);
            % Ky = CONST * sqrt(Ek) .* sind(Y0);
        
            % Theta offset
            y_offset = obj.y - DY_new;
            x_offset = obj.x - DX_new;
            if any(abs(x_offset) >= 90) || any(abs(y_offset) >= 90)
                error('OxArpes:InvalidAngle', ...
                    'Offset-corrected emission angles must lie strictly between -90 and 90 degrees.');
            end

            rotatedValue = data_new;
            if x_offset(1) > x_offset(end)
                x_offset = fliplr(x_offset);
                rotatedValue = flip(rotatedValue,1);
            end
            if y_offset(1) > y_offset(end)
                y_offset = fliplr(y_offset);
                rotatedValue = flip(rotatedValue,2);
            end
        
            % Find K's boundary
            thetax_max = max(x_offset);
            thetax_min = min(x_offset);
            thetay_max = max(y_offset);
            thetay_min = min(y_offset);
            energy_min = min(obj.z);
        
        
            % Calculate Kx, Ky boundaries
            common_term = CONST * sqrt(energy_min);
        
            kx_max = common_term * sind(thetax_max);
            kx_min = common_term * sind(thetax_min);
            ky_max = common_term * sind(thetay_max);
            ky_min = common_term * sind(thetay_min);

            kxn = length(x_offset);
            kyn = length(y_offset);
        
            % Create Kx, Ky grids
            kx = linspace(kx_min, kx_max, kxn);
            ky = linspace(ky_min, ky_max, kyn);
            [KY, KX] = meshgrid(ky, kx);
        
            % Resample data
            data_new_k = zeros(kxn,kyn,length(obj.z));
            for i = 1:length(obj.z)
                Eki = obj.z(i);
        
                % Calculate new thetay (Y0) and thetax (X0)
                yArgument = KY / CONST ./ sqrt(Eki);
                validQuery = abs(yArgument) <= 1;
                Y0 = nan(size(yArgument));
                Y0(validQuery) = asind(yArgument(validQuery));

                xArgument = KX / CONST / sqrt(Eki) ./ cosd(Y0);
                validQuery = validQuery & isfinite(xArgument) & abs(xArgument) <= 1;
                X0 = nan(size(xArgument));
                X0(validQuery) = asind(xArgument(validQuery));

                % Interpolate data
                plane = interp2(y_offset, x_offset, rotatedValue(:,:,i), Y0, X0, 'spline', 0);
                plane(~isfinite(plane)) = 0;
                data_new_k(:,:,i) = plane;
            end
            data_new_k(data_new_k < 0) = 0;
        
            % Calculate binding energy
            be = obj.z - (obj.info.photon_energy - obj.info.workfunction);
        
            % Create KMAP
            KMAP = OxA_MAP_ToF(kx, ky, be, data_new_k);
            % (Set KMAP properties)
            KMAP.x_name = '{\itk}_x';
            KMAP.x_unit = 'Å^{-1}';
            KMAP.y_name = '{\itk}_y';
            KMAP.y_unit = 'Å^{-1}';
            KMAP.z_name = '{\itE} - {\itE}_F';
            KMAP.z_unit = 'eV';
            KMAP.name = append(obj.name,'_ksp');
            KMAP.info = obj.info;

        end

    end
end

