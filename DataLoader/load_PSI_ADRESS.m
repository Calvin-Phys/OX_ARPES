function DATA = load_PSI_ADRESS(file_path)
%LOAD_PSI_ADRESS Read PSI ADRESS Igor HDF5 cuts and tilt maps.
%   DATA = LOAD_PSI_ADRESS(FILE_PATH) reads the /Matrix dataset and its
%   IGORWaveScaling/IGORWaveNote attributes. Two-dimensional data are
%   returned as OxA_CUT(angle, kinetic energy, counts). Three-dimensional
%   polar maps are returned as OxA_MAP(polar, angle, kinetic energy, counts).
%   ADRESS files store binding energy in the examples inspected here; that
%   axis is shifted by photon_energy - workfunction to match OX_ARPES's
%   kinetic-energy coordinate convention. The work function defaults to
%   4.5 eV, matching OxA_CUT, because these files do not store it.
%   Wave-note Theta/Azimuth are retained as metadata; calibrated OX angular
%   offset fields remain at their data-class defaults.

    if ~(ischar(file_path) || (isstring(file_path) && isscalar(file_path)))
        error('OxArpes:InvalidPathInput', ...
            'The ADRESS file path must be a character vector or scalar string.');
    end
    file_path = char(file_path);
    if ~isfile(file_path)
        error('OxArpes:FileNotFound', 'File not found: %s', file_path);
    end
    [~,~,extension] = fileparts(file_path);
    if ~strcmpi(extension, '.h5')
        error('OxArpes:InvalidPSIADRESSExtension', ...
            'PSI ADRESS files must use the .h5 extension.');
    end

    matrixInfo = h5info(file_path, '/Matrix');
    attributeNames = {matrixInfo.Attributes.Name};
    requiredAttributes = {'IGORWaveScaling','IGORWaveNote','IGORWaveUnits'};
    for iAttribute = 1:numel(requiredAttributes)
        if ~ismember(requiredAttributes{iAttribute}, attributeNames)
            error('OxArpes:InvalidPSIADRESSSchema', ...
                'The /Matrix dataset is missing required attribute %s.', ...
                requiredAttributes{iAttribute});
        end
    end

    % Igor scale columns 2:end describe [angle, energy, scan]. MATLAB's
    % h5read reverses that dimension order, returning [energy, angle] for
    % cuts and [scan, energy, angle] for maps. Reorder counts with the axes
    % below; units describe the Igor dimensions, not the h5read dimensions.
    value = double(h5read(file_path, '/Matrix'));
    scaling = double(h5readatt(file_path, '/Matrix', 'IGORWaveScaling'));
    note = h5readatt(file_path, '/Matrix', 'IGORWaveNote');
    units = string(h5readatt(file_path, '/Matrix', 'IGORWaveUnits'));
    units = units(:).';

    if size(scaling,1) ~= 2 || size(scaling,2) < 3
        error('OxArpes:InvalidPSIADRESScaling', ...
            'IGORWaveScaling must contain an origin and step for each data axis.');
    end
    nAxes = size(scaling,2) - 1;
    if nAxes ~= 2 && nAxes ~= 3
        error('OxArpes:UnsupportedPSIADRESSDimension', ...
            'PSI ADRESS supports two-dimensional cuts and three-dimensional tilt maps; received %d axes.', ...
            nAxes);
    end
    if numel(units) < nAxes + 1
        error('OxArpes:InvalidPSIADRESSUnits', ...
            'IGORWaveUnits does not describe every data axis.');
    end

    photonEnergy = note_scalar(note, 'hv');
    if ~isfinite(photonEnergy)
        error('OxArpes:MissingPSIADRESSPhotonEnergy', ...
            'The IGORWaveNote must contain a scalar hv value.');
    end
    energyMode = lower(strtrim(note_value(note, 'Ek/Eb')));
    if isempty(energyMode)
        error('OxArpes:MissingPSIADRESSEnergyMode', ...
            'The IGORWaveNote must identify the energy axis as Ek or Eb.');
    end

    workfunction = 4.5;
    if strcmp(energyMode, 'eb')
        energyOffset = photonEnergy - workfunction;
        energyName = 'Kinetic Energy';
    elseif strcmp(energyMode, 'ek')
        energyOffset = 0;
        energyName = 'Kinetic Energy';
    else
        error('OxArpes:UnsupportedPSIADRESSEnergyMode', ...
            'Unsupported ADRESS energy mode "%s"; expected Eb or Ek.', energyMode);
    end

    angleUnit = normalise_unit(units(2));
    energyUnit = normalise_unit(units(3));
    if ~strcmp(angleUnit, 'degree') || ~strcmp(energyUnit, 'ev')
        error('OxArpes:UnsupportedPSIADRESSUnits', ...
            'Expected angle in degrees and energy in eV; found "%s" and "%s".', ...
            units(2), units(3));
    end

    if nAxes == 2
        % Raw rows are energy channels; raw columns are angle channels.
        % Construct coordinates from those raw counts before transposing
        % into the OX convention value(angleIndex, energyIndex).
        angleCount = size(value, 2);
        energyCount = size(value, 1);
        angleAxis = make_axis(scaling, 2, angleCount);
        energyAxis = make_axis(scaling, 3, energyCount) + energyOffset;
        value = value.';
        DATA = OxA_CUT(angleAxis, energyAxis, value);
        DATA.y_name = energyName;
    else
        % [scan, energy, angle] -> OX [scan, angle, energy]. This is the
        % combined permutation in ReaderHDF5 -> ReadARPES -> load_ADRESS.
        value = permute(value, [1 3 2]);
        scanCount = size(value, 1);
        angleCount = size(value, 2);
        angleAxis = make_axis(scaling, 2, angleCount);
        energyAxis = make_axis(scaling, 3, size(value, 3)) + energyOffset;
        scanAxis = make_axis(scaling, 4, scanCount);
        scanUnit = normalise_unit(units(4));
        if ~strcmp(scanUnit, 'degree')
            error('OxArpes:UnsupportedPSIADRESSScan', ...
                'Three-dimensional ADRESS data must have a degree-valued scan axis and an energy axis.');
        end
        DATA = OxA_MAP(scanAxis, angleAxis, energyAxis, value);
        DATA.x_name = 'Polar';
        DATA.y_name = 'Angle';
        DATA.z_name = energyName;
    end

    DATA.info.beamline = 'PSI ADRESS';
    DATA.info.source_file = file_path;
    DATA.info.photon_energy = photonEnergy;
    DATA.info.workfunction = workfunction;
    DATA.info.workfunction_source = 'OX_ARPES default (4.5 eV); verify for quantitative conversion.';
    DATA.info.energy_mode = upper(energyMode);
    DATA.info.raw_wave_note = char(note);
    DATA.info.polarization = note_value(note, 'Pol');
    DATA.info.pass_energy = note_scalar(note, 'Epass');
    DATA.info.exit_slit = note_scalar(note, 'Slit');
    DATA.info.acquisition_mode = note_value(note, 'Mode');
    DATA.info.exposure_time = note_scalar(note, 'dt');
    DATA.info.temperature = note_scalar(note, 'Temp');
    DATA.info.theta = note_scalar(note, 'Theta');
    DATA.info.tilt = note_value(note, 'Tilt');
    DATA.info.azimuth = note_scalar(note, 'Azimuth');
    DATA.info.grating = note_scalar(note, 'Grating');
    DATA.info.correction = note_value(note, 'Corr');
    DATA.validate();
end

function axis = make_axis(scaling, scaleColumn, axisLength)
%MAKE_AXIS Reconstruct one Igor wave axis from its origin and step.
    if scaleColumn > size(scaling,2)
        error('OxArpes:InvalidPSIADRESSScaling', ...
            'IGORWaveScaling is missing axis column %d.', scaleColumn);
    end
    step = scaling(1, scaleColumn);
    origin = scaling(2, scaleColumn);
    if ~isfinite(step) || ~isfinite(origin)
        error('OxArpes:InvalidPSIADRESSScaling', ...
            'IGORWaveScaling contains a nonfinite origin or step.');
    end
    axis = origin + (0:axisLength-1) .* step;
end

function unit = normalise_unit(unitValue)
%NORMALISE_UNIT Canonicalize common Igor axis unit labels.
    unit = lower(strtrim(char(unitValue)));
    if ismember(unit, {'deg','degrees'})
        unit = 'degree';
    elseif ismember(unit, {'ev','electronvolt','electronvolts'})
        unit = 'ev';
    end
end

function value = note_value(note, key)
%NOTE_VALUE Return a case-insensitive key's text from IGORWaveNote.
    value = '';
    lines = regexp(char(note), '\r\n|\n|\r', 'split');
    for iLine = 1:numel(lines)
        tokens = regexp(lines{iLine}, '^\s*([^=]+?)\s*=\s*(.*?)\s*$', ...
            'tokens', 'once');
        if ~isempty(tokens) && strcmpi(strtrim(tokens{1}), key)
            value = strtrim(tokens{2});
            return
        end
    end
end

function value = note_scalar(note, key)
%NOTE_SCALAR Read the first numeric value from an IGORWaveNote field.
    textValue = note_value(note, key);
    numbers = regexp(textValue, ...
        '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', 'match', 'once');
    if isempty(numbers)
        value = NaN;
    else
        value = str2double(numbers);
    end
end
