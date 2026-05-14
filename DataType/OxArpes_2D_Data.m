classdef OxArpes_2D_Data
    %OXARPES_2D_DATA Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        name;
        info;

        x_name;
        x_unit;
        y_name;
        y_unit;

        x; % angle
        y; % kinetic energy
        value; % data
    end
    
    methods
        % constructor
        function obj = OxArpes_2D_Data(varargin)
            %OXARPES_2D_DATA Construct an instance of this class
            %   Detailed explanation goes here
            if nargin == 3
                obj.x = varargin{1};
                obj.y = varargin{2};
                obj.value = varargin{3};
            elseif nargin == 1
                obj.x = varargin{1}.x;
                obj.y = varargin{1}.y;
                obj.value = varargin{1}.value;
            end

        end

        % show / display
        function ha1 = show(obj)
            h1 = figure('Name',obj.name);
            ha1 = axes('parent',h1);
            
            % imagesc meshc
            imagesc(ha1,obj.x,obj.y,obj.value');
            xlabel(ha1,[obj.x_name ' (' obj.x_unit ')']);
            ylabel(ha1,[obj.y_name ' (' obj.y_unit ')']);
            try 
                title(ha1,append(obj.name, ': ', num2str(round(obj.info.photon_energy,1)), 'eV ', obj.info.polarization),'interpreter', 'none');
            catch
                try
                    title(ha1,append(obj.name, ': ', num2str(round(obj.info.photon_energy,1)), 'eV'),'interpreter', 'none');
                catch
                end
            end
            set(ha1,'YDir','normal');
            colormap(ha1,flipud(gray));

%             set(ha1,'TickDir','out');

            if strcmp(obj.x_unit,obj.y_unit)
                daspect([1 1 1]);
            end

            set(ha1,'linewidth',1.5);
            set(ha1,'fontsize',12);
            fontname(h1,"Arial");

        end

        function save_fig(obj,name)
            h1 = figure('Name',obj.name,'visible', 'off');
            ha1 = axes('parent',h1);
            
            % imagesc meshc
            imagesc(ha1,obj.x,obj.y,obj.value');
            xlabel(ha1,[obj.x_name ' (' obj.x_unit ')']);
            ylabel(ha1,[obj.y_name ' (' obj.y_unit ')']);
            title(ha1,obj.name,'interpreter', 'none');
            set(ha1,'YDir','normal');
            colormap(ha1,flipud(gray));

            if strcmp(obj.x_unit,obj.y_unit)
                pbaspect([1 1 1]);
            end

            saveas(h1,name);
            close(h1);
        end
        
        % basic operations
        function obj = set_contrast(obj)
            n_data = sort(obj.value(:));
            upbound = n_data(round(0.995*length(n_data)));

%             upbound = prctile(obj.value(:), 99.5);
            obj.value(obj.value > upbound) = upbound;
        end

        function NEW_DATA = remove_spikes(obj)
            NEW_DATA = obj;
            NEW_DATA.value = medfilt1(NEW_DATA.value,3,[],1);
            NEW_DATA.value = medfilt1(NEW_DATA.value,3,[],2);
        end

        function NEW_DATA = truncate(obj,xmin,xmax,ymin,ymax)
            NEW_DATA = obj;
            [~,nxmin] = min(abs(obj.x-xmin));
            [~,nxmax] = min(abs(obj.x-xmax));

            [~,nymin] = min(abs(obj.y-ymin));
            [~,nymax] = min(abs(obj.y-ymax));

            NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
            NEW_DATA.y = NEW_DATA.y(nymin:nymax);
            NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax);

        end

        function NEW_DATA = truncate_idx(obj,nxmin,nxmax,nymin,nymax)
            NEW_DATA = obj;

            NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
            NEW_DATA.y = NEW_DATA.y(nymin:nymax);
            NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax);

        end

        function NEW_DATA = block_reduce(obj, nx, ny)
        
            % 2D block averaging with independent block sizes:
            % nx : block size along x-direction (first dimension)
            % ny : block size along y-direction (second dimension)
        
            if nargin < 3
                error('block_reduce requires nx and ny.')
            end
        
            if nx <= 1 && ny <= 1
                NEW_DATA = obj;
                return
            end
        
            NEW_DATA = obj;
        
            % Original dimensions
            Nx = length(obj.x);
            Ny = length(obj.y);
        
            % Ensure divisibility
            Nx_new = floor(Nx / nx) * nx;
            Ny_new = floor(Ny / ny) * ny;
        
            % Truncate to divisible size
            x_trunc = obj.x(1:Nx_new);
            y_trunc = obj.y(1:Ny_new);
            V_trunc = obj.value(1:Nx_new, 1:Ny_new);
        
            % Reshape into blocks:
            % Dimensions: (nx, Nx_new/nx, ny, Ny_new/ny)
            V_block = reshape(V_trunc, nx, Nx_new/nx, ny, Ny_new/ny);
        
            % Average over block dimensions
            V_block = squeeze(mean(mean(V_block, 1), 3));
        
            % New x-axis (block averaged)
            x_block = reshape(x_trunc, nx, Nx_new/nx);
            x_block = mean(x_block, 1);
        
            % New y-axis (block averaged)
            y_block = reshape(y_trunc, ny, Ny_new/ny);
            y_block = mean(y_block, 1);
        
            % Assign to new object
            NEW_DATA.x = x_block;
            NEW_DATA.y = y_block;
            NEW_DATA.value = V_block;
        
        end

        function SCUT = Gaussian_smoothen(obj,sig_x,sig_y)
            % Gaussian_smoothen: Smoothens the ARPES data using a Gaussian filter.
            % Applies a Gaussian filter with specified standard deviations
            % sig_x and sig_y to smooth the data. Returns a new OxA_CUT object
            % with smoothed data.
            
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
            
            ma = obj.value;
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

            SCUT = obj;
            SCUT.value = map(1+w1:L+w1,1+w2:J+w2);
            SCUT.name = [obj.name ' smooth'];

        end


        function [D2x_CUT,D2y_CUT] = second_derivative(obj,sig_x,sig_y)
            % >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            % Gaussian Smooth 
            
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
            
            ma = obj.value;
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
            
            D2y = -Fuu;
            D2x = -Fvv;
    
            D2x_CUT = obj;
            D2x_CUT.name = [obj.name ' sd-x'];
            D2x_CUT.value = D2x(1+w1:L+w1,1+w2:J+w2);
            
            D2y_CUT = obj;
            D2y_CUT.name = [obj.name ' sd-y'];
            D2y_CUT.value = D2y(1+w1:L+w1,1+w2:J+w2);
        end

        function [D2x_CUT,D2y_CUT] = curvature(obj,sig_x,sig_y,C1,C2)
            % >>>>>>>>>>>>>>>>>>>>>>>>>>>>>
            % Curvature 
            % ref: Zhang, P. et al. A precise method for visualizing dispersive features in image plots. Rev. Sci. Instrum. 82, 043712 (2011).
            
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
            
            ma = obj.value;
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
            
            A1 = max(Fu.^2,[],"all");
            A2 = max(Fv.^2,[],"all");

            D2y = -Fuu./(C2*A1+Fu.^2).^(3/2);
            D2x = -Fvv./(C1*A2+Fv.^2).^(3/2);
    
%             D2y(D2y<0) = 0;
%             D2x(D2x<0) = 0;
            
            D2x_CUT = obj;
            D2x_CUT.name = [obj.name ' cv-x'];
            D2x_CUT.value = D2x(1+w1:L+w1,1+w2:J+w2);
            
            D2y_CUT = obj;
            D2y_CUT.name = [obj.name ' cv-y'];
            D2y_CUT.value = D2y(1+w1:L+w1,1+w2:J+w2);
        end

        function NCUT = self_normlaise(obj,dir)
            NCUT = obj;
            switch dir
                case 'x'
                    ss = mean(obj.value,2);
                    ss = ss./mean(ss,"all");
                    NCUT.value = NCUT.value./repmat(ss,1,size(NCUT.value,2));
                case 'y'
                    ss = mean(obj.value,1);
                    ss = ss./mean(ss,"all");
                    NCUT.value = NCUT.value./repmat(ss,size(NCUT.value,1),1);
            end
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

    end
end

