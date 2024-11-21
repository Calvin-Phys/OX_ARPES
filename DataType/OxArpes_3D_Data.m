classdef OxArpes_3D_Data
    %OXARPES_3D_DATA Summary of this class goes here
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

        x; % deflector angle - Theta X [deg]
        y; % angle - Theta Y [deg]
        z; % kinetic energy - Energy [eV]
        value; % data
    end
    
    methods
        % constructor
        function obj = OxArpes_3D_Data(varargin)
            if nargin == 4
                obj.x = varargin{1};
                obj.y = varargin{2};
                obj.z = varargin{3};
                obj.value = varargin{4};
            elseif nargin == 1
                obj.x = varargin{1}.x;
                obj.y = varargin{1}.y;
                obj.z = varargin{1}.z;
                obj.value = varargin{1}.value;
            end
        end

        % show / display
        function show(obj)

            UI = OxArpes_DataViewer(obj);

        end

        function VolumeViewer(obj)
            xx = (max(obj.x)-min(obj.x))/length(obj.x);
            yy = (max(obj.y)-min(obj.y))/length(obj.y);
            zz = (max(obj.z)-min(obj.z))/length(obj.z);

            rr = (max(obj.z)-min(obj.z)) / ((max(obj.x)-min(obj.x)+max(obj.y)-min(obj.y))/2);
            
            try
                volumeViewer(permute(obj.value, [2 1 3]), ScaleFactors=[xx yy zz/rr]);
            catch
            end
        end

        % basic operations
        function obj = set_contrast(obj)
            n_data = sort(obj.value(:));
            upbound = n_data(round(0.995*length(n_data)));
            obj.value(obj.value>upbound) = upbound;
        end
        
        function SDATA = Gaussian_smoothen(obj,sig_x,sig_y)

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

        function [D2x_DATA,D2y_DATA] = second_derivative(obj,sig_x,sig_y)
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

            NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
            NEW_DATA.y = NEW_DATA.y(nymin:nymax);
            NEW_DATA.z = NEW_DATA.z(nzmin:nzmax);
            NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax,nzmin:nzmax);

        end

        function NEW_DATA = truncate_idx(obj,nxmin,nxmax,nymin,nymax,nzmin,nzmax)
            NEW_DATA = obj;

            NEW_DATA.x = NEW_DATA.x(nxmin:nxmax);
            NEW_DATA.y = NEW_DATA.y(nymin:nymax);
            NEW_DATA.z = NEW_DATA.z(nzmin:nzmax);
            NEW_DATA.value = NEW_DATA.value(nxmin:nxmax,nymin:nymax,nzmin:nzmax);

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

            CUT = [];

            switch direction
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
                    sliceData = squeeze(mean(obj.value(cond,:,:),1));
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
                    sliceData = squeeze(mean(obj.value(:,cond,:),2));
                otherwise
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
                    sliceData = squeeze(mean(obj.value(:,:,cond),3));
            end

            CUT = OxA_CUT(xData,yData,sliceData);
            CUT.x_name = xData_name;
            CUT.y_name = yData_name;
            CUT.x_unit = xData_unit;
            CUT.y_unit = yData_unit;
            CUT.info = obj.info;

        end
        
    end
end

