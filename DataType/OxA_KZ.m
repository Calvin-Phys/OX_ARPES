classdef OxA_KZ < OxArpes_3D_Data
    %OXA_KZ Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = OxA_KZ(varargin)
            %OXA_KZ Construct an instance of this class
            %   Detailed explanation goes here
            obj@OxArpes_3D_Data(varargin{:});

            obj.name = 'KZ';
            obj.x_name = 'Photon Energy';
            obj.x_unit = 'eV';
            obj.y_name = 'Angle Y';
            obj.y_unit = 'deg';
            obj.z_name = '{\itE} - {\itE}_F';
            obj.z_unit = 'eV';

            obj.info.thetay_offset = 0;
            obj.info.inner_energy = 15;
        end
        
        function KMAP = kconvert(obj,varargin)
        
            % electron mass = 9.1093837 × 10-31 kilograms
            % hbar = 6.582119569...×10−16 eV⋅s
            % k (A-1) = CONST * sqrt(Ek (eV)) * sin(theta)
            CONST = 0.512316722;
            if isempty(varargin)
                % prompt = {'Enter Inner Energy [eV]:'};
                % dlgtitle = 'Inner Energy';
                % definput = {'15'};
                % dims = [1 35];
                % answer = inputdlg(prompt,dlgtitle,dims,definput);
                % V0 = str2num(answer{1});
                if isfield(obj.info,'inner_energy')
                    V0 = obj.info.inner_energy;
                else
                    warning('Please check the Inner Energy of the data. Now using 15 eV as default.')
                    obj.info.inner_energy = 15;
                    V0 = 15;
                end
            else
                V0 = varargin{1};
            end

            if size(obj.info.workfunction,1) > 1
                workfunction = mean(obj.info.workfunction);
            else
                workfunction = obj.info.workfunction;
            end
            

            thetay_offset = obj.y - obj.info.thetay_offset;
            hv_max = max(obj.x);
            hv_min = min(obj.x);
            thetay_max = max(thetay_offset);
            thetay_min = min(thetay_offset);
            thetay_abs_min = min(abs(thetay_offset));
            thetay_abs_max = max(abs(thetay_offset));
            energy_min = min(obj.z);
            energy_max = max(obj.z);

            % Kx = CONST* sqrt(H+E-workfunction).*sind(X);
            % Kz = CONST* sqrt((H+E-workfunction)./(1+(tand(X)).^2) + V0);

            kz_max = CONST* sqrt((hv_max+energy_max-workfunction)./(1+(tand(thetay_abs_min)).^2) + V0);
            kz_min = CONST* sqrt((hv_min+energy_min-workfunction)./(1+(tand(thetay_abs_max)).^2) + V0);

            ky_max = max(CONST* sqrt(hv_max+energy_max-workfunction).*sind(thetay_max),...
                CONST* sqrt(hv_min+energy_min-workfunction).*sind(thetay_max));
            ky_min = min(CONST* sqrt(hv_max+energy_max-workfunction).*sind(thetay_min),...
                CONST* sqrt(hv_min+energy_min-workfunction).*sind(thetay_min));


            kzn = 3*length(obj.x);
            kyn = 3*length(thetay_offset);
            kz = linspace(kz_min,kz_max,kzn);
            ky = linspace(ky_min,ky_max,kyn);

            [KY,KZ] = meshgrid(ky,kz);
            thetay = atand(KY./sqrt(KZ.^2 - V0*CONST^2));
            Ek = 1/CONST^2 * (KZ.^2 + KY.^2) - V0;

            tic
            data_new = zeros(kzn,kyn,length(obj.z));
            for i = 1:length(obj.z)
                hv = Ek - obj.z(i) + workfunction;
                data_new(:,:,i) = interp2(thetay_offset,obj.x,obj.value(:,:,i),thetay,hv,'spline',0);
            end
            data_new(data_new<0) = 0;
            toc

            KMAP = OxA_KZ(kz,ky,obj.z,data_new);
            KMAP.x_name = '{\itk}_z';
            KMAP.x_unit = 'Å^{-1}';
            KMAP.y_name = '{\itk}_y';
            KMAP.y_unit = 'Å^{-1}';
            KMAP.z_name = '{\itE} - {\itE}_F';
            KMAP.z_unit = 'eV';
            KMAP.name = [obj.name '_ksp'];
            KMAP.info = obj.info;
        end

        function KMAP = kconvert_type2(obj,varargin)
        
            % electron mass = 9.1093837 × 10-31 kilograms
            % hbar = 6.582119569...×10−16 eV⋅s
            % k (A-1) = CONST * sqrt(Ek (eV)) * sin(theta)
            CONST = 0.512316722;

            if size(obj.info.workfunction,1) > 1
                workfunction = mean(obj.info.workfunction);
            else
                workfunction = obj.info.workfunction;
            end

            thetay_offset = obj.y - obj.info.thetay_offset;
            hv_max = max(obj.x);
            hv_min = min(obj.x);
            thetay_max = max(thetay_offset);
            thetay_min = min(thetay_offset);
            energy_min = min(obj.z);
            energy_max = max(obj.z);

            k_max = CONST * sqrt(hv_max + energy_min - workfunction) * sind(thetay_max);
            k_min = CONST * sqrt(hv_max + energy_min - workfunction) * sind(thetay_min);
            
            kn = length(thetay_offset);
            ky = linspace(k_min,k_max,kn);
            [E_EF,KY] = meshgrid(obj.z,ky);

            tic
            data_new = zeros(length(obj.x),kn,length(obj.z));
            for i = 1:length(obj.x)
                hv = obj.x(i);
                theta_new = asind(KY/CONST./sqrt(E_EF + hv - workfunction));
                data_new(i,:,:) = interp2(obj.z,thetay_offset,squeeze(obj.value(i,:,:)),E_EF,theta_new,'spline',0);
            end
            data_new(data_new<0) = 0;
            toc

            KMAP = OxA_KZ(obj.x,ky,obj.z,data_new);
            KMAP.x_name = 'Photon Energy';
            KMAP.x_unit = 'eV';
            KMAP.y_name = '{\it k}_y';
            KMAP.y_unit = 'Å^{-1}';
            KMAP.z_name = '{\itE} - {\itE}_F';
            KMAP.z_unit = 'eV';
            KMAP.name = [obj.name '_khv'];
            KMAP.info = obj.info;
        end

    end
end

