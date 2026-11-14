function DATA = load_scienta_IBW(file_path)
%LOAD_SCIENTA_IBW Read a Scienta/SES Igor Binary Wave file.
%   Parses the wave notes and axis scaling to create a supported OX data
%   object, then derives beamline metadata such as work function.

    buffer = IBWread(file_path);

    % notes, read the header
    notes = buffer.WaveNotes;

    trimmedNotes = strtrim(string(notes));
    isSesNotes = ~(startsWith(trimmedNotes,"{") || startsWith(trimmedNotes,"["));
    notes2 = [];
    notes3 = struct();
    if isSesNotes % SES key-value notes
        notes1 = regexp(notes,'[A-Z][\w-]*( [\w-]*)*=[\w-]*(\.\d*)*','match'); % need update
        notes2 = squeeze(split(notes1,'='));
        bmln = ses_note_value(notes2,'Location');
        exp_date = datetime(ses_note_value(notes2,'Date'));
        pe = str2double(ses_note_value(notes2,'Pass Energy'));
        hv = str2double(ses_note_value(notes2,'Excitation Energy'));
    else % PEAK JSON notes
        notes3 = jsondecode(notes);
        bmln = notes3.Location;
        exp_date = datetime(notes3.Date);
        pe = notes3.PassEnergy;
        hv = notes3.ExcitationSource.ExcitationSourceEnergyInformation.Energy;


    end

    
    % check data dimension
    switch buffer.Ndim
        case 2
            DataSize = size(buffer.y);
            XSize = DataSize(2);
            YSize = DataSize(1);
            data.value = buffer.y';
            data.x = buffer.x0(2)+((1:XSize)-1)*buffer.dx(2);
            data.y = buffer.x0(1)+((1:YSize)-1)*buffer.dx(1);

            % remove spikes
            data.value = medfilt1(data.value,2,[],1);
            data.value = medfilt1(data.value,2,[],2);

            DATA = OxA_CUT(data);
        case 3
            DataSize = size(buffer.y);
            XSize = DataSize(3);
            YSize = DataSize(2);
            ZSize = DataSize(1);
            data.value = permute(buffer.y, [3 2 1]);
            data.x = buffer.x0(3)+((1:XSize)-1)*buffer.dx(3);
            data.y = buffer.x0(2)+((1:YSize)-1)*buffer.dx(2);
            data.z = buffer.x0(1)+((1:ZSize)-1)*buffer.dx(1);

            % remove spikes
            data.value = medfilt1(data.value,2,[],2);
            data.value = medfilt1(data.value,2,[],3);

            if isSesNotes
                isKzScan = any(contains(string(notes2(:,2)), 'CIS', 'IgnoreCase', true));
            else
                isKzScan = contains(jsonencode(notes3), 'CIS', 'IgnoreCase', true);
            end

            if isKzScan % KZ
                
                % convert binding energy to E-E_F
                data.z = -data.z;

                nz = length(data.z);
                P = polyfit(1:nz,data.z,1);
                dz = abs(P(1));
                if ~isfinite(dz) || dz <= 0
                    error('OxArpes:InvalidIBWEnergyAxis', ...
                        'The IBW energy axis does not define a positive sampling interval.');
                end

                % interpolate (workfunction)

                Emin = min(min(data.z,[],'all') + get_beamline_workfunction(bmln,exp_date,data.x,pe),[],'all'); 
                Emax = max(max(data.z,[],'all') + get_beamline_workfunction(bmln,exp_date,data.x,pe),[],'all'); 
                EEF_new = Emin:dz:Emax;
                [EEFF, YY] = meshgrid(EEF_new,data.y);
        
                VALUE_NEW = zeros(length(data.x),length(data.y),length(EEF_new));
                for i = 1:length(data.x)
                    wf = get_beamline_workfunction(bmln,exp_date,data.x(i),pe);
                    energyAxis = data.z + wf;
                    angleAxis = data.y;
                    CUT = reshape(data.value(i,:,:),numel(angleAxis),numel(energyAxis));
                    if energyAxis(1) > energyAxis(end)
                        energyAxis = fliplr(energyAxis);
                        CUT = flip(CUT,2);
                    end
                    if angleAxis(1) > angleAxis(end)
                        angleAxis = fliplr(angleAxis);
                        CUT = flip(CUT,1);
                    end
                    VALUE_NEW(i,:,:) = interp2(energyAxis,angleAxis,CUT, ...
                        EEFF,YY,'spline',0);
                end
                data.value = VALUE_NEW;
                data.z = EEF_new;
                DATA = OxA_KZ(data);
            else % map
                DATA = OxA_MAP(data);
            end
        case 4
            error('OxArpes:UnsupportedIBWDimension', ...
                'Four-dimensional IBW data are not yet supported.');

        otherwise
            error('OxArpes:UnsupportedIBWDimension', ...
                'Unsupported IBW dimensionality: %d.', buffer.Ndim);

    end


    if isSesNotes
        DATA.info.pass_energy = str2double(ses_note_value(notes2,'Pass Energy'));
        DATA.info.lens_mode = ses_note_value(notes2,'Lens Mode');
        DATA.info.photon_energy = str2double(ses_note_value(notes2,'Excitation Energy'));
        DATA.info.acquisition_mode = ses_note_value(notes2,'Acquisition Mode');
        DATA.info.beamline = ses_note_value(notes2,'Location');
    
        DATA.info.workfunction = get_beamline_workfunction(bmln,exp_date,hv,pe);
    
        DATA.info.experiment_date = ses_note_value(notes2,'Date');
    
        DATA.info.header = notes2;
    else
        DATA.info.pass_energy = notes3.PassEnergy;
        DATA.info.len_mode = notes3.LensMode;
        DATA.info.photon_energy = notes3.ExcitationSource.ExcitationSourceEnergyInformation.Energy;
        DATA.info.acquisition_mode = notes3.AcquisitionMode;
        DATA.info.beamline = notes3.Location;
        DATA.info.experiment_date = notes3.Date;
        DATA.info.header = notes3;
        DATA.info.workfunction = get_beamline_workfunction(bmln,exp_date,hv,pe);
    end




    % remove spikes
%     if strcmp(DATA.info.acquisition_mode,'Fixed')
%         switch Ndim
%             case 2
%                 DATA.value = filloutliers(DATA.value,'linear','mean',2);
%             case 3
%                 DATA.value = filloutliers(DATA.value,'linear','mean',3);
%         end
%     end





end

function value = ses_note_value(notes,key)
    if isempty(notes) || size(notes,2) < 2
        error('OxArpes:InvalidIBWNotes', 'SES IBW notes are not valid key-value metadata.');
    end
    index = find(strcmpi(strtrim(string(notes(:,1))),key),1);
    if isempty(index)
        error('OxArpes:MissingIBWMetadata', 'SES IBW notes do not contain "%s".', key);
    end
    value = char(string(notes{index,2}));
end
