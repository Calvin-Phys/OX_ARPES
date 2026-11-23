function window = export_nxmpes_UI()
%EXPORT_NXMPES_UI Select base-workspace OX datasets and save a NeXus file.
%   EXPORT_NXMPES_UI opens the complete workspace variable list. Tick one or
%   more scalar OX datasets, choose a destination, and click Save NXmpes.
%   FIG = EXPORT_NXMPES_UI also returns the owned figure. The GUI calls the
%   existing SAVE_NXMPES backend and never modifies source variables.

    root = fileparts(fileparts(mfilename('fullpath')));
    if isempty(which('save_nxmpes'))
        addpath(fullfile(root,'DataLoader'));
    end
    allowedClasses = {'OxArpes_1D_Data','OxArpes_2D_Data','OxArpes_3D_Data', ...
        'OxArpes_4D_Data','OxA_CUT','OxA_MAP','OxA_MAP_ToF','OxA_KZ','OxA_RSImage'};
    fig = uifigure('Name','OX ARPES | Export NXmpes','Position',[100 100 400 400], ...
        'Visible','off','Tag','NXmpesExportWindow');
    grid = uigridlayout(fig,[7 1],'RowHeight',{24,32,'1x',28,16,28,30}, ...
        'Padding',[10 10 10 10],'RowSpacing',5,'Scrollable','on');
    uilabel(grid,'Text','Export NeXus NXmpes','FontSize',16,'FontWeight','bold');
    statusLabel = uilabel(grid,'Text','','WordWrap','on','Tag','NXmpesStatus');
    variablesTable = uitable(grid,'Data',cell(0,5), ...
        'ColumnName',{'Save','Variable','Size','Class','OX'}, ...
        'ColumnFormat',{'logical','char','char','char','char'}, ...
        'ColumnEditable',[true false false false false], ...
        'ColumnWidth',{46,'auto',60,105,40},'RowName',{}, ...
        'Tag','NXmpesVariables','CellEditCallback',@selectionChanged);
    refreshRow = uigridlayout(grid,[1 2],'ColumnWidth',{85,'1x'},'Padding',0);
    refreshButton = uibutton(refreshRow,'Text','Refresh list','Tag','NXmpesRefresh', ...
        'ButtonPushedFcn',@refreshVariables);
    summaryLabel = uilabel(refreshRow,'Text','','Tag','NXmpesSummary');
    uilabel(grid,'Text','Save to','FontWeight','bold');
    pathRow = uigridlayout(grid,[1 2],'ColumnWidth',{'1x',76},'Padding',0);
    pathField = uieditfield(pathRow,'text','Value',fullfile(pwd,'arpes_export.nxs'), ...
        'Tag','NXmpesPath','ValueChangedFcn',@updateSaveState);
    browseButton = uibutton(pathRow,'Text','Browse...','Tag','NXmpesBrowse', ...
        'ButtonPushedFcn',@browsePath);
    buttons = uigridlayout(grid,[1 3],'ColumnWidth',{'1x',112,70},'Padding',0);
    saveButton = uibutton(buttons,'Text','Save NXmpes','Enable','off', ...
        'Tag','NXmpesSave','ButtonPushedFcn',@saveSelection);
    saveButton.Layout.Column = 2;
    closeButton = uibutton(buttons,'Text','Close','ButtonPushedFcn',@(~,~) delete(fig));
    closeButton.Layout.Column = 3;
    refreshVariables();
    fig.Visible = 'on';
    window = fig;
    if nargout == 0, clear window; end

    function refreshVariables(varargin)
        old = variablesTable.Data;
        selected = {};
        if ~isempty(old), selected = old(cell2mat(old(:,1)),2); end
        variables = evalin('base','whos');
        rows = cell(numel(variables),5);
        for i = 1:numel(variables)
            eligible = isequal(variables(i).size,[1 1]) && ismember(variables(i).class,allowedClasses);
            rows{i,1} = eligible && ismember(variables(i).name,selected);
            rows{i,2} = variables(i).name;
            rows{i,3} = strjoin(cellstr(string(variables(i).size)),'x');
            rows{i,4} = variables(i).class;
            if eligible, rows{i,5} = 'Yes'; else, rows{i,5} = 'No'; end
        end
        variablesTable.Data = rows;
        updateSaveState();
        setStatus('',false);
    end

    function selectionChanged(~,event)
        row = event.Indices(1);
        if event.NewData && ~strcmp(variablesTable.Data{row,5},'Yes')
            variablesTable.Data{row,1} = false;
            setStatus([variablesTable.Data{row,2} ' is not a scalar OX dataset.'],true);
        else
            setStatus('',false);
        end
        updateSaveState();
    end

    function updateSaveState(varargin)
        rows = variablesTable.Data;
        count = 0;
        eligibleCount = 0;
        if ~isempty(rows)
            eligible = strcmp(rows(:,5),'Yes');
            eligibleCount = sum(eligible);
            count = sum(cell2mat(rows(:,1)) & eligible);
        end
        summaryLabel.Text = sprintf('%d variables | %d OX | %d selected',size(rows,1),eligibleCount,count);
        if count > 0 && strlength(strtrim(string(pathField.Value))) > 0
            saveButton.Enable = 'on';
        else
            saveButton.Enable = 'off';
        end
    end

    function browsePath(varargin)
        [name,folder] = uiputfile({'*.nxs','NeXus NXmpes (*.nxs)'}, ...
            'Save selected ARPES datasets',pathField.Value);
        if isequal(name,0), return; end
        pathField.Value = fullfile(folder,name);
        updateSaveState();
    end

    function saveSelection(varargin)
        setappdata(fig,'LastExportReport',[]);
        try
            rows = variablesTable.Data;
            selected = {};
            if ~isempty(rows), selected = rows(cell2mat(rows(:,1)),2); end
            if isempty(selected)
                error('OxArpes:ExportSelection','Select at least one OX dataset.');
            end
            available = evalin('base','who');
            datasets = struct();
            for i = 1:numel(selected)
                name = selected{i};
                if ~isvarname(name) || ~ismember(name,available)
                    error('OxArpes:ExportSelection','Variable %s is no longer available. Refresh the list.',name);
                end
                item = evalin('base',name);
                if ~isscalar(item) || ~ismember(class(item),allowedClasses)
                    error('OxArpes:ExportSelection','Variable %s is no longer a scalar OX dataset. Refresh the list.',name);
                end
                datasets.(name) = item;
            end
            target = strtrim(pathField.Value);
            if isempty(target) || isfolder(target)
                error('OxArpes:ExportPath','Choose a destination filename ending in .nxs.');
            end
            [folder,~,extension] = fileparts(target);
            if ~isempty(folder) && ~isfolder(folder)
                error('OxArpes:ExportPath','The destination folder does not exist. Choose an existing folder.');
            end
            if isempty(extension)
                target = [target '.nxs'];
            elseif ~strcmpi(extension,'.nxs')
                error('OxArpes:ExportPath','Use the .nxs filename extension.');
            end
            pathField.Value = target;
            overwrite = false;
            if isfile(target)
                answer = uiconfirm(fig,'Replace the existing file?', ...
                    'File already exists','Options',{'Replace','Cancel'}, ...
                    'DefaultOption',2,'CancelOption',2);
                if ~strcmp(answer,'Replace'), setStatus('Save cancelled.',false); return; end
                overwrite = true;
            end
            saveButton.Enable = 'off';
            refreshButton.Enable = 'off';
            browseButton.Enable = 'off';
            setStatus(sprintf('Saving %d dataset(s)...',numel(selected)),false);
            drawnow limitrate nocallbacks
            report = save_nxmpes(target,datasets,'Overwrite',overwrite);
            setappdata(fig,'LastExportReport',report);
            message = sprintf('Saved %d dataset(s).',numel(selected));
            if any(arrayfun(@(entry) ~isempty(entry.missing_required),report.entries))
                message = [message ' Some acquisition metadata are missing.'];
            end
            setStatus(message,false);
        catch cause
            setStatus(cause.message,true);
        end
        restoreControls();
    end

    function restoreControls()
        if ~isvalid(variablesTable), return; end
        refreshButton.Enable = 'on';
        browseButton.Enable = 'on';
        updateSaveState();
    end

    function setStatus(message,isError)
        if isempty(message)
            message = 'Tick datasets, choose a file, then click Save NXmpes.';
        end
        statusLabel.Text = message;
        statusLabel.Tooltip = message;
        heights = grid.RowHeight;
        if isError
            statusLabel.FontColor = [0.75 0.15 0.15];
            heights{2} = 48;
        else
            statusLabel.FontColor = [0.2 0.25 0.3];
            heights{2} = 32;
        end
        grid.RowHeight = heights;
    end
end
