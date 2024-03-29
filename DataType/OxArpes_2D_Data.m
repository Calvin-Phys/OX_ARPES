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

        function ha1 = show(obj)
            h1 = figure('Name',obj.name);
            ha1 = axes('parent',h1);
            
            % imagesc meshc
            imagesc(ha1,obj.x,obj.y,obj.value');
            xlabel(ha1,[obj.x_name ' (' obj.x_unit ')']);
            ylabel(ha1,[obj.y_name ' (' obj.y_unit ')']);
            title(ha1,append(obj.name, ': ', num2str(round(obj.info.photon_energy,1)), 'eV ', obj.info.polarization),'interpreter', 'none');
            set(ha1,'YDir','normal');
            colormap(ha1,flipud(gray));

            if strcmp(obj.x_unit,obj.y_unit)
                pbaspect([1 1 1]);
            end
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

        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

