function DATA = load_Soleil_Cassiopee_folder(file)
    % load FS map at Soleil Cassiopee beamline
    
    [filepath,name,ext] = fileparts(file);

    allFiles = dir( filepath );
    allNames = { allFiles.name };

    % remove . and ..
    name_list0 = allNames(3:end);

    name_list1 = {};
    for i=1:length(name_list0)
        if endsWith(name_list0(i),'.txt')
            name_list1(end+1) = name_list0(i);
        end
    end


    for i=1:length(name_list1)
        name_list1(i) = erase(name_list1(i),'.txt'); 
        name_list1(i) = strip(name_list1(i),"right",'_'); 
    end

    Num_Cuts = (length(name_list1)/2);
    
    name_base = name(1:end-4);

    name_num = 1:Num_Cuts;
    % ROI1
    name_suffix1 = 'ROI1';
    % i
    name_suffix2 = 'i';

    Cuts = {};
    theta_list = [];
    hv_list = [];
    value = [];
    for i=1:Num_Cuts
        fullfile(filepath,[name_base '_' num2str(i) '_' name_suffix1 '_' ext])
        Cuts{i} = load_Soleil_Cassiopee(fullfile(filepath,[name_base '_' num2str(i) '_' name_suffix1 '_' ext]));

        theta_list(i) = Cuts{i}.info.sample_theta;
        hv_list(i) = Cuts{i}.info.photon_energy;
    
        value = cat(3,value,Cuts{i}.value);
    end
    
    % combine cuts into map
    if ~all(theta_list==theta_list(1))
        DATA = OxA_MAP(theta_list,Cuts{1}.x,Cuts{1}.y,permute(value,[3 1 2]));
        DATA.info = Cuts{1}.info;
        DATA.info.azimuth_offset = 0;
        DATA.info.sample_theta = theta_list;

        x = [45 75 90 95 111 120 130 141 150 170 ];
        y = [4.2348 4.5356 4.7295 4.7785 4.6109 4.68 4.7803 4.9464 5.0237 5.279];
        DATA.info.workfunction = interp1(x,y,hv_list(1),'spline','extrap'); 

    elseif ~all(hv_list==hv_list(1))
        E_EF = Cuts{1}.y - hv_list(1) + Cuts{1}.info.workfunction;
        DATA = OxA_KZ(hv_list,Cuts{1}.x,E_EF,permute(value,[3 1 2]));
        DATA.info = Cuts{1}.info;
        DATA.info.azimuth_offset = 0;
        DATA.info.photon_energy = hv_list;
    else
        DATA = OxA_MAP(1:Num_Cuts,Cuts{1}.x,Cuts{1}.y,permute(value,[3 1 2]));
        DATA.info = Cuts{1}.info;
        DATA.x_name = 'Index';
        DATA.x_unit = 'cut';
    end

end