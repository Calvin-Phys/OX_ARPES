function [outputs, details] = ox_data_process(data, action, options)
%OX_DATA_PROCESS Validated, side-effect-free Data Process operations.
%   [OUTPUTS, DETAILS] = OX_DATA_PROCESS(DATA, ACTION, OPTIONS) returns a
%   cell array of copied OX 2-D/3-D value objects. No workspace or figures
%   are changed. OPTIONS is a scalar struct; unknown fields are errors.
%
%   Actions / options (omitted fields use these defaults):
%     truncate: Bounds = {'Min','Max';'Min','Max';'Min','Max'},
%               Scale = 'coordinates' (or 'indices'). Z ignored for 2-D.
%     smooth, derivative: Sigma = [3 3], in samples. 2-D X/Y; 3-D Y/Z.
%     zsmooth: SigmaZ = 5 samples; 3-D only.
%     normalise: Direction = 'X' (X,Y,Z,XY,XZ,YZ), Peak = false,
%                Bounds = {'Min','Max'}, Scale = 'coordinates'.
%                Plane directions ignore Bounds/Scale deliberately.
%     median: Window = 5 samples (positive integer), Axis = 1 for 2-D,
%             2 for 3-D. Any actual array dimension may be selected.
%     reduce: Factors = [1 1 1] samples per X/Y/Z block (2-D ignores Z).
%             Uses block_reduce: averages pixels/coordinates and drops tails.
%
%   Coordinate bounds snap to nearest samples, clamp outside the axis, and
%   sort the resulting index pair (descending axes are supported). Min/Max
%   mean coordinate extrema in coordinate mode, first/last in index mode.
%   Normalisation divides full profiles by the selected mean/maximum;
%   nonfinite or zero divisors are errors. Filter conventions and derivative
%   sign are inherited from the data classes (negative second differences
%   in sample units). DETAILS records effective options, axes and suffixes.

    if nargin < 3
        options = struct();
    end
    if ~isscalar(data) || ~(isa(data,'OxArpes_2D_Data') || isa(data,'OxArpes_3D_Data'))
        error('OxArpes:ProcessData','Select one OX 2-D or 3-D data object.');
    end
    data.validate();
    validateattributes(data.value, {'numeric','logical'}, {'real','finite','nonempty'});
    dimension = 2 + isa(data,'OxArpes_3D_Data'); % class, not ndims: Z may be singleton
    axesValues = {data.x, data.y};
    axisNames = 'XY';
    if dimension == 3
        axesValues{3} = data.z;
        axisNames = 'XYZ';
    end
    action = validatestring(action, {'truncate','smooth','derivative','zsmooth','normalise','median','reduce'});
    details = struct('Action',action,'Dimensions',dimension,'Options',struct(), ...
        'Axes','','Suffixes',{{}},'Indices',{{}});
    switch action
        case 'reduce'
            opts = mergeOptions(struct('Factors',[1 1 1]),options);
            if ~isnumeric(opts.Factors) || ~isvector(opts.Factors) || ...
                    numel(opts.Factors) < dimension || numel(opts.Factors) > 3
                error('OxArpes:ProcessFactors','Supply one block factor for each active X/Y/Z axis.');
            end
            factors = opts.Factors(1:dimension);
            sampleCounts = cellfun(@numel,axesValues);
            if ~isreal(factors) || any(~isfinite(factors)) || any(factors < 1) || ...
                    any(factors ~= fix(factors)) || any(factors(:).' > sampleCounts)
                error('OxArpes:ProcessFactors', ...
                    'Block factors must be positive integers no larger than their axis sample counts.');
            end
            opts.Factors = double(factors(:).');
            args = num2cell(opts.Factors);
            result = data.block_reduce(args{:});
            result.validate();
            outputs = {result};
            details.Axes = axisNames;
            details.Suffixes = {'_rd'};
            details.DroppedSamples = mod(sampleCounts,opts.Factors);
        case 'truncate'
            defaults = struct('Bounds',{{'Min','Max';'Min','Max';'Min','Max'}},'Scale','coordinates');
            opts = mergeOptions(defaults,options);
            if ~iscell(opts.Bounds) || size(opts.Bounds,2) ~= 2 || ...
                    size(opts.Bounds,1) < dimension || size(opts.Bounds,1) > 3
                error('OxArpes:ProcessBounds','Bounds must have one cell row [from,to] per active axis.');
            end
            indexPairs = cell(1,dimension);
            for iAxis = 1:dimension
                indexPairs{iAxis} = parseRange(opts.Bounds(iAxis,:),opts.Scale,axesValues{iAxis});
            end
            args = num2cell([indexPairs{:}]);
            outputs = {data.truncate_idx(args{:})};
            details.Indices = indexPairs;
            details.Axes = axisNames;
            details.Suffixes = {'_tk'};
        case {'smooth','derivative'}
            opts = mergeOptions(struct('Sigma',[3 3]),options);
            validateattributes(opts.Sigma, {'numeric'}, {'real','finite','positive','vector','numel',2});
            opts.Sigma = double(opts.Sigma(:).');
            filterDims = (dimension-1):dimension;
            if any(cellfun(@numel,axesValues(filterDims)) < 2)
                error('OxArpes:ProcessDimension','Plane filters require at least two samples on each filtered axis.');
            end
            % The legacy reflected padding requires radius <= each axis.
            radii = ceil(3.5*double(opts.Sigma));
            if any(radii > cellfun(@numel,axesValues(filterDims)))
                error('OxArpes:ProcessSigma', ...
                    'Each sigma must satisfy ceil(3.5*sigma) <= its axis sample count.');
            end
            if prod(2*radii+1) > 2e6
                error('OxArpes:ProcessSigma','Gaussian kernel exceeds two million elements. Reduce sigma.');
            end
            if strcmp(action,'smooth')
                if dimension == 2
                    result = data.Gaussian_smoothen(opts.Sigma(1),opts.Sigma(2));
                else
                    result = data.Gaussian_smoothen_YZ(opts.Sigma(1),opts.Sigma(2));
                end
                outputs = {result};
                details.Suffixes = {'_sm'};
            else
                [first,second] = data.second_derivative(opts.Sigma(1),opts.Sigma(2));
                outputs = {first,second};
                details.Suffixes = {'_d2x','_d2y'}; % legacy names, Y/Z in 3-D
            end
            details.Axes = axisNames(filterDims);
        case 'zsmooth'
            opts = mergeOptions(struct('SigmaZ',5),options);
            if dimension ~= 3
                error('OxArpes:ProcessDimension','Z smoothing requires 3-D data.');
            end
            validateattributes(opts.SigmaZ, {'numeric'}, {'scalar','real','finite','positive'});
            if 2*ceil(3.5*opts.SigmaZ)+1 > 2e6
                error('OxArpes:ProcessSigma','Z kernel exceeds two million elements. Reduce sigma.');
            end
            outputs = {data.Z_Gaussian_smoothen(opts.SigmaZ)};
            details.Axes = 'Z';
            details.Suffixes = {'_zsm'};
        case 'normalise'
            opts = mergeOptions(struct('Direction','X','Peak',false, ...
                'Bounds',{{'Min','Max'}},'Scale','coordinates'),options);
            direction = validatestring(opts.Direction,{'X','Y','Z','XY','XZ','YZ'});
            if dimension == 2 && (numel(direction) > 1 || strcmp(direction,'Z'))
                error('OxArpes:ProcessDimension','2-D normalisation supports X or Y.');
            end
            validateattributes(opts.Peak, {'logical','numeric'}, {'scalar','real','finite','binary'});
            reduceDims = find(ismember(axisNames,direction));
            subset = repmat({':'},1,dimension);
            if isscalar(reduceDims)
                pair = parseRange(opts.Bounds,opts.Scale,axesValues{reduceDims});
                subset{reduceDims} = pair(1):pair(2);
                details.Indices = {pair};
            end
            reference = double(data.value(subset{:}));
            for iDim = reduceDims
                if opts.Peak
                    reference = max(reference,[],iDim);
                else
                    reference = mean(reference,iDim);
                end
            end
            if any(~isfinite(reference(:)) | reference(:) == 0)
                error('OxArpes:ProcessDivisor', ...
                    'Selected region has a zero or nonfinite normalisation divisor. Choose another region.');
            end
            result = data;
            result.value = double(data.value) ./ reference;
            if any(~isfinite(result.value(:)))
                error('OxArpes:ProcessDivisor','Normalisation overflows. Choose another region.');
            end
            outputs = {result};
            opts.Direction = direction;
            details.Axes = direction;
            details.Suffixes = {['_' direction '_snor']};
        case 'median'
            opts = mergeOptions(struct('Window',5,'Axis',dimension-1),options);
            validateattributes(opts.Axis, {'numeric'}, {'scalar','integer','>=',1,'<=',dimension});
            validateattributes(opts.Window, {'numeric'}, ...
                {'scalar','real','finite','integer','positive','<=',numel(axesValues{opts.Axis})});
            if isempty(which('medfilt1'))
                error('OxArpes:ProcessDependency','Median filtering requires Signal Processing Toolbox (medfilt1).');
            end
            result = data;
            result.value = medfilt1(double(data.value),opts.Window,[],opts.Axis);
            outputs = {result};
            details.Axes = axisNames(opts.Axis);
            details.Suffixes = {'_rmspk'};
    end
    details.Options = opts;
end

function options = mergeOptions(defaults, supplied)
    if ~isstruct(supplied) || ~isscalar(supplied)
        error('OxArpes:ProcessOptions','Options must be a scalar struct.');
    end
    fields = fieldnames(supplied);
    unknown = setdiff(fields,fieldnames(defaults));
    if ~isempty(unknown)
        error('OxArpes:ProcessOptions','Unknown option: %s.',unknown{1});
    end
    options = defaults;
    for iField = 1:numel(fields)
        options.(fields{iField}) = supplied.(fields{iField});
    end
end

function pair = parseRange(bounds, scale, coordinates)
    if ~iscell(bounds) || numel(bounds) ~= 2
        error('OxArpes:ProcessBounds','Each range must be a two-element cell array.');
    end
    scale = validatestring(scale,{'coordinates','indices'});
    numericBounds = zeros(1,2);
    for iBound = 1:2
        value = bounds{iBound};
        if ischar(value) || (isstring(value) && isscalar(value))
            token = strtrim(char(value));
            if strcmpi(token,'Min')
                if strcmp(scale,'indices'), value = 1; else, value = min(coordinates); end
            elseif strcmpi(token,'Max')
                if strcmp(scale,'indices'), value = numel(coordinates); else, value = max(coordinates); end
            else
                value = str2double(token); % never evaluate expressions
            end
        end
        if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
            error('OxArpes:ProcessBounds','Bounds must be finite real scalars, Min, or Max.');
        end
        if strcmp(scale,'indices')
            if value ~= fix(value) || value < 1 || value > numel(coordinates)
                error('OxArpes:ProcessBounds','Indices must be integers from 1 to %d.',numel(coordinates));
            end
            numericBounds(iBound) = value;
        else
            [~,numericBounds(iBound)] = min(abs(coordinates-value));
        end
    end
    pair = sort(numericBounds);
end
