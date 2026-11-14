classdef OxA_RSImage < OxArpes_3D_Data
    %OXA_RSIMAGE Data object for real-space images across energy.
    %   X and Y are spatial coordinates and Z is kinetic energy. The class
    %   provides an energy-window integration that returns a 2-D image.
    
    properties
    end
    
    methods
        function obj = OxA_RSImage(varargin)
            %OXA_RSIMAGE Construct a real-space energy-stack data object.
            obj@OxArpes_3D_Data(varargin{:});

            obj.name = 'Real Space Image';
            obj.x_name = 'X position';
            obj.x_unit = 'µm';
            obj.y_name = 'Y position';
            obj.y_unit = 'µm';
            obj.z_name = 'Kinetic Energy';
            obj.z_unit = 'eV';

        end
        
        function IMAGE = integrate_energy(obj,emin,emax)
            %INTEGRATE_ENERGY Sum image intensity between energy limits.
            %   The nearest z samples to EMIN and EMAX define an inclusive
            %   interval. The result preserves spatial axes and metadata.
            obj.validate();
            validateattributes(emin, {'numeric'}, {'scalar','real','finite'});
            validateattributes(emax, {'numeric'}, {'scalar','real','finite'});

            [~,i0] = min(abs(obj.z-emin));
            [~,i1] = min(abs(obj.z-emax));
            idx = sort([i0 i1]);

            IMAGE = OxArpes_2D_Data(obj.x, obj.y, ...
                sum(obj.value(:,:,idx(1):idx(2)), 3));
            IMAGE.name = sprintf('%s energy-integrated', obj.name);
            IMAGE.x_name = obj.x_name;
            IMAGE.x_unit = obj.x_unit;
            IMAGE.y_name = obj.y_name;
            IMAGE.y_unit = obj.y_unit;
            IMAGE.info = obj.info;
            IMAGE.info.integration_range = [obj.z(idx(1)), obj.z(idx(2))];
        end
    end
end

