classdef OxArpes_1D_Data
    %OXARPES_1D_DATA Container for a one-dimensional ARPES spectrum.
    %   X stores the sampled coordinate and VALUE stores intensity at each
    %   point. INFO holds acquisition and instrument metadata.
    
    properties
        name;
        info;

        x_name;
        x_unit;
        v_name;
        v_unit;

        x;      % Coordinate values for the 1-D measurement.
        value;  % Signal intensity or counts corresponding to x.
    end
    
    methods
        function obj = OxArpes_1D_Data(varargin)
            %OXARPES_1D_DATA Construct an empty object or populate its fields.
            obj.name = '1D scan';
            if nargin == 0
                obj.x = [];
                obj.value = [];
            elseif nargin == 2
                obj.x = varargin{1}(:).';
                obj.value = varargin{2};
                obj.validate();
            elseif nargin == 1
                obj.x = varargin{1}.x(:).';
                obj.value = varargin{1}.value;
                obj.validate();
            else
                error('OxArpes:InvalidConstructor', ...
                    'Expected zero arguments, a data structure, or x, value.');
            end
        end

        function show(obj)
            %SHOW Plot the spectrum with its coordinate and value labels.
            h1 = figure('Name',obj.name);
            ha1 = axes('parent',h1);
            
            plot(ha1,obj.x,obj.value);
            xlabel(ha1,[obj.x_name ' (' obj.x_unit ')']);
            if ~isempty(obj.v_name)
                ylabel(ha1,[obj.v_name ' (' obj.v_unit ')']);
            end
            title(ha1,obj.name,'interpreter', 'none');
        end

        function validate(obj)
            %VALIDATE Check that coordinates, values, and metadata are usable.
            validateattributes(obj.x, {'numeric'}, {'vector','real','finite','nonempty'});
            validateattributes(obj.value, {'numeric','logical'}, {'vector','nonempty'});
            if numel(obj.x) ~= numel(obj.value)
                error('OxArpes:DimensionMismatch', ...
                    'value must contain one element for every x coordinate.');
            end
            if numel(obj.x) > 1
                delta = diff(obj.x);
                if any(delta == 0)
                    error('OxArpes:DuplicateAxis', ...
                        'x must not contain duplicate adjacent coordinates.');
                elseif ~(all(delta > 0) || all(delta < 0))
                    error('OxArpes:NonMonotonicAxis', ...
                        'x must be strictly increasing or strictly decreasing.');
                end
            end
        end

    end
end

