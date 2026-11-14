classdef OxArpes_4D_Data
    %OXARPES_4D_DATA Base class for ARPES data sampled on four axes.
    %   Coordinates are X, Y, K, and Z. VALUE uses canonical indexing
    %   VALUE(x,y,k,z), with each axis vector matching its array dimension.
    %   Methods provide plotting, cropping, block averaging, and validation.
    
    properties
        name;
        info;

        x_name;
        x_unit;
        y_name;
        y_unit;
        z_name;
        z_unit;
        k_name;
        k_unit;

        x; % position X [mm]
        y; % position Y [mm]
        z; % kinetic energy - Energy [eV]
        k; % momentum - angle [deg]
        value; % canonical order: value(x, y, k, z)
    end
    
    methods
        % constructor
        function obj = OxArpes_4D_Data(varargin)
            %OXARPES_4D_DATA Construct from axes and a four-dimensional array.
            %   The five-argument form is X, Y, Z, K, VALUE for compatibility;
            %   VALUE dimensions must be ordered (x,y,k,z).
            if nargin == 5
                obj.x = varargin{1}(:).';
                obj.y = varargin{2}(:).';
                obj.z = varargin{3}(:).';
                obj.k = varargin{4}(:).';
                obj.value = varargin{5};
                obj.validate();
            elseif nargin == 1
                obj.x = varargin{1}.x(:).';
                obj.y = varargin{1}.y(:).';
                obj.z = varargin{1}.z(:).';
                obj.k = varargin{1}.k(:).';
                obj.value = varargin{1}.value;
                obj.validate();
            elseif nargin ~= 0
                error('OxArpes:InvalidConstructor', ...
                    'Expected zero arguments, a data structure, or x, y, z, k, value.');
            end
        end

        % show / display
        function show(obj)
            %SHOW Open the interactive viewer for this four-dimensional data.

            UI = OxArpes_DataViewer_4D(obj);

        end


        % basic operations
        function NEW_DATA = truncate(obj,xmin,xmax,ymin,ymax,zmin,zmax,kmin,kmax)
            %TRUNCATE Crop the object to limits on x, y, z, and k coordinates.
            [~,nx0] = min(abs(obj.x-xmin));
            [~,nx1] = min(abs(obj.x-xmax));
            [~,ny0] = min(abs(obj.y-ymin));
            [~,ny1] = min(abs(obj.y-ymax));
            [~,nz0] = min(abs(obj.z-zmin));
            [~,nz1] = min(abs(obj.z-zmax));
            [~,nk0] = min(abs(obj.k-kmin));
            [~,nk1] = min(abs(obj.k-kmax));

            NEW_DATA = obj.truncate_idx(nx0,nx1,ny0,ny1,nz0,nz1,nk0,nk1);
        end

        function NEW_DATA = truncate_idx(obj,nx0,nx1,ny0,ny1,nz0,nz1,nk0,nk1)
            %TRUNCATE_IDX Crop with inclusive index limits on each coordinate.
            nx = sort([nx0 nx1]);
            ny = sort([ny0 ny1]);
            nz = sort([nz0 nz1]);
            nk = sort([nk0 nk1]);

            validateattributes(nx, {'numeric'}, {'integer','positive','<=',numel(obj.x)});
            validateattributes(ny, {'numeric'}, {'integer','positive','<=',numel(obj.y)});
            validateattributes(nz, {'numeric'}, {'integer','positive','<=',numel(obj.z)});
            validateattributes(nk, {'numeric'}, {'integer','positive','<=',numel(obj.k)});

            NEW_DATA = obj;
            NEW_DATA.x = obj.x(nx(1):nx(2));
            NEW_DATA.y = obj.y(ny(1):ny(2));
            NEW_DATA.z = obj.z(nz(1):nz(2));
            NEW_DATA.k = obj.k(nk(1):nk(2));
            NEW_DATA.value = obj.value(nx(1):nx(2), ny(1):ny(2), ...
                nk(1):nk(2), nz(1):nz(2));
        end

        function NEW_DATA = block_reduce(obj, nx, ny, nz, nk)
        %BLOCK_REDUCE Average contiguous blocks using independent axis sizes.
        %
        % nx : block size along x (1st dimension)
        % ny : block size along y (2nd dimension)
        % nz : block size along z (4th value dimension)
        % nk : block size along k (3rd value dimension)
        
            if nargin < 5
                error('block_reduce requires nx, ny, nz, nk.')
            end

            validateattributes(nx, {'numeric'}, {'scalar','integer','positive','<=',numel(obj.x)});
            validateattributes(ny, {'numeric'}, {'scalar','integer','positive','<=',numel(obj.y)});
            validateattributes(nz, {'numeric'}, {'scalar','integer','positive','<=',numel(obj.z)});
            validateattributes(nk, {'numeric'}, {'scalar','integer','positive','<=',numel(obj.k)});
        
            if nx <= 1 && ny <= 1 && nz <= 1 && nk <= 1
                NEW_DATA = obj;
                return
            end
        
            NEW_DATA = obj;
        
            % Original dimensions
            Nx = length(obj.x);
            Ny = length(obj.y);
            Nz = length(obj.z);
            Nk = length(obj.k);
        
            % Ensure divisibility
            Nx_new = floor(Nx / nx) * nx;
            Ny_new = floor(Ny / ny) * ny;
            Nz_new = floor(Nz / nz) * nz;
            Nk_new = floor(Nk / nk) * nk;
        
            % Truncate axes
            x_trunc = obj.x(1:Nx_new);
            y_trunc = obj.y(1:Ny_new);
            z_trunc = obj.z(1:Nz_new);
            k_trunc = obj.k(1:Nk_new);
        
            % Truncate data
            V_trunc = obj.value(1:Nx_new, 1:Ny_new, 1:Nk_new, 1:Nz_new);
        
            % Reshape into blocks:
            % (nx, Nx_new/nx, ny, Ny_new/ny, nk, Nk_new/nk, nz, Nz_new/nz)
            V_block = reshape(V_trunc, ...
                              nx, Nx_new/nx, ...
                              ny, Ny_new/ny, ...
                              nk, Nk_new/nk, ...
                              nz, Nz_new/nz);
        
            % Average over block dimensions (1,3,5,7)
            V_block = mean(V_block, 1);
            V_block = mean(V_block, 3);
            V_block = mean(V_block, 5);
            V_block = mean(V_block, 7);
            V_block = reshape(V_block, Nx_new/nx, Ny_new/ny, Nk_new/nk, Nz_new/nz);
        
            % New axes: block-averaged coordinates
            x_block = reshape(x_trunc, nx, Nx_new/nx);
            x_block = mean(x_block, 1);
        
            y_block = reshape(y_trunc, ny, Ny_new/ny);
            y_block = mean(y_block, 1);
        
            z_block = reshape(z_trunc, nz, Nz_new/nz);
            z_block = mean(z_block, 1);
        
            k_block = reshape(k_trunc, nk, Nk_new/nk);
            k_block = mean(k_block, 1);
        
            % Assign
            NEW_DATA = obj;
            NEW_DATA.x = x_block;
            NEW_DATA.y = y_block;
            NEW_DATA.z = z_block;
            NEW_DATA.k = k_block;
            NEW_DATA.value = V_block;
        end

        function validate(obj)
            %VALIDATE Check metadata, axis lengths, and VALUE's (x,y,k,z) shape.
            %VALIDATE Check the canonical value(x,y,k,z) contract.
            validateattributes(obj.x, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.y, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.z, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.k, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.value, {'numeric','logical'}, {'nonempty'});

            expected = [numel(obj.x), numel(obj.y), numel(obj.k), numel(obj.z)];
            actual = size(obj.value);
            actual(end+1:4) = 1;
            if ~isequal(actual(1:4), expected) || numel(actual) > 4
                error('OxArpes:DimensionMismatch', ...
                    'value must have size [numel(x), numel(y), numel(k), numel(z)].');
            end

            axesToCheck = {obj.x, obj.y, obj.k, obj.z};
            axisNames = {'x','y','k','z'};
            for iAxis = 1:4
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
        % 
        % 
        % 
        % % others
        % function dx = get_dx(obj)
        %     nx = length(obj.x);
        %     P = polyfit(1:nx,obj.x,1);
        %     dx = P(1);
        % end
        % 
        % function dy = get_dy(obj)
        %     ny = length(obj.y);
        %     P = polyfit(1:ny,obj.y,1);
        %     dy = P(1);
        % end
        % 
        % function dz = get_dz(obj)
        %     nz = length(obj.z);
        %     P = polyfit(1:nz,obj.z,1);
        %     dz = P(1);
        % end
        % 
        % function CUT = get_slice(obj,direction,pos,width)
        % 
        %     CUT = [];
        % 
        %     switch direction
        %         case 'x'
        %             xData = obj.y;
        %             yData = obj.z;
        %             xData_name = obj.y_name;
        %             xData_unit = obj.y_unit;
        %             yData_name = obj.z_name;
        %             yData_unit = obj.z_unit;
        %             cond = ( abs(obj.x - pos) <= width/2 );
        %             if ~any(cond)
        %                 [~,cond] = min(abs(obj.x - pos));
        %             end
        %             sliceData = squeeze(mean(obj.value(cond,:,:),1));
        %         case 'y'
        %             xData = obj.x;
        %             yData = obj.z;
        %             xData_name = obj.x_name;
        %             xData_unit = obj.x_unit;
        %             yData_name = obj.z_name;
        %             yData_unit = obj.z_unit;
        %             cond = ( abs(obj.y - pos) <= width/2 );
        %             if ~any(cond)
        %                 [~,cond] = min(abs(obj.y - pos));
        %             end
        %             sliceData = squeeze(mean(obj.value(:,cond,:),2));
        %         otherwise
        %             xData = obj.x;
        %             yData = obj.y;
        %             xData_name = obj.x_name;
        %             xData_unit = obj.x_unit;
        %             yData_name = obj.y_name;
        %             yData_unit = obj.y_unit;
        %             cond = ( abs(obj.z - pos) <= width/2 );
        %             if ~any(cond)
        %                 [~,cond] = min(abs(obj.z - pos));
        %             end
        %             sliceData = squeeze(mean(obj.value(:,:,cond),3));
        %     end
        % 
        %     CUT = OxA_CUT(xData,yData,sliceData);
        %     CUT.x_name = xData_name;
        %     CUT.y_name = yData_name;
        %     CUT.x_unit = xData_unit;
        %     CUT.y_unit = yData_unit;
        %     CUT.info = obj.info;
        % 
        % end
        
    end
end

