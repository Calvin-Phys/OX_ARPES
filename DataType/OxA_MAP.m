 classdef OxA_MAP < OxArpes_3D_Data
    %OXA_MAP Data object for angular ARPES maps across kinetic energy.
    %   The x/y axes are emission angles and z is kinetic energy. kconvert
    %   applies angular offsets, azimuth rotation, and energy-dependent
    %   momentum conversion to produce an in-plane momentum map.
    
    properties
    end
    
    methods
        function obj = OxA_MAP(varargin)
            %OXA_MAP Construct an angular map and initialize axis metadata.
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
            %KCONVERT Convert the angle-angle-energy map to kx-ky-energy.
            %   The physical conversion and rotated bounds are documented
            %   inline below; interpolation maps the measured planes onto a
            %   regular momentum grid.

            obj.validate();
            requiredInfo = {'thetax_offset','thetay_offset','azimuth_offset', ...
                'photon_energy','workfunction'};
            for iField = 1:numel(requiredInfo)
                if ~isfield(obj.info, requiredInfo{iField}) || ...
                        isempty(obj.info.(requiredInfo{iField}))
                    error('OxArpes:MissingMetadata', ...
                        'MAP k conversion requires info.%s.', requiredInfo{iField});
                end
            end

            for iField = 1:numel(requiredInfo)
                validateattributes(obj.info.(requiredInfo{iField}), {'numeric'}, ...
                    {'scalar','real','finite'}, mfilename, ['info.' requiredInfo{iField}]);
            end

            if any(obj.z <= 0)
                error('OxArpes:InvalidKineticEnergy', ...
                    'MAP k conversion requires strictly positive kinetic energies.');
            end
            if ~(all(diff(obj.x) > 0) || all(diff(obj.x) < 0)) || ...
                    ~(all(diff(obj.y) > 0) || all(diff(obj.y) < 0))
                error('OxArpes:InvalidAxis', ...
                    'MAP angular axes must be strictly monotonic.');
            end

            % Constants
            CONST = 0.512316722; % [sqrt(2m)/hbar] * 1/sqrt(eV)
        
            % Kx = CONST * sqrt(Ek) .* cosd(Y0) .* sind(X0);
            % Ky = CONST * sqrt(Ek) .* sind(Y0);
        
            % Theta offset
            y_offset = obj.y - obj.info.thetay_offset;
            x_offset = obj.x - obj.info.thetax_offset;
            if any(abs(x_offset) >= 90) || any(abs(y_offset) >= 90)
                error('OxArpes:InvalidAngle', ...
                    'Offset-corrected emission angles must lie strictly between -90 and 90 degrees.');
            end

            sampleX = x_offset;
            sampleY = y_offset;
            sampleValue = obj.value;
            if sampleX(1) > sampleX(end)
                sampleX = fliplr(sampleX);
                sampleValue = flip(sampleValue,1);
            end
            if sampleY(1) > sampleY(end)
                sampleY = fliplr(sampleY);
                sampleValue = flip(sampleValue,2);
            end
        
            % Find K's boundary
            energy_min = min(obj.z);
            energy_max = max(obj.z);
        
            % Precompute azimuth offset sines and cosines
            % keep -45<azimuth_offset<45
            azimuth_cos = cosd(obj.info.azimuth_offset);
            azimuth_sin = sind(obj.info.azimuth_offset);
        
            % Emission momentum before the in-plane azimuth rotation follows
            % kx = C*sqrt(Ek)*cos(theta_y)*sin(theta_x),
            % ky = C*sqrt(Ek)*sin(theta_y). The configured azimuth rotates
            % this vector by -phi: [kx';ky'] = [cos(phi) sin(phi); ...
            %                                   -sin(phi) cos(phi)]*[kx;ky].
            % Because |theta_x| and |theta_y| are below 90 degrees, each
            % rotated component is monotonic in theta_x for fixed theta_y.
            % Its extrema therefore occur at the two theta_x boundaries;
            % include the possible stationary theta_y values and both energy
            % endpoints to bound centred and off-centre maps consistently.
            thetaXBounds = [sampleX(1), sampleX(end)];
            thetaYBounds = [sampleY(1), sampleY(end)];
            thetaYCandidates = thetaYBounds;
            for iXBound = 1:numel(thetaXBounds)
                sinX = sind(thetaXBounds(iXBound));
                componentCos = [azimuth_cos * sinX, -azimuth_sin * sinX];
                componentSin = [azimuth_sin, azimuth_cos];
                for iComponent = 1:2
                    stationaryAngle = atan2d(componentSin(iComponent), ...
                        componentCos(iComponent));
                    for iPeriod = -1:1
                        candidate = stationaryAngle + 180 * iPeriod;
                        if candidate > thetaYBounds(1) && candidate < thetaYBounds(2)
                            thetaYCandidates(end + 1) = candidate; %#ok<AGROW>
                        end
                    end
                end
            end

            thetaXCandidates = repmat(thetaXBounds(:), 1, numel(thetaYCandidates));
            thetaYCandidates = repmat(thetaYCandidates, numel(thetaXBounds), 1);
            thetaYCandidates = thetaYCandidates(:).';
            thetaXCandidates = thetaXCandidates(:).';
            energyBounds = unique([energy_min, energy_max]);
            kxBounds = zeros(1, numel(thetaXCandidates) * numel(energyBounds));
            kyBounds = zeros(size(kxBounds));
            boundIndex = 0;
            for iEnergy = 1:numel(energyBounds)
                commonTerm = CONST * sqrt(energyBounds(iEnergy));
                kxSource = commonTerm .* cosd(thetaYCandidates) .* sind(thetaXCandidates);
                kySource = commonTerm .* sind(thetaYCandidates);
                kxRotated = azimuth_cos .* kxSource + azimuth_sin .* kySource;
                kyRotated = -azimuth_sin .* kxSource + azimuth_cos .* kySource;
                range = boundIndex + (1:numel(kxSource));
                kxBounds(range) = kxRotated;
                kyBounds(range) = kyRotated;
                boundIndex = boundIndex + numel(kxSource);
            end

            kx_min = min(kxBounds);
            kx_max = max(kxBounds);
            ky_min = min(kyBounds);
            ky_max = max(kyBounds);

            % Preserve approximately the original angular sampling density
            % after rotation without relying on a centred angular range.
            kxn = max(2, ceil(abs(azimuth_cos)*numel(x_offset) + ...
                abs(azimuth_sin)*numel(y_offset)));
            kyn = max(2, ceil(abs(azimuth_cos)*numel(y_offset) + ...
                abs(azimuth_sin)*numel(x_offset)));
        
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
                yArgument = KY_r / CONST ./ sqrt(Eki);
                validQuery = abs(yArgument) <= 1;
                Y0 = nan(size(yArgument));
                Y0(validQuery) = asind(yArgument(validQuery));

                xArgument = KX_r / CONST / sqrt(Eki) ./ cosd(Y0);
                validQuery = validQuery & isfinite(xArgument) & abs(xArgument) <= 1;
                X0 = nan(size(xArgument));
                X0(validQuery) = asind(xArgument(validQuery));

                % Interpolate data
                plane = interp2(sampleY, sampleX, sampleValue(:,:,i), Y0, X0, 'spline', 0);
                plane(~isfinite(plane)) = 0;
                data_new(:,:,i) = plane;
            end
            data_new(data_new < 0) = 0;
        
            % Calculate binding energy
            be = obj.z - (obj.info.photon_energy - obj.info.workfunction);
        
            % Create KMAP
            KMAP = OxA_MAP(kx, ky, be, data_new);
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

%         function KMAP = kconvert(obj)
% 
%             % electron mass = 9.1093837 × 10-31 kilograms
%             % hbar = 6.582119569...×10-16 eV⋅s
%             % k (A-1) = CONST [sqrt(2m)/hbar] * sqrt(Ek (eV)) * sin(theta)
%             CONST = 0.512316722;
% 
%             %% theta offset
%             y_offset = obj.y - obj.info.thetay_offset;
%             x_offset = obj.x - obj.info.thetax_offset;
% 
%             %% find K's boundary
% 
% %             Kx = CONST * sqrt(Ek) .* cosd(Y0) .* sind(X0);
% %             Ky = CONST * sqrt(Ek) .* sind(Y0);
% 
% 
%             thetax_max = max(x_offset);
%             thetax_min = min(x_offset);
%             thetay_max = max(y_offset);
%             thetay_min = min(y_offset);
%             energy_min = min(obj.z);
%             energy_max = max(obj.z);
% 
%             if thetax_max>0 && thetax_min<0 && thetay_max>0 && thetay_min<0 % common case
%                 kx_max = CONST * sqrt(energy_min) * sind(thetax_max);
%                 kx_min = CONST * sqrt(energy_min) * sind(thetax_min);
%                 ky_max = CONST * sqrt(energy_min) * sind(thetay_max);
%                 ky_min = CONST * sqrt(energy_min) * sind(thetay_min);
%             else % special case
%                 kx_max = max([...
%                     CONST * sqrt(energy_max) .* cosd(thetay_max) .* sind(thetax_max),...
%                     CONST * sqrt(energy_max) .* cosd(thetay_min) .* sind(thetax_max),...
%                     CONST * sqrt(energy_min) .* cosd(thetay_max) .* sind(thetax_max),...
%                     CONST * sqrt(energy_min) .* cosd(thetay_min) .* sind(thetax_max)]);
%                 kx_min = min([...
%                     CONST * sqrt(energy_max) .* cosd(thetay_max) .* sind(thetax_min),...
%                     CONST * sqrt(energy_max) .* cosd(thetay_min) .* sind(thetax_min),...
%                     CONST * sqrt(energy_min) .* cosd(thetay_max) .* sind(thetax_min),...
%                     CONST * sqrt(energy_min) .* cosd(thetay_min) .* sind(thetax_min)]);
%                 ky_max = max([ ...
%                     CONST * sqrt(energy_max) .* sind(thetay_max),...
%                     CONST * sqrt(energy_min) .* sind(thetay_max)]);
%                 ky_min = min([ ...
%                     CONST * sqrt(energy_max) .* sind(thetay_min),...
%                     CONST * sqrt(energy_min) .* sind(thetay_min)]);
%             end
% 
%             kxn = length(x_offset);
%             kyn = length(y_offset);
%             kx = linspace(kx_min,kx_max,kxn);
%             ky = linspace(ky_min,ky_max,kyn);
%             [KY,KX] = meshgrid(ky,kx);
% 
%             data_new = zeros(size(obj.value));
%             for i = 1:length(obj.z)
% 
%                 Eki = obj.z(i);
%                 
%                 %thetay_new 
%                 Y0 = asind( KY/CONST ./ sqrt(Eki) );
%                 %thetax_new 
% %                 X0 = asind( KX/CONST^2/Eki .* sqrt(CONST^2 *Eki -KY.^2) );
%                 X0 = asind( KX/CONST/sqrt(Eki) ./ cosd(Y0) );
%                 
%                 Yq = + cosd(obj.info.azimuth_offset) * Y0 + sind(obj.info.azimuth_offset) * X0;
%                 Xq = - sind(obj.info.azimuth_offset) * Y0 + cosd(obj.info.azimuth_offset) * X0;
% 
%                 data_new(:,:,i) = interp2(y_offset,x_offset,obj.value(:,:,i),Yq,Xq,'spline',0);
%             end
%             data_new(data_new<0) = 0;
% 
%             be = obj.z - (obj.info.photon_energy - obj.info.workfunction);
% 
%             KMAP = OxA_MAP(kx,ky,be,data_new);
%             KMAP.x_name = '{\it k}_x';
%             KMAP.x_unit = 'Å^{-1}';
%             KMAP.y_name = '{\it k}_y';
%             KMAP.y_unit = 'Å^{-1}';
%             KMAP.z_name = '{\it E}-{\it E}_F';
%             KMAP.z_unit = 'eV';
%             KMAP.name = [obj.name '_ksp'];
%             KMAP.info = obj.info;
% 
% 
% 
%         end
%         function KMAP = kconvert_nano(obj)
% 
%             % find k boundary
%             Ek1 = min(obj.z);
%             Ek2 = max(obj.z);
%             y_offset = mean(obj.y);
%             thetaY = obj.y - y_offset;
%             thetaX = obj.x;
%             
%             [Y0,X0] = meshgrid(thetaY,thetaX);
%             Kx1 = zeros(size(X0));
%             Ky1 = zeros(size(X0));
%             Kz1 = zeros(size(X0));
%             Kx2 = zeros(size(X0));
%             Ky2 = zeros(size(X0));
%             Kz2 = zeros(size(X0));
%             for i=1:length(thetaX)
%                 for j=1:length(thetaY)
%                     [Kx1(i,j),Ky1(i,j),Kz1(i,j)] = rotate2K(Ek1,y_offset,X0(i,j),Y0(i,j));
%                     [Kx2(i,j),Ky2(i,j),Kz2(i,j)] = rotate2K(Ek2,y_offset,X0(i,j),Y0(i,j));
%                 end
%             end
% 
%             % generate KX/KY mesh
%             Kx_min = min([Kx1(:);Kx2(:)]);
%             Kx_max = max([Kx1(:);Kx2(:)]);
%             Ky_min = min([Ky1(:);Ky2(:)]);
%             Ky_max = max([Ky1(:);Ky2(:)]);
%             
%             kx = linspace(Kx_min,Kx_max, round(1.5*length(thetaX)));
%             ky = linspace(Ky_min,Ky_max, round(1.5*length(thetaY)));
%             [KY,KX] = meshgrid(ky,kx);
% 
%             % interpolate data_new
%             data_new = zeros(length(kx),length(ky),length(obj.z));
%             tic
%             for s=1:length(obj.z)
%                 Kx3 = zeros(size(X0));
%                 Ky3 = zeros(size(X0));
%                 for i=1:length(thetaX)
%                     for j=1:length(thetaY)
%                         [Kx3(i,j),Ky3(i,j),~] = rotate2K(obj.z(s),y_offset,X0(i,j),Y0(i,j));
%                     end
%                 end
%                 value3 = obj.value(:,:,s);
%                 % two methods: no obvious differences
%                 data_new(:,:,s) = griddata(Kx3(:),Ky3(:),value3(:),KX,KY,'natural');
%             %     F = scatteredInterpolant(Kx3(:),Ky3(:),value3(:),'natural','none');
%             %     data_new(:,:,s) = F(KX,KY);
%                 disp(s);
%             end
%             toc
%             data_new(data_new<0) = 0;
%             data_new(isnan(data_new))=0;
% 
%             be = obj.z - (obj.info.photon_energy - obj.info.workfunction);
% 
%             KMAP = OxA_MAP(kx,ky,be,data_new);
%             KMAP.x_name = 'K_x';
%             KMAP.x_unit = 'Å^{-1}';
%             KMAP.y_name = 'K_y';
%             KMAP.y_unit = 'Å^{-1}';
%             KMAP.z_name = 'Binding Energy';
%             KMAP.z_unit = 'eV';
%             KMAP.name = [obj.name '_ksp'];
%             KMAP.info = obj.info;
% 
%             function [kx,ky,kz] = rotate2K(Eki,y_offset,thetax,thetay)
%                 % electron mass = 9.1093837 × 10-31 kilograms
%                 % hbar = 6.582119569...×10-16 eV⋅s
%                 % k (A-1) = CONST [sqrt(2m)/hbar] * sqrt(Ek (eV)) * sin(theta)
%                 CONST = 0.512316722;
%                 z_i = [0 0 1]';
%                 z_f = RM(RM([0 cosd(y_offset) -sind(y_offset)]',thetax)*[1 0 0]',-thetay)*RM([0 cosd(y_offset) -sind(y_offset)]',thetax)*RM([1 0 0]',-y_offset)*z_i;
%                 kx = CONST* sqrt(Eki)* z_f(1);
%                 ky = CONST* sqrt(Eki)* z_f(2);
%                 kz = CONST* sqrt(Eki)* z_f(3);
%             end
%             
%             
%             function M = RM(U,deg)
%             %ROTATION_MATRIX Summary of this function goes here
%             %   Detailed explanation goes here
%                 ux = U(1);
%                 uy = U(2);
%                 uz = U(3);
%                 M =[cosd(deg)+ux^2*(1-cosd(deg)), ux*uy*(1-cosd(deg))-uz*sind(deg), ux*uz*(1-cosd(deg))+uy*sind(deg);
%                     uy*ux*(1-cosd(deg))+uz*sind(deg), cosd(deg)+uy^2*(1-cosd(deg)), uy*uz*(1-cosd(deg))-ux*sind(deg);
%                     uz*ux*(1-cosd(deg))-uy*sind(deg), uz*uy*(1-cosd(deg))+ux*sind(deg), cosd(deg)+uz^2*(1-cosd(deg))];
%             end
% 
% 
%         end

    end
end

