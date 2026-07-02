classdef OxArpes_4D_Data
    %OXARPES_4D_DATA Summary of this class goes here
    %   Detailed explanation goes here
    
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
        value; % data
    end
    
    methods
        % constructor
        function obj = OxArpes_4D_Data(varargin)
            if nargin == 5
                obj.x = varargin{1};
                obj.y = varargin{2};
                obj.z = varargin{3};
                obj.k = varargin{4};
                obj.value = varargin{5};
            elseif nargin == 1
                obj.x = varargin{1}.x;
                obj.y = varargin{1}.y;
                obj.z = varargin{1}.z;
                obj.k = varargin{1}.k;
                obj.value = varargin{1}.value;
            end
        end

        % show / display
        function show(obj)

            UI = OxArpes_DataViewer_4D(obj);

        end


        % basic operations
        % function NEW_DATA = truncate(obj,xmin,xmax,ymin,ymax,zmin,zmax)
        %     NEW_DATA = obj;
        %     [~,nxmin] = min(abs(obj.x-xmin));
        %     [~,nxmax] = min(abs(obj.x-xmax));
        % 
        %     [~,nymin] = min(abs(obj.y-ymin));
        %     [~,nymax] = min(abs(obj.y-ymax));
        % 
        %     [~,nzmin] = min(abs(obj.z-zmin));
        %     [~,nzmax] = min(abs(obj.z-zmax));
        % 
        %     NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
        %     NEW_DATA.y = NEW_DATA.y(nymin:nymax);
        %     NEW_DATA.z = NEW_DATA.z(nzmin:nzmax);
        %     NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax,nzmin:nzmax);
        % 
        % end
        % 
        % function NEW_DATA = truncate_idx(obj,nxmin,nxmax,nymin,nymax,nzmin,nzmax)
        %     NEW_DATA = obj;
        % 
        %     NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
        %     NEW_DATA.y = NEW_DATA.y(nymin:nymax);
        %     NEW_DATA.z = NEW_DATA.z(nzmin:nzmax);
        %     NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax,nzmin:nzmax);
        % 
        % end
        % 
        function NEW_DATA = block_reduce(obj, nx, ny, nz, nk)
        %BLOCK_REDUCE 4D block averaging with independent block sizes.
        %
        % nx : block size along x (1st dimension)
        % ny : block size along y (2nd dimension)
        % nz : block size along z (3rd dimension)
        % nk : block size along k (4th dimension)
        
            if nargin < 5
                error('block_reduce requires nx, ny, nz, nk.')
            end
        
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
            % (nx, Nx_new/nx, ny, Ny_new/ny, nz, Nz_new/nz, nk, Nk_new/nk)
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
            V_block = squeeze(V_block);
        
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

