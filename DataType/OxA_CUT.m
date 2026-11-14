classdef OxA_CUT < OxArpes_2D_Data
    % OxA_CUT: A class for handling 2D ARPES data - CUT.
    % This class inherits from the OxArpes_2D_Data class and adds methods
    % for processing ARPES data, such as converting to k-space, smoothing,
    % and calculating second derivatives and curvature.
    
    properties
    end
    
    methods
        function obj = OxA_CUT(varargin)
            % OxA_CUT: Class constructor.
            % Initializes the properties of the class with default values.
            obj@OxArpes_2D_Data(varargin{:});

            obj.name = 'CUT';
            obj.x_name = 'Angle Y';
            obj.x_unit = 'deg';
            obj.y_name = 'Kinetic Energy';
            obj.y_unit = 'eV';

            obj.info.thetay_offset = 0;
            obj.info.photon_energy = 21.2;
            obj.info.workfunction = 4.5;
        end

        function KCUT = kconvert(obj)
            % kconvert: Converts the theta values of ARPES data to k-space.
            % Uses a simple formula to convert the theta values to k-space.
            % Returns a new OxA_CUT object with k-space data.

            obj.validate();
            requiredInfo = {'thetay_offset','photon_energy','workfunction'};
            for iField = 1:numel(requiredInfo)
                if ~isfield(obj.info, requiredInfo{iField}) || ...
                        isempty(obj.info.(requiredInfo{iField}))
                    error('OxArpes:MissingMetadata', ...
                        'CUT k conversion requires info.%s.', requiredInfo{iField});
                end
            end
            validateattributes(obj.info.photon_energy, {'numeric'}, {'scalar','real','finite'});
            validateattributes(obj.info.workfunction, {'numeric'}, {'scalar','real','finite'});
            validateattributes(obj.info.thetay_offset, {'numeric'}, {'scalar','real','finite'});
            if any(obj.y <= 0)
                error('OxArpes:InvalidKineticEnergy', ...
                    'CUT k conversion requires strictly positive kinetic energies.');
            end
            if ~(all(diff(obj.x) > 0) || all(diff(obj.x) < 0))
                error('OxArpes:InvalidAxis', 'The CUT angle axis must be strictly monotonic.');
            end

            % electron mass = 9.1093837 × 10-31 kilograms
            % hbar = 6.582119569...×10-16 eV⋅s
            % k (A-1) = CONST * sqrt(Ek (eV)) * sin(theta)
            CONST = 0.512316722;

            theta_offset = obj.x - obj.info.thetay_offset;
            if any(abs(theta_offset) >= 90)
                error('OxArpes:InvalidAngle', ...
                    'Offset-corrected emission angles must lie strictly between -90 and 90 degrees.');
            end

            theta_max = max(theta_offset);
            theta_min = min(theta_offset);
            energy_min = min(obj.y);
            
            
            k_max = CONST * sqrt(energy_min) * sind(theta_max);
            k_min = CONST * sqrt(energy_min) * sind(theta_min);
            
            kn = length(theta_offset);
            kx = linspace(k_min,k_max,kn);

            data_new = zeros(size(obj.value));
            for i = 1:length(obj.y)
                theta_new = asind(kx/CONST./sqrt(obj.y(i)));
                data_new(:,i) = interp1(theta_offset,obj.value(:,i),theta_new,'pchip');
            end

            be = obj.y - (obj.info.photon_energy - obj.info.workfunction);
            KCUT = OxA_CUT(kx,be,data_new);
            KCUT.x_name = '{\itk}_y';
            KCUT.x_unit = 'Å^{-1}';
            KCUT.y_name = '{\itE} - {\itE}_F';
            KCUT.y_unit = 'eV';
            KCUT.name = [obj.name '_ksp'];
            KCUT.info = obj.info;
        end

        function EDC = getEDC(obj,x0,x1)
            %GETEDC Average intensity over the selected angular interval.
            [~,nx0] = min(abs(obj.x-x0));
            [~,nx1] = min(abs(obj.x-x1));
            nx = sort([nx0 nx1]);
            nx0 = nx(1);
            nx1 = nx(2);
            EDC = mean(obj.value(nx0:nx1,:),1);
%             figure
%             plot(obj.y,EDC);
        end
    end
end

