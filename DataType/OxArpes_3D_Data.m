classdef OxArpes_3D_Data
    %OXARPES_3D_DATA Base class for data sampled on three ARPES axes.
    %   X, Y, and Z are coordinate vectors and VALUE is indexed as
    %   VALUE(x,y,z). INFO stores acquisition metadata; methods provide
    %   common plotting, smoothing, slicing, cropping, and validation.
    
    properties
        name;
        info;

        x_name;
        x_unit;
        y_name;
        y_unit;
        z_name;
        z_unit;

        x; % deflector angle - Theta X [deg]
        y; % angle - Theta Y [deg]
        z; % kinetic energy - Energy [eV]
        value; % data
    end
    
    methods
        % constructor
        function obj = OxArpes_3D_Data(varargin)
            if nargin == 4
                obj.x = varargin{1}(:).';
                obj.y = varargin{2}(:).';
                obj.z = varargin{3}(:).';
                obj.value = varargin{4};
                obj.validate();
            elseif nargin == 1
                obj.x = varargin{1}.x(:).';
                obj.y = varargin{1}.y(:).';
                obj.z = varargin{1}.z(:).';
                obj.value = varargin{1}.value;
                obj.validate();
            elseif nargin ~= 0
                error('OxArpes:InvalidConstructor', ...
                    'Expected zero arguments, a data structure, or x, y, z, value.');
            end
        end

        % show / display
        function show(obj)

            UI = OxArpes_DataViewer_3D(obj);

        end

        function VolumeViewer(obj)
            %VOLUMEVIEWER Open the volume viewer with physical axis scaling.
            %   The array is permuted for the viewer's row/column convention.
            %   Comma-separated name-value syntax also works before R2021a.
            xx = (max(obj.x)-min(obj.x))/length(obj.x);
            yy = (max(obj.y)-min(obj.y))/length(obj.y);
            zz = (max(obj.z)-min(obj.z))/length(obj.z);

            rr = (max(obj.z)-min(obj.z)) / ((max(obj.x)-min(obj.x)+max(obj.y)-min(obj.y))/2);
            
            volumeViewer(permute(obj.value, [2 1 3]), 'ScaleFactors', [xx yy zz/rr]);
        end

        % basic operations
        function obj = set_contrast(obj)
            n_data = sort(obj.value(isfinite(obj.value)));
            if isempty(n_data)
                return
            end
            upbound = n_data(max(1, round(0.995*length(n_data))));
            obj.value(obj.value>upbound) = upbound;
        end
        
        function SDATA = Gaussian_smoothen_YZ(obj,sig_x,sig_y)

            validateattributes(sig_x, {'numeric'}, {'scalar','real','finite','positive'});
            validateattributes(sig_y, {'numeric'}, {'scalar','real','finite','positive'});

            % sigma - standard deviation
            rad_x = ceil(3.5*sig_x);
            rad_y = ceil(3.5*sig_y);
            x = -rad_x : rad_x;
            y = -rad_y : rad_y;
            [Y,X] = meshgrid(y,x);
            R = (X/sig_x).^2 + (Y/sig_y).^2;
            
            G = exp(-R/2);
            % normalize gaussian filter
            S = sum(G,'all');
            G = G./S;

            SDATA = obj;
            SDATA.name = [obj.name ' smooth'];
            
            for i = 1:size(obj.value,1)
                ma = squeeze(obj.value(i,:,:));
                w1 = rad_x;
                w2 = rad_y;
                L = size(ma,1); % y
                J = size(ma,2); % z
                
                map = zeros(L+2*w1, J+2*w2);
                map(1+w1:L+w1, 1+w2:J+w2) = ma;
    
                map(1:w1,:) = flip(map(1+w1:2*w1,:),1);
                map(w1+L+1:L+2*w1,:) = flip(map(L+1:L+w1,:),1);
                map(:,1:w2) = flip(map(:,1+w2:2*w2),2);
                map(:,w2+J+1:J+2*w2) = flip(map(:,J+1:J+w2),2);
    
                map = conv2(map,G,'same');

                SDATA.value(i,:,:) = map(1+w1:L+w1,1+w2:J+w2);
            end

        end

        function SDATA = Gaussian_smoothen_XY(obj,sig_x,sig_y)

            validateattributes(sig_x, {'numeric'}, {'scalar','real','finite','positive'});
            validateattributes(sig_y, {'numeric'}, {'scalar','real','finite','positive'});

            % sigma - standard deviation
            rad_x = ceil(3.5*sig_x);
            rad_y = ceil(3.5*sig_y);
            x = -rad_x : rad_x;
            y = -rad_y : rad_y;
            [Y,X] = meshgrid(y,x);
            R = (X/sig_x).^2 + (Y/sig_y).^2;
            
            G = exp(-R/2);
            % normalize gaussian filter
            S = sum(G,'all');
            G = G./S;

            SDATA = obj;
            SDATA.name = [obj.name ' smooth'];
            
            for i = 1:size(obj.value,3)
                ma = squeeze(obj.value(:,:,i));
                w1 = rad_x;
                w2 = rad_y;
                L = size(ma,1); % y
                J = size(ma,2); % z
                
                map = zeros(L+2*w1, J+2*w2);
                map(1+w1:L+w1, 1+w2:J+w2) = ma;
    
                map(1:w1,:) = flip(map(1+w1:2*w1,:),1);
                map(w1+L+1:L+2*w1,:) = flip(map(L+1:L+w1,:),1);
                map(:,1:w2) = flip(map(:,1+w2:2*w2),2);
                map(:,w2+J+1:J+2*w2) = flip(map(:,J+1:J+w2),2);
    
                map = conv2(map,G,'same');

                SDATA.value(:,:,i) = map(1+w1:L+w1,1+w2:J+w2);
            end

        end

        function SDATA = Z_Gaussian_smoothen(obj,sig_z)
            %Z_GAUSSIAN_SMOOTHEN Smooth each x-y location along the z axis.
            %   SIG_Z is the Gaussian standard deviation in samples. The
            %   normalized one-dimensional kernel acts only on dimension 3;
            %   the denominator corrects edge attenuation. Algorithm kept.
            % Smooth only along the third (z) dimension.  Edge weights are
            % renormalised so a constant volume remains constant.
            validateattributes(sig_z, {'numeric'}, {'scalar','real','finite','positive'});

            radius = ceil(3.5*sig_z);
            kernelAxis = -radius:radius;
            G = exp(-0.5*(kernelAxis/sig_z).^2);
            G = reshape(G/sum(G), 1, 1, []);

            inputValue = double(obj.value);
            numerator = convn(inputValue, G, 'same');
            denominator = convn(ones(size(inputValue)), G, 'same');

            SDATA = obj;
            SDATA.value = numerator ./ denominator;
            SDATA.name = [obj.name ' z-smooth'];

        end

        function [D2x_DATA,D2y_DATA] = second_derivative(obj,sig_x,sig_y)
            % >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            % Gaussian Smooth 
            
            validateattributes(sig_x, {'numeric'}, {'scalar','real','finite','positive'});
            validateattributes(sig_y, {'numeric'}, {'scalar','real','finite','positive'});

            % sigma - standard deviation
            rad_x = ceil(3.5*sig_x);
            rad_y = ceil(3.5*sig_y);
            x = -rad_x : rad_x;
            y = -rad_y : rad_y;
            [Y,X] = meshgrid(y,x);
            R = (X/sig_x).^2 + (Y/sig_y).^2;
            
            G = exp(-R/2);
            % normalize gaussian filter
            S = sum(G,'all');
            G = G./S;

            D2x_DATA = obj;
            D2x_DATA.name = [obj.name ' sd-x'];
            D2y_DATA = obj;
            D2y_DATA.name = [obj.name ' sd-y'];
            
            for i=1:size(obj.value,1)
                ma = squeeze(obj.value(i,:,:));
                w1 = rad_x;
                w2 = rad_y;
                L = size(ma,1); % x
                J = size(ma,2); % z
                
                map = zeros(L+2*w1, J+2*w2);
                map(1+w1:L+w1, 1+w2:J+w2) = ma;
    
                map(1:w1,:) = flip(map(1+w1:2*w1,:),1);
                map(w1+L+1:L+2*w1,:) = flip(map(L+1:L+w1,:),1);
                map(:,1:w2) = flip(map(:,1+w2:2*w2),2);
                map(:,w2+J+1:J+2*w2) = flip(map(:,J+1:J+w2),2);
                
    %             meshc(map);
    
                map = conv2(map,G,'same');
                
                % >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
                % Second Derivative
                
                [Fu,Fv] = gradient(map); % Dy Dx
                [Fuu,~] = gradient(Fu);
                [~,Fvv] = gradient(Fv);
                
                D2y_DATA.value(i,:,:) = -Fuu(1+w1:L+w1,1+w2:J+w2);
                D2x_DATA.value(i,:,:) = -Fvv(1+w1:L+w1,1+w2:J+w2);
            end
            
        end

        function KMAP = interpolate_x(obj)
            NX = 3;

            KMAP = obj;

            x0 = obj.x(1);
            x1 = obj.x(end);
            xn = length(obj.x);
            x_new = linspace(x0,x1,(xn-1)*NX +1);

            [Yq,Xq,Zq] = meshgrid(obj.y,x_new,obj.z);

            Vq = interp3(obj.y,obj.x,obj.z,obj.value,Yq,Xq,Zq,'spline');

            KMAP.x = x_new;
            KMAP.value = Vq;
        end

        function NEW_DATA = truncate(obj,xmin,xmax,ymin,ymax,zmin,zmax)
            NEW_DATA = obj;
            [~,nxmin] = min(abs(obj.x-xmin));
            [~,nxmax] = min(abs(obj.x-xmax));

            [~,nymin] = min(abs(obj.y-ymin));
            [~,nymax] = min(abs(obj.y-ymax));

            [~,nzmin] = min(abs(obj.z-zmin));
            [~,nzmax] = min(abs(obj.z-zmax));

            nx = sort([nxmin nxmax]);
            ny = sort([nymin nymax]);
            nz = sort([nzmin nzmax]);
            nxmin = nx(1); nxmax = nx(2);
            nymin = ny(1); nymax = ny(2);
            nzmin = nz(1); nzmax = nz(2);

            NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
            NEW_DATA.y = NEW_DATA.y(nymin:nymax);
            NEW_DATA.z = NEW_DATA.z(nzmin:nzmax);
            NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax,nzmin:nzmax);

        end

        function NEW_DATA = truncate_idx(obj,nxmin,nxmax,nymin,nymax,nzmin,nzmax)
            NEW_DATA = obj;

            nx = sort([nxmin nxmax]);
            ny = sort([nymin nymax]);
            nz = sort([nzmin nzmax]);
            nxmin = nx(1); nxmax = nx(2);
            nymin = ny(1); nymax = ny(2);
            nzmin = nz(1); nzmax = nz(2);

            validateattributes([nxmin nxmax], {'numeric'}, ...
                {'integer','positive','<=',numel(obj.x)});
            validateattributes([nymin nymax], {'numeric'}, ...
                {'integer','positive','<=',numel(obj.y)});
            validateattributes([nzmin nzmax], {'numeric'}, ...
                {'integer','positive','<=',numel(obj.z)});

            NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
            NEW_DATA.y = NEW_DATA.y(nymin:nymax);
            NEW_DATA.z = NEW_DATA.z(nzmin:nzmax);
            NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax,nzmin:nzmax);

        end

        function NEW_DATA = block_reduce(obj, nx, ny, nz)

            % 3D block averaging with independent block sizes:
            % nx : block size along x (1st dimension)
            % ny : block size along y (2nd dimension)
            % nz : block size along z (3rd dimension)
        
            if nargin < 4
                error('block_reduce requires nx, ny, nz.')
            end

            validateattributes(nx, {'numeric'}, {'scalar','integer','positive','<=',numel(obj.x)});
            validateattributes(ny, {'numeric'}, {'scalar','integer','positive','<=',numel(obj.y)});
            validateattributes(nz, {'numeric'}, {'scalar','integer','positive','<=',numel(obj.z)});
        
            if nx <= 1 && ny <= 1 && nz <= 1
                NEW_DATA = obj;
                return
            end
        
            NEW_DATA = obj;
        
            % Original dimensions
            Nx = length(obj.x);
            Ny = length(obj.y);
            Nz = length(obj.z);
        
            % Ensure divisibility
            Nx_new = floor(Nx / nx) * nx;
            Ny_new = floor(Ny / ny) * ny;
            Nz_new = floor(Nz / nz) * nz;
        
            % Truncate axes
            x_trunc = obj.x(1:Nx_new);
            y_trunc = obj.y(1:Ny_new);
            z_trunc = obj.z(1:Nz_new);
        
            % Truncate data
            V_trunc = obj.value(1:Nx_new, 1:Ny_new, 1:Nz_new);
        
            % Reshape into blocks:
            % (nx, Nx_new/nx, ny, Ny_new/ny, nz, Nz_new/nz)
            V_block = reshape(V_trunc, ...
                              nx, Nx_new/nx, ...
                              ny, Ny_new/ny, ...
                              nz, Nz_new/nz);
        
            % Average over block dimensions (1,3,5)
            V_block = mean(mean(mean(V_block,1), 3), 5);
            V_block = reshape(V_block, Nx_new/nx, Ny_new/ny, Nz_new/nz);
        
            % New axes: block-averaged coordinates
            x_block = reshape(x_trunc, nx, Nx_new/nx);
            x_block = mean(x_block, 1);
        
            y_block = reshape(y_trunc, ny, Ny_new/ny);
            y_block = mean(y_block, 1);
        
            z_block = reshape(z_trunc, nz, Nz_new/nz);
            z_block = mean(z_block, 1);
        
            % Assign
            NEW_DATA.x = x_block;
            NEW_DATA.y = y_block;
            NEW_DATA.z = z_block;
            NEW_DATA.value = V_block;
        
        end

        function R_DATA = z_rotate(obj,deg,zero_center)
            % Create Kx, Ky grids
            kx = obj.x;
            ky = obj.y;

            if ~zero_center
                kx = kx - mean(kx);
                ky = ky - mean(ky);
            end
            [KY, KX] = meshgrid(ky, kx);
            
            % Rotate by azimuth offset
            azimuth_cos = cosd(deg);
            azimuth_sin = sind(deg);

            KY_r =  azimuth_cos * KY + azimuth_sin * KX;
            KX_r = -azimuth_sin * KY + azimuth_cos * KX;
        
            % Resample data
            data_new = zeros(length(obj.x),length(obj.y),length(obj.z));
            for i = 1:length(obj.z)
        
                % Interpolate data
                data_new(:,:,i) = interp2(ky, kx, obj.value(:,:,i), KY_r, KX_r, 'cubic', 0);
            end
            data_new(data_new < 0) = 0;

            R_DATA = obj;
            R_DATA.value = data_new;
        end

        % others
        function dx = get_dx(obj)
            nx = length(obj.x);
            P = polyfit(1:nx,obj.x,1);
            dx = P(1);
        end

        function dy = get_dy(obj)
            ny = length(obj.y);
            P = polyfit(1:ny,obj.y,1);
            dy = P(1);
        end

        function dz = get_dz(obj)
            nz = length(obj.z);
            P = polyfit(1:nz,obj.z,1);
            dz = P(1);
        end

        function CUT = get_slice(obj,direction,pos,width)

            validateattributes(pos, {'numeric'}, {'scalar','real','finite'});
            validateattributes(width, {'numeric'}, {'scalar','real','finite','nonnegative'});
            if ~(ischar(direction) || (isstring(direction) && isscalar(direction)))
                error('OxArpes:InvalidDirection', ...
                    'Slice direction must be ''x'', ''y'', or ''z''.');
            end

            CUT = [];

            switch lower(char(direction))
                case 'x'
                    xData = obj.y;
                    yData = obj.z;
                    xData_name = obj.y_name;
                    xData_unit = obj.y_unit;
                    yData_name = obj.z_name;
                    yData_unit = obj.z_unit;
                    cond = ( abs(obj.x - pos) <= width/2 );
                    if ~any(cond)
                        [~,cond] = min(abs(obj.x - pos));
                    end
                    sliceData = reshape(mean(obj.value(cond,:,:),1), ...
                        numel(obj.y),numel(obj.z));
                case 'y'
                    xData = obj.x;
                    yData = obj.z;
                    xData_name = obj.x_name;
                    xData_unit = obj.x_unit;
                    yData_name = obj.z_name;
                    yData_unit = obj.z_unit;
                    cond = ( abs(obj.y - pos) <= width/2 );
                    if ~any(cond)
                        [~,cond] = min(abs(obj.y - pos));
                    end
                    sliceData = reshape(mean(obj.value(:,cond,:),2), ...
                        numel(obj.x),numel(obj.z));
                case 'z'
                    xData = obj.x;
                    yData = obj.y;
                    xData_name = obj.x_name;
                    xData_unit = obj.x_unit;
                    yData_name = obj.y_name;
                    yData_unit = obj.y_unit;
                    cond = ( abs(obj.z - pos) <= width/2 );
                    if ~any(cond)
                        [~,cond] = min(abs(obj.z - pos));
                    end
                    sliceData = reshape(mean(obj.value(:,:,cond),3), ...
                        numel(obj.x),numel(obj.y));
                otherwise
                    error('OxArpes:InvalidDirection', ...
                        'Slice direction must be ''x'', ''y'', or ''z''.');
            end

            CUT = OxA_CUT(xData,yData,sliceData);
            CUT.x_name = xData_name;
            CUT.y_name = yData_name;
            CUT.x_unit = xData_unit;
            CUT.y_unit = yData_unit;
            CUT.info = obj.info;

        end

        function validate(obj)
            %VALIDATE Check the public 3-D axis/value contract.
            validateattributes(obj.x, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.y, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.z, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.value, {'numeric','logical'}, {'nonempty'});

            expected = [numel(obj.x), numel(obj.y), numel(obj.z)];
            actual = size(obj.value);
            actual(end+1:3) = 1;
            if ~isequal(actual(1:3), expected) || numel(actual) > 3
                error('OxArpes:DimensionMismatch', ...
                    'value must have size [numel(x), numel(y), numel(z)].');
            end

            axesToCheck = {obj.x, obj.y, obj.z};
            axisNames = {'x','y','z'};
            for iAxis = 1:3
                if numel(axesToCheck{iAxis}) > 1
                    delta = diff(axesToCheck{iAxis});
                    if any(delta == 0)
                        error('OxArpes:DuplicateAxis', ...
                            '%s must not contain duplicate adjacent coordinates.', axisNames{iAxis});
                    elseif ~(all(delta > 0) || all(delta < 0))
                        error('OxArpes:NonMonotonicAxis', ...
                            '%s must be strictly increasing or strictly decreasing.', axisNames{iAxis});
                    end
                end
            end
        end
        
    end
end

