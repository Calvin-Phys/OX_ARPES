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

        function show(obj)

            UI = OxArpes_DataViewer(obj);

        end

        function obj = set_contrast(obj)
            n_data = sort(obj.value(:));
            upbound = n_data(round(0.995*length(n_data)));
            obj.value(obj.value>upbound) = upbound;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

