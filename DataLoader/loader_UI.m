function loader_UI(varargin)
    % load ARPES data to pre-defined class object.
    % input can be: empty - prompt UI window to select files
    % a single file path - load the file
    % a cell of file paths - load all the files

    % memorize last opened directory
    persistent lastPath Path
    if isempty(lastPath) 
        lastPath = 0;
    end

    %% obtain the file list
    if ~isempty(varargin)
        % [~, file, ext] = fileparts(varargin{1});
        if iscell(varargin{1})
            file_list = varargin{1};
        elseif isfile(varargin{1})
            file_list = {varargin{1}};
        else
            return
        end
        
        if isempty(file_list)
            return
        end

    else
        % select folder
        if lastPath == 0
            [file, Path] = uigetfile_with_lastpath(pwd);
        else
            [file, Path] = uigetfile_with_lastpath(lastPath);
        end
    
        % empty
        if Path == 0
            return
        else
            lastPath = Path;
        end

        file_list = {};
        
        if ~iscell(file)
            % one file
            file_list = {fullfile(Path, file)};
        else
            for i = 1:length(file)
                file_list{i} = fullfile(Path, file{i});
            end
        end

    end

    %% load and assign data


    N = length(file_list);

    % multiply file
    f = waitbar(0, '');
    f.Children.Title.Interpreter = 'none';

    % close the waitbar when exiting
    cleanupObj = onCleanup(@() close(f));

    for i = 1:N
        % get file name and ext
        filename = file_list{i};
        [~, basename, ext] = fileparts(filename);

        waitbar(i/N, f, append('Loading selected data [', basename, ext, '] ... ', num2str(i), '/', num2str(N)));

        % Simplify the string replacements for the basename variable
        if contains(basename,'-')
            basename = strrep(basename,'-','_');
        end
        if contains(basename,' ')
            basename = strrep(basename,' ','_');
        end
        if all(ismember(basename(1), '0123456789'))
            basename = ['A' basename];
        end


        % Call the separate function to handle file extensions and loading functions
        data = load_data_by_ext(filename, ext);

        % assign the data to base workspace
        if ~isempty(data)
            data.name = basename;
            assignin('base', basename, data);
        end
    end

%     close(f)
end

function [file, path] = uigetfile_with_lastpath(lastPath_)
    [file, path] = uigetfile({'*.*', 'All Files (*.*)'; ...
                              '*.txt;*.zip', 'Scienta CUT/MAP (*.txt, *.zip)'; ...
                              '*.hdf5', 'Elettra Nano (*.hdf5)'; ...
                              '*.h5', 'SSRL BL5-2; PSI ULTRA/ADRESS (*.h5)'; ...
                              '*.nxs', 'DLS io5/9; ALBA LOREA (*.nxs)'; ...
                              '*.ibw', 'Igor binary wave (*.ibw)'; ...
                              '*.itx', 'Specs itx (*.itx)';...
                              '*.fits', 'ALS Maestro fits (*.fits)';...
                              '*.krx', 'ALBA LOREA Spin (*.krx)';...
                              '*.mat', 'MAT-files (*.mat)'}, ...
                              'Select One or More Files', 'MultiSelect', 'on', lastPath_);
end

function data = load_data_by_ext(filepath, ext)
    % Replace the if...elseif... block with a switch block
    switch ext
        case '.mat'
            evalin('base', append("load('", filepath, "');"));
            data = [];
        case '.txt'
            if endsWith(filepath, '_ROI1_.txt')
                data = load_Soleil_Cassiopee(filepath);
            elseif endsWith(filepath, '_i.txt')
                data = load_Soleil_Cassiopee_folder(filepath);
            else
                data = load_scienta_txt(filepath);
            end
        case '.zip'
            data = load_scienta_zip(filepath);
        case '.hdf5'
            data = load_Elettra_Spectromicroscopy(filepath);
        case '.h5'
            try
                h5readatt(filepath,'/UserSettings','Location');
                flg = 0;
            catch
                flg = 1;
            end
                
            if flg == 0
                data = load_SSRL_BL52(filepath);
            else
                data = load_PSI_ULTRA(filepath);
            end

        case '.nxs'
            try
                data = load_DLS_io5(filepath);
            catch
                try
                    data = load_ALBA_LOREA(filepath);
                catch
                    try
                        data = load_DLS_io9_kPEEM(filepath);
                    catch
                        data = load_DLS_io9_HAXPES(filepath);
                    end
                end
                
            end
        case '.ibw'
            data = load_scienta_IBW(filepath);
        case '.itx'
            data = load_Specs_itx(filepath);
        case '.fits'
            data = load_ALS_Maestro_fits(filepath);
        case '.krx'
            data = load_ALBA_krx(filepath);
        otherwise
            warning(['Fail to load ' filepath '. Check data type.']);
            data = [];
    end
end



% function loader_UI(varargin)
% % load ARPES data to pre-defined class object.
% 
%     % memorize last opened directory
%     persistent lastPath path
%     if isempty(lastPath) 
%         lastPath = 0;
%     end
%     
%     % select folder
%     if lastPath == 0
%         [file,path] = uigetfile({'*.*','All Files (*.*)'; '*.txt;*.zip','Scienta CUT/MAP (*.txt, *.zip)'; ...
%             '*.hdf5','Elettra Nano (*.hdf5)';'*.h5','PSI ULTRA/ADRESS (*.h5)';'*.nxs','DLS io5 (*.nxs)'; ...
%             '*.ibw','Bessy 1^3 (*.ibw)';'*.mat','MAT-files (*.mat)' }, ...
%             'Select One or More Files','MultiSelect', 'on');
%     else 
%         [file,path] = uigetfile({'*.*','All Files (*.*)'; '*.txt;*.zip','Scienta CUT/MAP (*.txt, *.zip)'; ...
%             '*.hdf5','Elettra Nano (*.hdf5)';'*.h5','PSI ULTRA/ADRESS (*.h5)';'*.nxs','DLS io5 (*.nxs)'; ...
%             '*.ibw','Bessy 1^3 (*.ibw)';'*.mat','MAT-files (*.mat)' }, ...
%             'Select One or More Files','MultiSelect', 'on',lastPath);
%     end
% 
%     % empty
%     if path == 0
%         return
%     else
%         lastPath = path;
%     end
% 
%     % one file
%     if ~iscell(file)
%         file = {file};
%     end
%     N = length(file);
% 
%     % multiply file
%     f = waitbar(0,'');
%     f.Children.Title.Interpreter = 'none';
% 
% %     tic
%     for i = 1:N
% 
%         % get file name and ext
%         filename = file{i};
%         [~,basename,ext] = fileparts(filename);
% 
%         waitbar(i/N,f,['Loading selected data [', filename ,'] ... ',num2str(i),'/',num2str(N)]);
% 
%         if strcmp(ext,'.mat')
%             evalin('base',append("load('",fullfile(path, filename),"');"));
%             continue
%         end
% 
%         if strcmp(ext,'.txt')
%             data = load_scienta_txt_fast(fullfile(path, filename));
%         elseif strcmp(ext,'.zip')
%             data = load_scienta_zip_fast(fullfile(path, filename));
%         elseif strcmp(ext,'.hdf5')
%             data = load_Elettra_Spectromicroscopy(fullfile(path, filename));
%         elseif strcmp(ext,'.h5')
%             data = load_PSI_ULTRA(fullfile(path, filename));
%         elseif strcmp(ext,'.nxs')
%             data = load_DLS_io5(fullfile(path, filename));
%         elseif strcmp(ext,'.ibw')
%             data = load_Bessy_IBW(fullfile(path, filename));
%             
%         else
%             warning(['Fail to load ' filename '. Check data type.']);
%             continue
%         end
%         
%         if contains(basename,'-')
%             basename = strrep(basename,'-','_');
%         end
%         if contains(basename,' ')
%             basename = strrep(basename,' ','_');
%         end
% 
%         data.name = basename;
%         assignin('base',basename,data);
% 
%         
%     end
% %     toc
% 
%     close(f)
% end