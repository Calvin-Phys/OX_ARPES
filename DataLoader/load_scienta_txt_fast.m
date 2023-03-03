function CUT = load_scienta_txt_fast(file_path)

    % extract data header
    fileID = fopen(file_path);
    tline = fgetl(fileID);
    
    while ~startsWith(tline,'Dimension 1 scale=')
        tline = fgetl(fileID);
    end
    y = cell2mat(textscan(tline(19:end),'%f'))';

    while ~startsWith(tline,'Dimension 2 scale=')
        tline = fgetl(fileID);
    end
    x = cell2mat(textscan(tline(19:end),'%f'))';

    while ~startsWith(tline,'[Data')
        tline = fgetl(fileID);
    end

    value = zeros(length(x),length(y));
    for i=1:length(y)
        tline = fgetl(fileID);
        value(:,i) = cell2mat(textscan(tline(25:end),'%f'));
    end

    fclose(fileID);

    CUT = OxA_CUT(x,y,value);

end

