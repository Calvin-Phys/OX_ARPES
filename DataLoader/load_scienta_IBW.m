function DATA = load_scienta_IBW(file_path)
%load_Bessy_IBW Summary of this function goes here
%   Detailed explanation goes here

    buffer = IBWread(file_path);

    % notes, read the header
    notes = buffer.WaveNotes;
    notes1 = regexp(notes,'[A-Z][\w-]*( [\w-]*)*=[\w-]*(\.\d*)*','match');
    notes2 = squeeze(split(notes1,'='));


    % check data dimension
    switch buffer.Ndim
        case 2
            DataSize = size(buffer.y);
            XSize = DataSize(2);
            YSize = DataSize(1);
            data.value = buffer.y';
            data.x = buffer.x0(2)+((1:XSize)-1)*buffer.dx(2);
            data.y = buffer.x0(1)+((1:YSize)-1)*buffer.dx(1);
%             data.value = filloutliers(data.value,'center','mean',1);
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
%             data.value = filloutliers(data.value,'linear','mean',2);

            if any(contains(notes2(:,2),'CIS')) % KZ
                
                % convert binding energy to E-E_F
                data.z = -data.z;

                nz = length(data.z);
                P = polyfit(1:nz,data.z,1);
                dz = P(1);

                % interpolate
                x = [25 50 60 110 160 170];
                y = [4.3907 4.4095 4.4133 4.4667 4.5164 4.5193];

                Emin = min(min(data.z,[],'all') + interp1(x,y,data.x,'spline','extrap'),[],'all'); 
                Emax = max(max(data.z,[],'all') + interp1(x,y,data.x,'spline','extrap'),[],'all'); 
                EEF_new = Emin:dz:Emax;
                [EEFF, YY] = meshgrid(EEF_new,data.y);
        
                VALUE_NEW = zeros(length(data.x),length(data.y),length(EEF_new));
                for i = 1:length(data.x)
                    wf = interp1(x,y,data.x(i),'spline','extrap');
                    CUT = squeeze(data.value(i,:,:));
                    VALUE_NEW(i,:,:) = interp2(data.z + wf,data.y,CUT,EEFF,YY,'spline',0);
                end
                data.value = VALUE_NEW;
                data.z = EEF_new;
                DATA = OxA_KZ(data);
            else
                DATA = OxA_MAP(data);
            end
    end



    Index = contains(notes2(:,1),'Pass Energy');
    DATA.info.pass_energy = str2num(notes2{Index,2});
    Index = contains(notes2(:,1),'Lens Mode');
    DATA.info.len_mode = notes2{Index,2};
    Index = contains(notes2(:,1),'Excitation Energy');
    DATA.info.photon_energy = str2num(notes2{Index,2});
    Index = contains(notes2(:,1),'Acquisition Mode');
    DATA.info.acquisition_mode = notes2{Index,2};
    Index = contains(notes2(:,1),'Location');
    bmln = notes2{Index,2};
    switch bmln
        case {'MAXIV','Bloch'}
            DATA.info.beamline = 'MAXIV_Bloch';
            x = [25 50 60 110 160 170];
            y = [4.3907 4.4095 4.4133 4.4667 4.5164 4.5193];
            DATA.info.workfunction = interp1(x,y,DATA.info.photon_energy,'spline','extrap'); 
        otherwise
            DATA.info.workfunction = 4.44; 
    end

    DATA.info.header = notes2;

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