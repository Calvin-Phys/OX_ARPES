 classdef OxA_MAP_ToF < OxArpes_3D_Data
    %OXA_MAP Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = OxA_MAP_ToF(varargin)
            %OXA_MAP Construct an instance of this class
            %   Detailed explanation goes here
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

            % Precompute azimuth offset sines and cosines
            % keep -45<azimuth_offset<45
            azimuth_cos = cosd(obj.info.azimuth_offset);
            azimuth_sin = sind(obj.info.azimuth_offset);
            
            [DY, DX] = meshgrid(obj.y,obj.x);

            % Rotate by azimuth offset
            DY_r =  azimuth_cos * DY + azimuth_sin * DX;
            DX_r = -azimuth_sin * DY + azimuth_cos * DX;
        
            % Resample data
            data_new = zeros(size(obj.value));
            for i = 1:length(obj.z)
                % Interpolate data
                data_new(:,:,i) = interp2(obj.y, obj.x, obj.value(:,:,i), DY_r, DX_r, 'spline', 0);
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
        
            % Find K's boundary
            thetax_max = max(x_offset);
            thetax_min = min(x_offset);
            thetay_max = max(y_offset);
            thetay_min = min(y_offset);
            energy_min = min(obj.z);
            energy_max = max(obj.z);
        
        
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
                Y0 = asind(KY / CONST ./ sqrt(Eki));
                X0 = asind(KX / CONST / sqrt(Eki) ./ cosd(Y0));
        
                % Interpolate data
                data_new_k(:,:,i) = interp2(y_offset, x_offset, data_new(:,:,i), Y0, X0, 'spline', 0);
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

