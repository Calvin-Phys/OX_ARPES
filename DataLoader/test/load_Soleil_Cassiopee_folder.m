function DATA = load_Soleil_Cassiopee_folder(file)
    % load FS map at Soleil Cassiopee beamline
    
    [filepath,name,ext] = fileparts(file);

    allFiles = dir( filepath );
    allNames = { allFiles.name };

    % remove . and ..
    name_list1 = allNames(3:end);

    for i=1:length(name_list1)
        name_list1(i) = erase(name_list1(i),'.txt'); 
        name_list1(i) = strip(name_list1(i),"right",'_'); 
    end

    name_list2 = {};
    for i=1:length(name_list1)
        name_list2(:,i) = split(name_list1(i),'_');
    end


    Num_Cuts = (size(name_list2,2)/2);
    
    name_base = name_list2{1,1};
    name_num = 1:Num_Cuts;
    % ROI1
    name_suffix1 = name_list2{3,1};
    % i
    name_suffix2 = name_list2{3,2};

    Cuts = {};
    theta_list = [];
    value = [];
    for i=1:Num_Cuts
        Cuts{i} = load_Soleil_Cassiopee(fullfile(filepath,[name_base '_' num2str(i) '_' name_suffix1 '_' ext]));

        theta_list(i) = Cuts{i}.info.sample_theta;
    
        value = cat(3,value,Cuts{i}.value);
    end
    
    % combine cuts into map
    
    DATA = OxA_MAP(theta_list,Cuts{1}.x,Cuts{1}.y,permute(value,[3 1 2]));
    DATA.info = Cuts{1}.info;
    DATA.info.azimuth_offset = 0;
    DATA.info.sample_theta = theta_list;
    

end