function DATA = load_scienta_IBW(file_path)
%load_Bessy_IBW Summary of this function goes here
%   Detailed explanation goes here

    buffer = IBWread(file_path);

    % notes, read the header
    notes = buffer.WaveNotes;

    try %ses
        notes1 = regexp(notes,'[A-Z][\w-]*( [\w-]*)*=[\w-]*(\.\d*)*','match'); % need update
        notes2 = squeeze(split(notes1,'='));
    
        % info for workfunction
        Index = contains(notes2(:,1),'Location');
        bmln = notes2{Index,2};
        Index = contains(notes2(:,1),'Date');
        exp_date = datetime(notes2{Index,2});
        Index = contains(notes2(:,1),'Pass Energy');
        pe = str2num(notes2{Index,2});
        Index = contains(notes2(:,1),'Excitation Energy');
        hv = str2num(notes2{Index,2});

    catch %peak
        notes3 = jsondecode(notes);
        blmn = notes3.Location;
        exp_date = notes3.Date;
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

            if any(contains(notes2(:,2),'CIS')) % KZ
                
                % convert binding energy to E-E_F
                data.z = -data.z;

                nz = length(data.z);
                P = polyfit(1:nz,data.z,1);
                dz = P(1);

                % interpolate (workfunction)

                Emin = min(min(data.z,[],'all') + get_beamline_workfunction(bmln,exp_date,data.x,pe),[],'all'); 
                Emax = max(max(data.z,[],'all') + get_beamline_workfunction(bmln,exp_date,data.x,pe),[],'all'); 
                EEF_new = Emin:dz:Emax;
                [EEFF, YY] = meshgrid(EEF_new,data.y);
        
                VALUE_NEW = zeros(length(data.x),length(data.y),length(EEF_new));
                for i = 1:length(data.x)
                    wf = get_beamline_workfunction(bmln,exp_date,data.x(i),pe);
                    CUT = squeeze(data.value(i,:,:));
                    VALUE_NEW(i,:,:) = interp2(data.z + wf,data.y,CUT,EEFF,YY,'spline',0);
                end
                data.value = VALUE_NEW;
                data.z = EEF_new;
                DATA = OxA_KZ(data);
            else % map
                DATA = OxA_MAP(data);
            end
    end


    try
        Index = contains(notes2(:,1),'Pass Energy');
        DATA.info.pass_energy = str2num(notes2{Index,2});
        Index = contains(notes2(:,1),'Lens Mode');
        DATA.info.len_mode = notes2{Index,2};
        Index = contains(notes2(:,1),'Excitation Energy');
        DATA.info.photon_energy = str2num(notes2{Index,2});
        Index = contains(notes2(:,1),'Acquisition Mode');
        DATA.info.acquisition_mode = notes2{Index,2};
        Index = contains(notes2(:,1),'Location');
        DATA.info.beamline = notes2{Index,2};
    
        DATA.info.workfunction = get_beamline_workfunction(bmln,exp_date,hv,pe);
    
        Index = contains(notes2(:,1),'Date');
        DATA.info.experiment_date = notes2{Index,2};
    
        DATA.info.header = notes2;
    catch
        DATA.info.pass_energy = notes3.PassEnergy;
        DATA.info.len_mode = notes3.LensMode;
        DATA.info.photon_energy = notes3.ExcitationSource.ExcitationSourceEnergyInformation.Energy;
        DATA.info.acquisition_mode = notes3.AcquisitionMode;
        DATA.info.beamline = notes3.Location;
        DATA.info.experiment_date = notes3.Date;
        DATA.info.header = notes3;
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