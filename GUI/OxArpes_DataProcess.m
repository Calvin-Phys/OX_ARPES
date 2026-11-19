classdef OxArpes_DataProcess < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                 matlab.ui.Figure
        RemoveSpikesPanel        matlab.ui.container.Panel
        RemoveButton             matlab.ui.control.Button
        StrengthEditField        matlab.ui.control.NumericEditField
        StrengthEditFieldLabel   matlab.ui.control.Label
        DirectionButtonGroup     matlab.ui.container.ButtonGroup
        VerticalButton           matlab.ui.control.RadioButton
        HorizontalButton         matlab.ui.control.RadioButton
        SelfnormalisePanel       matlab.ui.container.Panel
        NormaliseButton          matlab.ui.control.Button
        NormalisetopeakCheckBox  matlab.ui.control.CheckBox
        RegionButtonGroup        matlab.ui.container.ButtonGroup
        ToEditField              matlab.ui.control.EditField
        ToEditFieldLabel         matlab.ui.control.Label
        FromEditField            matlab.ui.control.EditField
        FromEditFieldLabel       matlab.ui.control.Label
        IndexButton_2            matlab.ui.control.RadioButton
        RealscaleButton_2        matlab.ui.control.RadioButton
        NormalisationdirectionButtonGroup  matlab.ui.container.ButtonGroup
        XYButton                 matlab.ui.control.RadioButton
        XZButton                 matlab.ui.control.RadioButton
        YZButton                 matlab.ui.control.RadioButton
        ZButton                  matlab.ui.control.RadioButton
        YButton                  matlab.ui.control.RadioButton
        XButton                  matlab.ui.control.RadioButton
        FinestructurePanel       matlab.ui.container.Panel
        ZSmoothButton            matlab.ui.control.Button
        sigma_zEditField         matlab.ui.control.NumericEditField
        sigma_zLabel             matlab.ui.control.Label
        ndDerivativeButton       matlab.ui.control.Button
        SmoothButton             matlab.ui.control.Button
        sigma_yEditField         matlab.ui.control.NumericEditField
        sigma_yEditFieldLabel    matlab.ui.control.Label
        sigma_xEditField         matlab.ui.control.NumericEditField
        sigmaLabel               matlab.ui.control.Label
        TruncatedataPanel        matlab.ui.container.Panel
        ResetButton              matlab.ui.control.Button
        TruncateDataButton       matlab.ui.control.Button
        AxisscaleButtonGroup     matlab.ui.container.ButtonGroup
        IndexButton              matlab.ui.control.RadioButton
        RealscaleButton          matlab.ui.control.RadioButton
        EditField_6              matlab.ui.control.EditField
        EditField_5              matlab.ui.control.EditField
        EditField_4              matlab.ui.control.EditField
        EditField_3              matlab.ui.control.EditField
        EditField_2              matlab.ui.control.EditField
        EditField                matlab.ui.control.EditField
        ZLabel                   matlab.ui.control.Label
        YLabel                   matlab.ui.control.Label
        XLabel                   matlab.ui.control.Label
        ToLabel                  matlab.ui.control.Label
        FromLabel                matlab.ui.control.Label
        PlotButton               matlab.ui.control.Button
        RefreshButton            matlab.ui.control.Button
        ListBox                  matlab.ui.control.ListBox
        BlockReductionPanel      matlab.ui.container.Panel
        BlockXEditField          matlab.ui.control.NumericEditField
        BlockYEditField          matlab.ui.control.NumericEditField
        BlockZEditField          matlab.ui.control.NumericEditField
        BlockZLabel              matlab.ui.control.Label
        BlockReduceButton        matlab.ui.control.Button
    end

    properties (Access = private)
        StatusLabel
        DataSummary
        FilterContext
        Heading
        ContentGrid
        ReductionSummary
    end

    methods (Access = public)
        function app = OxArpes_DataProcess
            %OXARPES_DATAPROCESS Process workspace OX 2-D/3-D data.
            %   Add GUI and DataType to the MATLAB path. This .m is the
            %   maintained entry point; OxArpes_DataProcess_legacy.mlapp
            %   preserves the previous App Designer implementation.
            createComponents(app);
            registerApp(app,app.UIFigure);
            setappdata(app.UIFigure,'OxArpesDataProcessApp',app);
            refreshData(app);
            app.UIFigure.Visible = 'on';
            if nargout == 0, clear app; end
        end

        function refreshData(app)
            %REFRESHDATA Refresh compatible variables, retaining selection.
            previous = app.ListBox.Value;
            variables = evalin('base','whos');
            names = {};
            for iVar = 1:numel(variables)
                if ~isequal(variables(iVar).size,[1 1]), continue; end
                candidate = evalin('base',variables(iVar).name);
                if isa(candidate,'OxArpes_2D_Data') || isa(candidate,'OxArpes_3D_Data')
                    names{end+1} = variables(iVar).name; %#ok<AGROW>
                end
            end
            app.ListBox.Items = sort(names);
            if ismember(previous,names)
                app.ListBox.Value = previous;
            elseif ~isempty(names)
                app.ListBox.Value = app.ListBox.Items{1};
            end
            updateContext(app);
        end

        function selectData(app,name)
            %SELECTDATA Validate and select exactly one compatible workspace name.
            name = char(string(name));
            if ~isvarname(name) || ~ismember(name,evalin('base','who'))
                error('OxArpes:ProcessSelection','Select one existing workspace variable name.');
            end
            data = evalin('base',name);
            if ~isscalar(data) || ~(isa(data,'OxArpes_2D_Data') || isa(data,'OxArpes_3D_Data'))
                error('OxArpes:ProcessSelection','Select one OX 2-D or 3-D data object.');
            end
            data.validate();
            if ~ismember(name,app.ListBox.Items), refreshData(app); end
            app.ListBox.Value = name;
            updateContext(app);
        end

        function state = readState(app)
            %READSTATE Inspect controls without refreshing, validating or resetting them.
            cropScale = 'coordinates'; normalScale = 'coordinates';
            if app.IndexButton.Value, cropScale = 'indices'; end
            if app.IndexButton_2.Value, normalScale = 'indices'; end
            parameters = struct();
            parameters.truncate = struct('Scale',cropScale,'Bounds',{{ ...
                app.EditField.Value,app.EditField_4.Value;app.EditField_2.Value,app.EditField_5.Value; ...
                app.EditField_3.Value,app.EditField_6.Value}});
            parameters.smooth = struct('Sigma',[app.sigma_xEditField.Value app.sigma_yEditField.Value]);
            parameters.derivative = parameters.smooth;
            parameters.zsmooth = struct('SigmaZ',app.sigma_zEditField.Value);
            parameters.normalise = struct('Direction',app.NormalisationdirectionButtonGroup.SelectedObject.Text, ...
                'Peak',app.NormalisetopeakCheckBox.Value,'Scale',normalScale, ...
                'Bounds',{{app.FromEditField.Value,app.ToEditField.Value}});
            parameters.median = struct('Window',app.StrengthEditField.Value,'Axis',app.DirectionButtonGroup.SelectedObject.UserData);
            parameters.reduce = struct('Factors',[app.BlockXEditField.Value app.BlockYEditField.Value app.BlockZEditField.Value]);
            state = struct('App',app,'Figure',app.UIFigure,'Selected',app.ListBox.Value, ...
                'Available',{app.ListBox.Items},'Parameters',parameters,'Status',app.StatusLabel.Text, ...
                'ColumnWidths',[app.ContentGrid.ColumnWidth{:}]);
        end

        function resetCrop(app)
            %RESETCROP Restore Min/Max crop bounds, retaining coordinate/index mode.
            ResetButtonPushed(app,[],[]);
        end

        function report = process(app,action,options)
            %PROCESS Process the selected input; omitted options use API defaults.
            %   GUI buttons explicitly pass their current control values.
            if nargin < 3, options = struct(); end
            sourceName = selectedName(app);
            report = ox_data_process_workspace(sourceName,action,options);
            refreshData(app);
            setStatus(app,['Created ' strjoin(report.OutputNames,', ') '. Source: ' sourceName '.'],false);
        end

        function fig = preview(app)
            %PREVIEW Open an owned figure with a 2-D map or central 3-D slices.
            sourceName = selectedName(app);
            data = evalin('base',sourceName);
            data.validate();
            fig = figure('Name',['OX ARPES | ' sourceName],'NumberTitle','off', ...
                'Tag','OxArpes_DataProcess_Preview','Color','white');
            try
                if isa(data,'OxArpes_2D_Data')
                    ax = axes('Parent',fig);
                    drawSlice(app,ax,data.x,data.y,data.value,axisLabel(app,data,'x'),axisLabel(app,data,'y'));
                    title(ax,sourceName,'Interpreter','none');
                else
                    fig.Position(3:4) = [1100 420];
                    layout = tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
                    ix = ceil(numel(data.x)/2); iy = ceil(numel(data.y)/2); iz = ceil(numel(data.z)/2);
                    ax = nexttile(layout);
                    drawSlice(app,ax,data.y,data.z,reshape(data.value(ix,:,:),numel(data.y),numel(data.z)), ...
                        axisLabel(app,data,'y'),axisLabel(app,data,'z'));
                    title(ax,sprintf('X = %.5g (index %d)',data.x(ix),ix));
                    ax = nexttile(layout);
                    drawSlice(app,ax,data.x,data.z,reshape(data.value(:,iy,:),numel(data.x),numel(data.z)), ...
                        axisLabel(app,data,'x'),axisLabel(app,data,'z'));
                    title(ax,sprintf('Y = %.5g (index %d)',data.y(iy),iy));
                    ax = nexttile(layout);
                    drawSlice(app,ax,data.x,data.y,data.value(:,:,iz),axisLabel(app,data,'x'),axisLabel(app,data,'y'));
                    title(ax,sprintf('Z = %.5g (index %d)',data.z(iz),iz));
                    title(layout,sourceName,'Interpreter','none');
                end
                setStatus(app,['Preview opened for ' sourceName '.'],false);
            catch exception
                delete(fig);
                rethrow(exception);
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure), delete(app.UIFigure); end
        end
    end

    methods (Access = private)
        function sourceName = selectedName(app)
            sourceName = app.ListBox.Value;
            if isempty(sourceName) || ~isvarname(sourceName)
                error('OxArpes:ProcessSelection','Load an OX 2-D or 3-D object into the workspace, then refresh.');
            end
            if ~ismember(sourceName,evalin('base','who'))
                error('OxArpes:ProcessSelection','Selected variable no longer exists. Refresh the list.');
            end
            data = evalin('base',sourceName);
            if ~isscalar(data) || ~(isa(data,'OxArpes_2D_Data') || isa(data,'OxArpes_3D_Data'))
                error('OxArpes:ProcessSelection','Selected variable is no longer a compatible OX object.');
            end
        end

        function updateContext(app)
            buttons = {app.PlotButton,app.TruncateDataButton,app.SmoothButton, ...
                app.ndDerivativeButton,app.ZSmoothButton,app.NormaliseButton,app.RemoveButton,app.BlockReduceButton};
            for iButton = 1:numel(buttons), buttons{iButton}.Enable = 'off'; end
            setEnabled(app,{app.ZLabel,app.EditField_3,app.EditField_6, ...
                app.sigma_zLabel,app.sigma_zEditField,app.ZButton,app.XYButton,app.XZButton,app.YZButton, ...
                app.BlockZLabel,app.BlockZEditField},false);
            try
                sourceName = selectedName(app);
                data = evalin('base',sourceName);
                data.validate();
                is3D = isa(data,'OxArpes_3D_Data');
                dimension = 2 + is3D;
                for iButton = 1:numel(buttons), buttons{iButton}.Enable = 'on'; end
                app.ZSmoothButton.Enable = matlab.lang.OnOffSwitchState(is3D);
                app.RemoveButton.Enable = matlab.lang.OnOffSwitchState(~isempty(which('medfilt1')));
                setEnabled(app,{app.ZLabel,app.EditField_3,app.EditField_6, ...
                    app.sigma_zLabel,app.sigma_zEditField,app.ZButton,app.XYButton,app.XZButton,app.YZButton, ...
                    app.BlockZLabel,app.BlockZEditField},is3D);
                if ~is3D && ~ismember(app.NormalisationdirectionButtonGroup.SelectedObject.Text,{'X','Y'})
                    app.NormalisationdirectionButtonGroup.SelectedObject = app.XButton;
                end
                axisNames = 'XYZ';
                lines = {sourceName;class(data);sprintf('%d-D data | %s samples',dimension, ...
                    strjoin(arrayfun(@(k) num2str(numel(data.(lower(axisNames(k))))),1:dimension,'UniformOutput',false),' x '));' '};
                fields = {app.EditField,app.EditField_2,app.EditField_3; ...
                    app.EditField_4,app.EditField_5,app.EditField_6};
                for k = 1:dimension
                    axisName = lower(axisNames(k));
                    coordinates = data.(axisName);
                    line = sprintf('%s: %.6g to %.6g',axisLabel(app,data,axisName),min(coordinates),max(coordinates));
                    lines{end+1} = line; %#ok<AGROW>
                    fields{1,k}.Tooltip = line;
                    fields{2,k}.Tooltip = line;
                end
                app.DataSummary.Value = lines;
                app.VerticalButton.UserData = dimension-1;
                app.HorizontalButton.UserData = dimension;
                if is3D
                    app.FilterContext.Text = 'Y-Z at each X | sigma in samples';
                    app.sigmaLabel.Text = 'Sigma Y'; app.sigma_yEditFieldLabel.Text = 'Sigma Z';
                    app.VerticalButton.Text = 'Y (dimension 2)'; app.HorizontalButton.Text = 'Z (dimension 3)';
                else
                    app.FilterContext.Text = 'X-Y plane | sigma in samples';
                    app.sigmaLabel.Text = 'Sigma X'; app.sigma_yEditFieldLabel.Text = 'Sigma Y';
                    app.VerticalButton.Text = 'X (dimension 1)'; app.HorizontalButton.Text = 'Y (dimension 2)';
                end
                setStatus(app,['Ready: ' sourceName '. Processing creates new workspace variables.'],false);
            catch exception
                app.DataSummary.Value = {'No valid dataset selected.';' '; ...
                    'Load an OX 2-D or 3-D object into the base workspace, then click Refresh.'};
                setStatus(app,exception.message,~isempty(app.ListBox.Items));
            end
            NormalisationdirectionButtonGroupSelectionChanged(app,[],[]);
            updateReductionSummary(app);
        end

        function setEnabled(~,controls,enabled)
            for k = 1:numel(controls), controls{k}.Enable = matlab.lang.OnOffSwitchState(enabled); end
        end

        function setStatus(app,message,isError)
            app.StatusLabel.Text = message;
            app.StatusLabel.Tooltip = message;
            if isError, app.StatusLabel.FontColor = [0.68 0.16 0.13];
            else, app.StatusLabel.FontColor = [0.12 0.31 0.36]; end
        end

        function execute(app,action,options)
            app.UIFigure.Pointer = 'watch';
            cleanup = onCleanup(@() restorePointer(app));
            try
                process(app,action,options);
            catch exception
                setStatus(app,exception.message,true);
                uialert(app.UIFigure,exception.message,'Processing could not finish','Icon','error');
            end
        end

        function restorePointer(app)
            if isvalid(app) && isvalid(app.UIFigure), app.UIFigure.Pointer = 'arrow'; end
        end

        function RefreshButtonPushed(app,~,~), refreshData(app); end
        function PlotButtonPushed(app,~,~)
            try
                preview(app);
            catch exception
                setStatus(app,exception.message,true);
                uialert(app.UIFigure,exception.message,'Preview could not open','Icon','error');
            end
        end
        function SmoothButtonPushed(app,~,~)
            execute(app,'smooth',struct('Sigma',[app.sigma_xEditField.Value app.sigma_yEditField.Value]));
        end
        function ndDerivativeButtonPushed(app,~,~)
            execute(app,'derivative',struct('Sigma',[app.sigma_xEditField.Value app.sigma_yEditField.Value]));
        end
        function ZSmoothButtonPushed(app,~,~)
            execute(app,'zsmooth',struct('SigmaZ',app.sigma_zEditField.Value));
        end
        function TruncateDataButtonPushed(app,~,~)
            bounds = {app.EditField.Value,app.EditField_4.Value; ...
                app.EditField_2.Value,app.EditField_5.Value;app.EditField_3.Value,app.EditField_6.Value};
            scale = 'coordinates';
            if app.IndexButton.Value, scale = 'indices'; end
            execute(app,'truncate',struct('Bounds',{bounds},'Scale',scale));
        end
        function ResetButtonPushed(app,~,~)
            fields = {app.EditField,app.EditField_2,app.EditField_3,app.EditField_4,app.EditField_5,app.EditField_6};
            for k = 1:6
                if k <= 3, fields{k}.Value = 'Min'; else, fields{k}.Value = 'Max'; end
            end
        end
        function NormaliseButtonPushed(app,~,~)
            scale = 'coordinates';
            if app.IndexButton_2.Value, scale = 'indices'; end
            execute(app,'normalise',struct('Direction',app.NormalisationdirectionButtonGroup.SelectedObject.Text, ...
                'Peak',app.NormalisetopeakCheckBox.Value,'Scale',scale, ...
                'Bounds',{{app.FromEditField.Value,app.ToEditField.Value}}));
        end
        function NormalisationdirectionButtonGroupSelectionChanged(app,~,~)
            plane = numel(app.NormalisationdirectionButtonGroup.SelectedObject.Text) > 1;
            setEnabled(app,{app.FromEditField,app.ToEditField,app.FromEditFieldLabel, ...
                app.ToEditFieldLabel,app.RealscaleButton_2,app.IndexButton_2},~plane);
            if plane, app.RegionButtonGroup.Title = 'Reference: full plane';
            else, app.RegionButtonGroup.Title = 'Reference region'; end
        end
        function RemoveButtonPushed(app,~,~)
            axisNumber = app.DirectionButtonGroup.SelectedObject.UserData;
            execute(app,'median',struct('Window',app.StrengthEditField.Value,'Axis',axisNumber));
        end

        function BlockReduceButtonPushed(app,~,~)
            execute(app,'reduce',struct('Factors',[app.BlockXEditField.Value app.BlockYEditField.Value app.BlockZEditField.Value]));
        end

        function updateReductionSummary(app)
            try
                name = selectedName(app);
                data = evalin('base',name);
                counts = [numel(data.x),numel(data.y)];
                factors = [app.BlockXEditField.Value app.BlockYEditField.Value];
                if isa(data,'OxArpes_3D_Data')
                    counts(3) = numel(data.z); factors(3) = app.BlockZEditField.Value;
                end
                if any(factors < 1 | factors ~= fix(factors) | factors > counts)
                    app.ReductionSummary.Text = 'Block factors must fit their axes.';
                else
                    app.ReductionSummary.Text = sprintf('Output: %s samples\nTrailing samples omitted: %s', ...
                        strjoin(string(floor(counts./factors)),' x '),strjoin(string(mod(counts,factors)),', '));
                end
            catch
                app.ReductionSummary.Text = 'Select a dataset to see the output size.';
            end
        end

        function text = axisLabel(~,data,axisName)
            text = upper(axisName);
            name = data.([axisName '_name']); unit = data.([axisName '_unit']);
            if ~isempty(name), text = [text ': ' char(string(name))]; end
            if ~isempty(unit), text = [text ' (' char(string(unit)) ')']; end
        end
        function drawSlice(~,ax,x,y,values,xLabel,yLabel)
            % Cell edges honour nonuniform and descending coordinates too.
            xEdges = OxArpes_DataProcess.sampleEdges(x);
            yEdges = OxArpes_DataProcess.sampleEdges(y);
            colors = double(values.');
            colors(end+1,:) = colors(end,:);
            colors(:,end+1) = colors(:,end);
            surface(ax,xEdges,yEdges,zeros(size(colors)),colors,'FaceColor','flat','EdgeColor','none');
            view(ax,2); axis(ax,'tight');
            ax.YDir = 'normal';
            xlabel(ax,xLabel,'Interpreter','none'); ylabel(ax,yLabel,'Interpreter','none');
            colormap(ax,flipud(gray)); colorbar(ax);
        end

        function createComponents(app)
            app.UIFigure = uifigure('Visible','off','Name','OX ARPES | Data Process', ...
                'Position',[80 80 1132 740],'Color',[0.95 0.96 0.98],'AutoResizeChildren','off');
            root = uigridlayout(app.UIFigure,[4 1],'RowHeight',{34,24,'1x',42}, ...
                'Padding',[16 12 16 12],'RowSpacing',8,'BackgroundColor',[0.95 0.96 0.98]);
            app.Heading = uilabel(root,'Text','Data Process','FontSize',23,'FontWeight','bold','FontColor',[0.10 0.22 0.35]);
            uilabel(root,'Text','Select a dataset, choose a processing step, then find the result in your workspace.', ...
                'FontColor',[0.32 0.39 0.46]);
            content = uigridlayout(root,[2 4],'ColumnWidth',{250,407*2/3,407*2/3,407*2/3}, ...
                'RowHeight',{330,'1x'},'Padding',0,'ColumnSpacing',12,'RowSpacing',12, ...
                'BackgroundColor',[0.95 0.96 0.98]);
            content.Layout.Row = 3;
            app.ContentGrid = content;
            content.Scrollable = 'on';
            app.UIFigure.SizeChangedFcn = @(~,~) resizeLayout(app);
            resizeLayout(app);
            workspace = uipanel(content,'Title','Workspace data','FontWeight','bold', ...
                'ForegroundColor',[0.10 0.22 0.35],'BackgroundColor','white');
            place(app,workspace,[1 2],1);
            work = uigridlayout(workspace,[6 1],'RowHeight',{22,'1x',32,180,32,36},'Padding',12,'RowSpacing',8);
            uilabel(work,'Text','OX 2-D and 3-D objects','FontColor',[0.32 0.39 0.46]);
            app.ListBox = uilistbox(work,'Items',{},'FontSize',13, ...
                'ValueChangedFcn',@(~,~) updateContext(app),'Tag','ListBox');
            app.RefreshButton = uibutton(work,'Text','Refresh workspace','ButtonPushedFcn',@app.RefreshButtonPushed);
            app.DataSummary = uitextarea(work,'Editable','off','Value',{'Select a dataset.'},'FontSize',12);
            app.PlotButton = uibutton(work,'Text','Preview slices','ButtonPushedFcn',@app.PlotButtonPushed);
            uilabel(work,'Text',sprintf('Results use new variable names.\nThe source stays selected.'), ...
                'WordWrap','on','FontColor',[0.32 0.39 0.46]);

            app.TruncatedataPanel = section(app,content,'Crop data',1,2);
            crop = uigridlayout(app.TruncatedataPanel,[8 3],'ColumnWidth',{20,'1x','1x'}, ...
                'RowHeight',{52,20,28,28,28,24,32,20},'Padding',12,'RowSpacing',6);
            app.AxisscaleButtonGroup = uibuttongroup(crop,'Title','Bounds use','FontWeight','bold');
            place(app,app.AxisscaleButtonGroup,1,[1 3]);
            app.RealscaleButton = uiradiobutton(app.AxisscaleButtonGroup,'Text','Coordinates','Position',[10 5 110 22],'Value',true);
            app.IndexButton = uiradiobutton(app.AxisscaleButtonGroup,'Text','Indices','Position',[135 5 80 22],'Tooltip','Inclusive, one-based indices');
            app.FromLabel = label(app,crop,'From',2,2); app.ToLabel = label(app,crop,'To',2,3);
            app.XLabel = label(app,crop,'X',3,1); app.YLabel = label(app,crop,'Y',4,1); app.ZLabel = label(app,crop,'Z',5,1);
            app.EditField = boundField(app,crop,'Min',3,2); app.EditField_4 = boundField(app,crop,'Max',3,3);
            app.EditField_2 = boundField(app,crop,'Min',4,2); app.EditField_5 = boundField(app,crop,'Max',4,3);
            app.EditField_3 = boundField(app,crop,'Min',5,2); app.EditField_6 = boundField(app,crop,'Max',5,3);
            hint = label(app,crop,'Min / Max or number; nearest sample',6,[1 3]); hint.FontSize = 11;
            app.ResetButton = uibutton(crop,'Text','Full range','ButtonPushedFcn',@app.ResetButtonPushed);
            place(app,app.ResetButton,7,2);
            app.TruncateDataButton = actionButton(app,crop,'Crop data',@app.TruncateDataButtonPushed,7,3);
            label(app,crop,'Output: _tk',8,[1 3]);

            app.SelfnormalisePanel = section(app,content,'Self normalisation',1,3);
            normal = uigridlayout(app.SelfnormalisePanel,[4 1],'RowHeight',{82,112,24,32},'Padding',12,'RowSpacing',8);
            app.NormalisationdirectionButtonGroup = uibuttongroup(normal,'Title','Reduce along axis / plane','FontWeight','bold', ...
                'SelectionChangedFcn',@app.NormalisationdirectionButtonGroupSelectionChanged);
            group = app.NormalisationdirectionButtonGroup;
            app.XButton = radio(app,group,'X',[12 32 50 22],true);
            app.YButton = radio(app,group,'Y',[85 32 50 22],false);
            app.ZButton = radio(app,group,'Z',[160 32 50 22],false);
            app.XYButton = radio(app,group,'XY',[12 5 50 22],false);
            app.XZButton = radio(app,group,'XZ',[85 5 50 22],false);
            app.YZButton = radio(app,group,'YZ',[160 5 50 22],false);
            app.RegionButtonGroup = uibuttongroup(normal,'Title','Reference region','FontWeight','bold');
            group = app.RegionButtonGroup;
            app.FromEditFieldLabel = uilabel(group,'Text','From','Position',[10 58 42 22]);
            app.ToEditFieldLabel = uilabel(group,'Text','To','Position',[10 30 42 22]);
            app.FromEditField = uieditfield(group,'text','Value','Min','Position',[54 58 174 24]);
            app.ToEditField = uieditfield(group,'text','Value','Max','Position',[54 30 174 24]);
            app.RealscaleButton_2 = radio(app,group,'Coordinates',[10 3 110 22],true);
            app.IndexButton_2 = radio(app,group,'Indices',[135 3 80 22],false);
            app.NormalisetopeakCheckBox = uicheckbox(normal,'Text','Use peak instead of mean','Value',false);
            app.NormaliseButton = actionButton(app,normal,'Normalise profiles',@app.NormaliseButtonPushed,4,1);
            app.NormaliseButton.Tooltip = 'Divides full profiles by the selected mean or peak. Output: _<axis>_snor';

            app.FinestructurePanel = section(app,content,'Smoothing and derivatives',2,2);
            fine = uigridlayout(app.FinestructurePanel,[5 4],'ColumnWidth',{52,'1x',52,'1x'}, ...
                'RowHeight',{22,28,32,28,32},'Padding',12,'RowSpacing',8,'ColumnSpacing',8);
            app.FilterContext = label(app,fine,'X-Y plane | sigma in samples',1,[1 4]);
            app.FilterContext.FontSize = 11;
            app.sigmaLabel = label(app,fine,'Sigma X',2,1);
            app.sigma_xEditField = sigmaField(app,fine,3,2,2);
            app.sigma_yEditFieldLabel = label(app,fine,'Sigma Y',2,3);
            app.sigma_yEditField = sigmaField(app,fine,3,2,4);
            app.SmoothButton = actionButton(app,fine,'Smooth plane',@app.SmoothButtonPushed,3,[1 2]);
            app.ndDerivativeButton = actionButton(app,fine,'2nd derivatives',@app.ndDerivativeButtonPushed,3,[3 4]);
            app.ndDerivativeButton.Tooltip = 'Negative second differences in sample units. Output: _d2x, _d2y (Y/Z for 3-D).';
            app.sigma_zLabel = label(app,fine,'Sigma Z',4,1);
            app.sigma_zEditField = sigmaField(app,fine,5,4,2);
            tip = label(app,fine,'3-D data only',4,[3 4]); tip.FontSize = 11;
            app.ZSmoothButton = actionButton(app,fine,'Smooth along Z',@app.ZSmoothButtonPushed,5,[1 4]);
            app.SmoothButton.Tooltip = 'Gaussian standard deviations in samples. Output: _sm';
            app.ZSmoothButton.Tooltip = 'Smooths dimension 3 only. Output: _zsm';

            app.RemoveSpikesPanel = section(app,content,'Median spike filter',2,3);
            medianGrid = uigridlayout(app.RemoveSpikesPanel,[4 2],'ColumnWidth',{'1x',70}, ...
                'RowHeight',{78,28,22,32},'Padding',12,'RowSpacing',8);
            app.DirectionButtonGroup = uibuttongroup(medianGrid,'Title','Filter along','FontWeight','bold');
            place(app,app.DirectionButtonGroup,1,[1 2]);
            app.VerticalButton = radio(app,app.DirectionButtonGroup,'X (dimension 1)',[12 29 190 22],true);
            app.HorizontalButton = radio(app,app.DirectionButtonGroup,'Y (dimension 2)',[12 4 190 22],false);
            app.StrengthEditFieldLabel = label(app,medianGrid,'Window (samples)',2,1);
            app.StrengthEditField = uieditfield(medianGrid,'numeric','Value',5,'Limits',[1 Inf],'RoundFractionalValues','on');
            place(app,app.StrengthEditField,2,2);
            hint = label(app,medianGrid,'Positive integer; zero-padded edges',3,[1 2]); hint.FontSize = 11;
            app.RemoveButton = actionButton(app,medianGrid,'Apply median filter',@app.RemoveButtonPushed,4,[1 2]);
            app.RemoveButton.Tooltip = 'Requires Signal Processing Toolbox. Output: _rmspk';
            app.BlockReductionPanel = section(app,content,'Block reduction',[1 2],4);
            reduction = uigridlayout(app.BlockReductionPanel,[10 2],'ColumnWidth',{'1x',80}, ...
                'RowHeight',{22,48,28,28,28,50,44,32,22,'1x'},'Padding',12,'RowSpacing',8);
            label(app,reduction,'Average pixels in each block',1,[1 2]);
            hint = label(app,reduction,'Each factor is a number of samples. Use 1 to keep an axis unchanged.',2,[1 2]);
            hint.WordWrap = 'on';
            label(app,reduction,'X block',3,1);
            app.BlockXEditField = blockField(app,reduction,3,2);
            label(app,reduction,'Y block',4,1);
            app.BlockYEditField = blockField(app,reduction,4,2);
            app.BlockZLabel = label(app,reduction,'Z block (3-D)',5,1);
            app.BlockZEditField = blockField(app,reduction,5,2);
            app.ReductionSummary = label(app,reduction,'Select a dataset.',6,[1 2]);
            app.ReductionSummary.WordWrap = 'on'; app.ReductionSummary.FontSize = 11;
            hint = label(app,reduction,'Coordinates are averaged too. Incomplete trailing blocks are omitted.',7,[1 2]);
            hint.WordWrap = 'on'; hint.FontSize = 11;
            app.BlockReduceButton = actionButton(app,reduction,'Reduce pixels',@app.BlockReduceButtonPushed,8,[1 2]);
            app.BlockReduceButton.Tooltip = 'Average contiguous blocks using the OX block_reduce method. Output: _rd';
            label(app,reduction,'Output: _rd',9,[1 2]);
            app.StatusLabel = uilabel(root,'Text','Ready','WordWrap','on','FontWeight','bold','FontSize',12,'Tag','StatusLabel');
            app.StatusLabel.Layout.Row = 4;
            % Retain component names as stable tags for scripts and UI tests.
            components = properties(app);
            for k = 1:numel(components)
                component = app.(components{k});
                if isscalar(component) && isobject(component) && isprop(component,'Tag')
                    component.Tag = components{k};
                end
            end
        end

        function resizeLayout(app)
            bounds = app.UIFigure.Position;
            columnWidth = max(407*2/3,(bounds(3)-318)/3);
            app.ContentGrid.ColumnWidth = {250,columnWidth,columnWidth,columnWidth};
            app.ContentGrid.RowHeight = {330,max(230,bounds(4)-490)};
        end

        function panel = section(app,parent,title,row,column)
            panel = uipanel(parent,'Title',title,'FontWeight','bold','FontSize',14, ...
                'ForegroundColor',[0.10 0.29 0.39],'BackgroundColor','white');
            place(app,panel,row,column);
        end
        function place(~,control,row,column)
            control.Layout.Row = row; control.Layout.Column = column;
        end
        function control = label(app,parent,text,row,column)
            control = uilabel(parent,'Text',text,'FontSize',12);
            place(app,control,row,column);
        end
        function control = boundField(app,parent,value,row,column)
            control = uieditfield(parent,'text','Value',value);
            place(app,control,row,column);
        end
        function control = blockField(app,parent,row,column)
            control = uieditfield(parent,'numeric','Value',1,'Limits',[1 Inf], ...
                'RoundFractionalValues','on','ValueChangedFcn',@(~,~) updateReductionSummary(app));
            place(app,control,row,column);
        end
        function control = sigmaField(app,parent,value,row,column)
            control = uieditfield(parent,'numeric','Value',value,'Limits',[0 Inf],'LowerLimitInclusive','off');
            place(app,control,row,column);
        end
        function control = radio(~,parent,text,position,selected)
            control = uiradiobutton(parent,'Text',text,'Position',position,'Value',selected);
        end
        function control = actionButton(app,parent,text,callback,row,column)
            control = uibutton(parent,'Text',text,'ButtonPushedFcn',callback, ...
                'BackgroundColor',[0.13 0.36 0.48],'FontColor','white','FontWeight','bold');
            place(app,control,row,column);
        end
    end

    methods (Static, Access = private)
        function edges = sampleEdges(coordinates)
            coordinates = double(coordinates(:).');
            if isscalar(coordinates)
                edges = coordinates + [-0.5 0.5];
            else
                midpoints = coordinates(1:end-1) + diff(coordinates)/2;
                edges = [2*coordinates(1)-midpoints(1),midpoints,2*coordinates(end)-midpoints(end)];
            end
        end
    end
end
