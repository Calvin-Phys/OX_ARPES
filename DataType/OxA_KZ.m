classdef OxA_KZ < OxArpes_3D_Data
    %OXA_KZ Data object for photon-energy versus momentum-z ARPES scans.
    %   The class inherits common three-axis operations and converts angular
    %   measurements to momentum coordinates using the inner-potential model.
    
    properties
    end
    
    methods
        function obj = OxA_KZ(varargin)
            %OXA_KZ Construct a KZ object and initialize axis metadata.
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
            %KCONVERT Convert photon-energy and angle axes to (kz,ky).
            %   Uses the inner-potential value from metadata or an optional
            %   first argument, then interpolates each energy plane.

            obj.validate();
            requiredInfo = {'thetay_offset','workfunction'};
            for iField = 1:numel(requiredInfo)
                if ~isfield(obj.info, requiredInfo{iField}) || ...
                        isempty(obj.info.(requiredInfo{iField}))
                    error('OxArpes:MissingMetadata', ...
                        'KZ k conversion requires info.%s.', requiredInfo{iField});
                end
            end
            validateattributes(obj.info.thetay_offset, {'numeric'}, ...
                {'scalar','real','finite'});
            validateattributes(obj.info.workfunction, {'numeric'}, ...
                {'vector','real','finite','nonempty'});
            if ~(all(diff(obj.x) > 0) || all(diff(obj.x) < 0)) || ...
                    ~(all(diff(obj.y) > 0) || all(diff(obj.y) < 0))
                error('OxArpes:InvalidAxis', ...
                    'KZ photon-energy and angular axes must be strictly monotonic.');
            end
        
            % electron mass = 9.1093837 × 10-31 kilograms
            % hbar = 6.582119569...×10-16 eV⋅s
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

            validateattributes(V0, {'numeric'}, {'scalar','real','finite'});

            workfunction = mean(obj.info.workfunction(:));
            

            thetay_offset = obj.y - obj.info.thetay_offset;
            if any(abs(thetay_offset) >= 90)
                error('OxArpes:InvalidAngle', ...
                    'Offset-corrected emission angles must lie strictly between -90 and 90 degrees.');
            end
            hv_max = max(obj.x);
            hv_min = min(obj.x);
            thetay_max = max(thetay_offset);
            thetay_min = min(thetay_offset);
            thetay_abs_min = min(abs(thetay_offset));
            thetay_abs_max = max(abs(thetay_offset));
            energy_min = min(obj.z);
            energy_max = max(obj.z);

            kineticMinimum = hv_min + energy_min - workfunction;
            if kineticMinimum <= 0
                error('OxArpes:InvalidKineticEnergy', ...
                    'Photon energy plus binding-energy coordinate minus work function must stay positive.');
            end
            if kineticMinimum/(1+tand(thetay_abs_max)^2) + V0 <= 0
                error('OxArpes:InvalidInnerPotential', ...
                    'The selected inner potential produces a nonpositive normal-energy term.');
            end

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

            sampleHv = obj.x;
            sampleTheta = thetay_offset;
            sampleValue = obj.value;
            if sampleHv(1) > sampleHv(end)
                sampleHv = fliplr(sampleHv);
                sampleValue = flip(sampleValue,1);
            end
            if sampleTheta(1) > sampleTheta(end)
                sampleTheta = fliplr(sampleTheta);
                sampleValue = flip(sampleValue,2);
            end

            data_new = zeros(kzn,kyn,length(obj.z));
            for i = 1:length(obj.z)
                hv = Ek - obj.z(i) + workfunction;
                plane = interp2(sampleTheta,sampleHv,sampleValue(:,:,i), ...
                    thetay,hv,'spline',0);
                plane(~isfinite(plane)) = 0;
                data_new(:,:,i) = plane;
            end
            data_new(data_new<0) = 0;

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
            %KCONVERT_TYPE2 Convert a KZ scan using a common ky interval.
            %   Resamples the input for each photon energy while retaining
            %   the binding-energy coordinate.

            obj.validate();
            if ~isfield(obj.info,'thetay_offset') || ~isfield(obj.info,'workfunction')
                error('OxArpes:MissingMetadata', ...
                    'KZ conversion requires angular offset and work function metadata.');
            end
            validateattributes(obj.info.thetay_offset, {'numeric'}, ...
                {'scalar','real','finite'});
            validateattributes(obj.info.workfunction, {'numeric'}, ...
                {'vector','real','finite','nonempty'});
        
            % electron mass = 9.1093837 × 10-31 kilograms
            % hbar = 6.582119569...×10-16 eV⋅s
            % k (A-1) = CONST * sqrt(Ek (eV)) * sin(theta)
            CONST = 0.512316722;

            workfunction = mean(obj.info.workfunction(:));

            thetay_offset = obj.y - obj.info.thetay_offset;
            if any(abs(thetay_offset) >= 90)
                error('OxArpes:InvalidAngle', ...
                    'Offset-corrected emission angles must lie strictly between -90 and 90 degrees.');
            end
            hv_max = max(obj.x);
            hv_min = min(obj.x);
            thetay_max = max(thetay_offset);
            thetay_min = min(thetay_offset);
            energy_min = min(obj.z);
            kineticMinimum = hv_min + energy_min - workfunction;
            kineticMaximum = hv_max + max(obj.z) - workfunction;
            if kineticMinimum <= 0
                error('OxArpes:InvalidKineticEnergy', ...
                    'Photon energy plus binding-energy coordinate minus work function must stay positive.');
            end

            lowerLimits = CONST * sqrt([kineticMinimum kineticMaximum]) * sind(thetay_min);
            upperLimits = CONST * sqrt([kineticMinimum kineticMaximum]) * sind(thetay_max);
            k_min = max(lowerLimits);
            k_max = min(upperLimits);
            if k_min >= k_max
                error('OxArpes:NoCommonMomentumRange', ...
                    'The scans do not share a nonempty momentum interval.');
            end
            
            kn = length(thetay_offset);
            ky = linspace(k_min,k_max,kn);
            [E_EF,KY] = meshgrid(obj.z,ky);

            sampleEnergy = obj.z;
            sampleTheta = thetay_offset;
            sampleValue = obj.value;
            if sampleTheta(1) > sampleTheta(end)
                sampleTheta = fliplr(sampleTheta);
                sampleValue = flip(sampleValue,2);
            end
            if sampleEnergy(1) > sampleEnergy(end)
                sampleEnergy = fliplr(sampleEnergy);
                sampleValue = flip(sampleValue,3);
            end

            data_new = zeros(length(obj.x),kn,length(obj.z));
            for i = 1:length(obj.x)
                hv = obj.x(i);
                theta_new = asind(KY/CONST./sqrt(E_EF + hv - workfunction));
                sourcePlane = reshape(sampleValue(i,:,:), ...
                    numel(sampleTheta),numel(sampleEnergy));
                plane = interp2(sampleEnergy,sampleTheta,sourcePlane, ...
                    E_EF,theta_new,'spline',0);
                plane(~isfinite(plane)) = 0;
                data_new(i,:,:) = plane;
            end
            data_new(data_new<0) = 0;

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

