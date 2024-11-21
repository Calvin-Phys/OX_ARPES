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
            set(ha1,'XMinorTick','on','YMinorTick','on');
            ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
            ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');

            if strcmp(obj.x_unit,obj.y_unit)
                daspect([1 1 1]);
            end

            set(ha1,'linewidth',1.5);
            set(ha1,'fontsize',12);
            fontname(h1,"Arial");

        end

        function ha1 = show_for_print(obj)

            set(groot,{'DefaultAxesXColor','DefaultAxesYColor','DefaultAxesZColor'},{'k','k','k'});

            h1 = figure('Name',obj.name,'Renderer', 'painters');
%             h1.Units = 'centimeters';
%             h1.Position = [3 3 15 15];
            ha1 = axes('parent',h1);
            % ha1.Units = 'centimeters';
            % ha1.Position = [2 2 3.5 3.2];

            set(ha1,'linewidth',1.5);
            fontname(ha1,"Arial");
            
            % imagesc meshc
            % hold on
            imagesc(ha1,obj.x,obj.y,obj.value');
            xlabel(ha1,[obj.x_name ' (' obj.x_unit ')']);
            ylabel(ha1,[obj.y_name ' (' obj.y_unit ')']);
%             title(ha1,append(obj.name, ': ', num2str(round(obj.info.photon_energy,1)), 'eV ', obj.info.polarization),'interpreter', 'none');
            set(ha1,'YDir','normal');

            load('oxa_colourmap.mat');
            colormap(ha1,flip(oxa_blue));
            clim(ha1,[0 0.7*max(obj.value,[],"all")]);

            set(ha1,'TickDir','out');
            box(ha1,'off');
            set(ha1,'XMinorTick','on','YMinorTick','on');
            ha1.XAxis.MinorTickValues = interp1(1:length(ha1.XTick),ha1.XTick,0.5:0.5:(length(ha1.XTick)+0.5),'linear','extrap');
            ha1.YAxis.MinorTickValues = interp1(1:length(ha1.YTick),ha1.YTick,0.5:0.5:(length(ha1.YTick)+0.5),'linear','extrap');
            % axis tight

            % This syntax just sets the axis limits to their current value
            xlim(ha1, xlim(ha1));
            ylim(ha1, ylim(ha1));
            
            % Set right and upper axis lines to same color as axes
            xline(max(xlim(ha1)), 'k-', 'Color', ha1.XAxis.Color);
            yline(max(ylim(ha1)), 'k-', 'Color', ha1.YAxis.Color);

            if strcmp(obj.x_unit,obj.y_unit)
                pbaspect([1 1 1]);
            end
            set(ha1,'fontsize',10);
            % set(findall(gcf,'-property','FontSize'),'FontSize',6);


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
            
            A1 = max(Fu.^2,[],"all");
            A2 = max(Fv.^2,[],"all");

            D2y = -Fuu./(C1*A1+Fu.^2).^(3/2);
            D2x = -Fvv./(C2*A2+Fv.^2).^(3/2);
    
            D2y(D2y<0) = 0;
            D2x(D2x<0) = 0;
            
            D2x_CUT = obj;
            D2x_CUT.name = [obj.name ' sd-x'];
            D2x_CUT.value = D2x(1+w1:L+w1,1+w2:J+w2);
            
            D2y_CUT = obj;
            D2y_CUT.name = [obj.name ' sd-y'];
            D2y_CUT.value = D2y(1+w1:L+w1,1+w2:J+w2);
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

