classdef OxArpes_DataViewer_3D_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ARPES3DDataViewerUIFigure   matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        GridLayout8                 matlab.ui.container.GridLayout
        UIAxes5                     matlab.ui.control.UIAxes
        UIAxes7                     matlab.ui.control.UIAxes
        UIAxes6                     matlab.ui.control.UIAxes
        UIAxes3                     matlab.ui.control.UIAxes
        UIAxes4                     matlab.ui.control.UIAxes
        UIAxes2                     matlab.ui.control.UIAxes
        UIAxes                      matlab.ui.control.UIAxes
        TabGroup                    matlab.ui.container.TabGroup
        PositionTab                 matlab.ui.container.Tab
        GridLayout2                 matlab.ui.container.GridLayout
        UnitsCheckBox               matlab.ui.control.CheckBox
        CrosshairCheckBox           matlab.ui.control.CheckBox
        ZEditField_2                matlab.ui.control.NumericEditField
        ZEditField_2Label           matlab.ui.control.Label
        YEditField_2                matlab.ui.control.NumericEditField
        YEditField_2Label           matlab.ui.control.Label
        XEditField_2                matlab.ui.control.NumericEditField
        XEditField_2Label           matlab.ui.control.Label
        ZEditField                  matlab.ui.control.NumericEditField
        ZEditFieldLabel             matlab.ui.control.Label
        YEditField                  matlab.ui.control.NumericEditField
        YEditFieldLabel             matlab.ui.control.Label
        XEditField                  matlab.ui.control.NumericEditField
        XEditFieldLabel             matlab.ui.control.Label
        ViewDirectionDropDown       matlab.ui.control.DropDown
        ViewDirectionDropDownLabel  matlab.ui.control.Label
        ColourTab                   matlab.ui.container.Tab
        GridLayout3                 matlab.ui.container.GridLayout
        FixColourRangeCheckBox      matlab.ui.control.CheckBox
        ColourMapDropDown           matlab.ui.control.DropDown
        ColourMapDropDownLabel      matlab.ui.control.Label
        ColourRangeSlider           matlab.ui.control.RangeSlider
        ColourRangeLabel            matlab.ui.control.Label
        FlipCheckBox                matlab.ui.control.CheckBox
        SliceTab                    matlab.ui.container.Tab
        GridLayout4                 matlab.ui.container.GridLayout
        ClearButton                 matlab.ui.control.Button
        SaveSliceButton             matlab.ui.control.Button
        NPointsEditField            matlab.ui.control.NumericEditField
        NPointsEditFieldLabel       matlab.ui.control.Label
        LengthAEditField            matlab.ui.control.NumericEditField
        LengthAEditFieldLabel       matlab.ui.control.Label
        AngleDegEditField           matlab.ui.control.NumericEditField
        AngleDegEditFieldLabel      matlab.ui.control.Label
        SelectButton                matlab.ui.control.Button
        SliceDataWindowCheckBox     matlab.ui.control.CheckBox
        EnergyDistributionTab       matlab.ui.container.Tab
        GridLayout5                 matlab.ui.container.GridLayout
        FitFermiLevelButton         matlab.ui.control.Button
        ColorLimitSlider            matlab.ui.control.Slider
        ColorLimitLabel             matlab.ui.control.Label
        CalculateButton             matlab.ui.control.Button
        OperationTab                matlab.ui.container.Tab
        GridLayout7                 matlab.ui.container.GridLayout
        KconvertButton              matlab.ui.control.Button
        CaptureImageButton          matlab.ui.control.Button
        InfoTab                     matlab.ui.container.Tab
        GridLayout6                 matlab.ui.container.GridLayout
        WorkfuncEditField           matlab.ui.control.NumericEditField
        WorkfuncLabel               matlab.ui.control.Label
        BeamlineEditField           matlab.ui.control.EditField
        BeamlineEditFieldLabel      matlab.ui.control.Label
        TempKEditField              matlab.ui.control.NumericEditField
        TempKEditFieldLabel         matlab.ui.control.Label
        PEEditField                 matlab.ui.control.NumericEditField
        PEEditFieldLabel            matlab.ui.control.Label
        ModeEditField               matlab.ui.control.EditField
        ModeEditFieldLabel          matlab.ui.control.Label
        PolarizationEditField       matlab.ui.control.EditField
        PolarizationEditFieldLabel  matlab.ui.control.Label
        hveVEditField               matlab.ui.control.NumericEditField
        hveVEditFieldLabel          matlab.ui.control.Label
    end


    properties (Access = private)
        DATA_IN % Description
        DATA_DIR
        XX
        YY
        ZZ
        DATA_XY
        DATA_XZ
        DATA_YZ
        DATA_X_
        DATA_Y_
        DATA_Z_

        DATA_VALUE_MAX
        DATA_EID

        FigXY
        FigXZ
        FigYZ
        FigXY_ch
        FigXZ_ch
        FigYZ_ch

        FigXY_slice
        Fig_slice
        Fig_slice_h

        FigX_
        FigY_
        FigZ_

        C
    end

    methods (Access = private)

        function slice_data(app)

            % YZ
            cond1 = ( abs(app.DATA_IN.x - app.XX) <= app.XEditField_2.Value);
            if ~any(cond1)
                [~,cond1] = min(abs(app.DATA_IN.x - app.XX));
            end
            app.DATA_YZ = squeeze(mean(app.DATA_IN.value(cond1,:,:),1))';

            % XZ
            cond2 = ( abs(app.DATA_IN.y - app.YY) <= app.YEditField_2.Value);
            if ~any(cond2)
                [~,cond2] = min(abs(app.DATA_IN.y - app.YY));
            end
            app.DATA_XZ = squeeze(mean(app.DATA_IN.value(:,cond2,:),2))';

            % XY
            cond3 = ( abs(app.DATA_IN.z - app.ZZ) <= app.ZEditField_2.Value );
            if ~any(cond3)
                [~,cond3] = min(abs(app.DATA_IN.z - app.ZZ));
            end
            app.DATA_XY = squeeze(mean(app.DATA_IN.value(:,:,cond3),3))';

            % X_
            app.DATA_X_ = squeeze(mean(app.DATA_IN.value(:,cond2,cond3),[2 3]));

            % Y_
            app.DATA_Y_ = squeeze(mean(app.DATA_IN.value(cond1,:,cond3),[1 3]));

            % Z_
            app.DATA_Z_ = squeeze(mean(app.DATA_IN.value(cond1,cond2,:),[1 2]));

        end

        function display_data(app)
            app.FigXY = imagesc(app.UIAxes,app.DATA_IN.x,app.DATA_IN.y,app.DATA_XY);
            set(app.UIAxes,'YDir','normal');
            app.FigYZ = imagesc(app.UIAxes2,app.DATA_IN.z,app.DATA_IN.y,app.DATA_YZ');
            set(app.UIAxes2,'YDir','normal');
            set(app.UIAxes2,'XDir','reverse');
            app.FigXZ = imagesc(app.UIAxes3,app.DATA_IN.x,app.DATA_IN.z,app.DATA_XZ);
            set(app.UIAxes3,'YDir','normal');

            app.FigX_ = plot(app.UIAxes5,app.DATA_IN.x,app.DATA_X_);
            app.FigY_ = plot(app.UIAxes4,app.DATA_Y_,app.DATA_IN.y);
            app.FigZ_ = plot(app.UIAxes6,app.DATA_Z_,app.DATA_IN.z);

            value = app.UnitsCheckBox.Value;
            if value == 1
                app.UIAxes.XLabel.String = [app.DATA_IN.x_name ' (' app.DATA_IN.x_unit ')'];
                app.UIAxes.YLabel.String = [app.DATA_IN.y_name ' (' app.DATA_IN.y_unit ')'];
                app.UIAxes2.XLabel.String = [app.DATA_IN.z_name ' (' app.DATA_IN.z_unit ')'];
                app.UIAxes3.YLabel.String = [app.DATA_IN.z_name ' (' app.DATA_IN.z_unit ')'];
                app.UIAxes4.XLabel.String = 'Counts (a.u.)';
                app.UIAxes5.YLabel.String = 'Counts (a.u.)';
            else
                app.UIAxes.XLabel.String = [];
                app.UIAxes.YLabel.String = [];
                app.UIAxes2.XLabel.String = [];
                app.UIAxes3.YLabel.String = [];
                app.UIAxes4.XLabel.String = [];
                app.UIAxes5.YLabel.String = [];
            end

        end

        function update_positions(app,x,y,z)
            app.XX = x;
            app.YY = y;
            app.ZZ = z;
            app.XEditField.Value = x;
            app.YEditField.Value = y;
            app.ZEditField.Value = z;

            app.slice_data();
            app.update_images();


            app.FigXY_ch.Position = [x y];
            app.FigXZ_ch.Position = [x z];
            app.FigYZ_ch.Position = [z y];

        end

        function update_images(app)
            app.FigXY.CData = app.DATA_XY;
            app.FigXZ.CData = app.DATA_XZ;
            app.FigYZ.CData = app.DATA_YZ';

            app.FigX_.YData = app.DATA_X_;
            app.FigY_.XData = app.DATA_Y_;
            app.FigZ_.XData = app.DATA_Z_;

        end

        function update_colourmap(app)

            cm = app.ColourMapDropDown.Value;
            fp = app.FlipCheckBox.Value;

            if strcmp(cm,'oxa_heat')
                load("GUI\oxa_colourmap.mat","oxa_heat");
            elseif strcmp(cm,'oxa_blue')
                load("GUI\oxa_colourmap.mat","oxa_blue");
            elseif strcmp(cm,'oxa_redwhiteblue')
                load("GUI\oxa_colourmap.mat","oxa_redwhilteblue");
            end

            if fp
                cmf = flip(eval(cm));
                colormap(app.UIAxes,cmf);
                colormap(app.UIAxes2,cmf);
                colormap(app.UIAxes3,cmf);
            else
                colormap(app.UIAxes,eval(cm));
                colormap(app.UIAxes2,eval(cm));
                colormap(app.UIAxes3,eval(cm));
            end

            llmm = app.ColourRangeSlider.Value ./100 .*app.DATA_VALUE_MAX;

            clim(app.UIAxes,llmm);
            clim(app.UIAxes2,llmm);
            clim(app.UIAxes3,llmm);

        end

        function update_slice_positions(app,Position)
            dx = Position(2,1) - Position(1,1);
            dy = Position(2,2) - Position(1,2);

            ang = atand(dy/dx);
            len = sqrt(dx^2+dy^2);
            app.AngleDegEditField.Value = ang;
            app.LengthAEditField.Value = len;

            % slice data
            Npoints = app.NPointsEditField.Value;
            xs = linspace(Position(1,1), Position(2,1), Npoints);
            ys = linspace(Position(1,2), Position(2,2), Npoints);
            ls = linspace(0, len, Npoints);

            % ----- build 2D sampling surface (line × z) -----
            % size: [Npoints x Nz]
            [Xq, Zq] = meshgrid(xs, app.DATA_IN.z);   % careful: meshgrid swaps order
            [Yq, ~ ] = meshgrid(ys, app.DATA_IN.z);

            % ----- interpolate using interp3 -----

            slice = interp3(app.DATA_IN.y, app.DATA_IN.x, app.DATA_IN.z, app.DATA_IN.value, Yq',Xq', Zq', 'linear', NaN);

            app.FigXY_slice.CData = slice';
            app.FigXY_slice.XData = ls;

        end

        function update_info(app)
            if isfield(app.DATA_IN.info,'photon_energy')
                try
                    app.hveVEditField.Value = app.DATA_IN.info.photon_energy;
                catch
                    app.hveVEditField.Value = 0;
                end
            end
            if isfield(app.DATA_IN.info,'polarization')
                app.PolarizationEditField.Value = app.DATA_IN.info.polarization;
            end
            if isfield(app.DATA_IN.info,'aquisition_mode')
                app.ModeEditField.Value = app.DATA_IN.info.acquisition_mode;
            end
            if isfield(app.DATA_IN.info,'pass_energy')
                app.PEEditField.Value = app.DATA_IN.info.pass_energy;
            end
            if isfield(app.DATA_IN.info,'temperature')
                app.TempKEditField.Value = app.DATA_IN.info.temperature;
            end
            if isfield(app.DATA_IN.info,'beamline')
                app.BeamlineEditField.Value = app.DATA_IN.info.beamline;
            end
            if isfield(app.DATA_IN.info,'workfunction')
                try
                    app.WorkfuncEditField.Value = app.DATA_IN.info.workfunction;
                catch
                    app.WorkfuncEditField.Value = mean(app.DATA_IN.info.workfunction);
                end
            end
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, DATA_INPUT)
            app.DATA_IN = DATA_INPUT;
            app.DATA_DIR = app.ViewDirectionDropDown.Value;
            app.C = orderedcolors("gem");

            % initialise
            app.XX = mean(app.DATA_IN.x);
            app.YY = mean(app.DATA_IN.y);
            app.ZZ = mean(app.DATA_IN.z);
            app.XEditField.Value = app.XX;
            app.YEditField.Value = app.YY;
            app.ZEditField.Value = app.ZZ;

            app.DATA_VALUE_MAX = max(app.DATA_IN.value,[],'all');

            % slice data
            app.slice_data();

            % display data
            app.display_data();
            app.update_colourmap();

            % set crosshair
            app.FigXY_ch = drawcrosshair('Parent',app.UIAxes,'Position',[app.XX app.YY],'LineWidth',0.5,'Color',app.C(6,:),'Deletable',0);
            app.FigXZ_ch = drawcrosshair('Parent',app.UIAxes3,'Position',[app.XX app.ZZ],'LineWidth',0.5,'Color',app.C(6,:),'Deletable',0);
            app.FigYZ_ch = drawcrosshair('Parent',app.UIAxes2,'Position',[app.ZZ app.YY],'LineWidth',0.5,'Color',app.C(6,:),'Deletable',0);
            addlistener(app.FigXY_ch,'MovingROI',@(src,data) app.update_positions(data.CurrentPosition(1),data.CurrentPosition(2),app.ZZ));
            addlistener(app.FigXZ_ch,'MovingROI',@(src,data) app.update_positions(data.CurrentPosition(1),app.YY,data.CurrentPosition(2)));
            addlistener(app.FigYZ_ch,'MovingROI',@(src,data) app.update_positions(app.XX,data.CurrentPosition(2),data.CurrentPosition(1)));

            % update info
            app.update_info();

        end

        % Value changed function: ColourMapDropDown, ColourRangeSlider,
        % ...and 1 other component
        function ColourMapDropDownValueChanged(app, event)
            value = app.ColourMapDropDown.Value;
            app.update_colourmap();
        end

        % Value changed function: CrosshairCheckBox
        function CrosshairCheckBoxValueChanged(app, event)
            value = app.CrosshairCheckBox.Value;
            if value == 1
                app.FigXY_ch.Visible = 'on';
                app.FigXZ_ch.Visible = 'on';
                app.FigYZ_ch.Visible = 'on';
            else
                app.FigXY_ch.Visible = 'off';
                app.FigXZ_ch.Visible = 'off';
                app.FigYZ_ch.Visible = 'off';
            end
        end

        % Value changed function: XEditField, XEditField_2, YEditField,
        % ...and 3 other components
        function XEditFieldValueChanged(app, event)
            value = app.XEditField.Value;
            app.update_positions(app.XEditField.Value,app.YEditField.Value,app.ZEditField.Value);
        end

        % Value changed function: ViewDirectionDropDown
        function ViewDirectionDropDownValueChanged(app, event)
            value = app.ViewDirectionDropDown.Value;

            app.DATA_IN.value = permute(app.DATA_IN.value,[2 1 3]);
            xx = app.DATA_IN.x;
            yy = app.DATA_IN.y;
            app.DATA_IN.x = yy;
            app.DATA_IN.y = xx;

            update_positions(app,mean(app.DATA_IN.x),mean(app.DATA_IN.y),mean(app.DATA_IN.z));
            % display data
            app.display_data();
            % set crosshair
            app.FigXY_ch = drawcrosshair('Parent',app.UIAxes,'Position',[app.XX app.YY],'LineWidth',0.2,'Color','k');
            app.FigXZ_ch = drawcrosshair('Parent',app.UIAxes3,'Position',[app.XX app.ZZ],'LineWidth',0.2,'Color','k');
            app.FigYZ_ch = drawcrosshair('Parent',app.UIAxes2,'Position',[app.ZZ app.YY],'LineWidth',0.2,'Color','k');
            addlistener(app.FigXY_ch,'MovingROI',@(src,data) app.update_positions(data.CurrentPosition(1),data.CurrentPosition(2),app.ZZ));
            addlistener(app.FigXZ_ch,'MovingROI',@(src,data) app.update_positions(data.CurrentPosition(1),app.YY,data.CurrentPosition(2)));
            addlistener(app.FigYZ_ch,'MovingROI',@(src,data) app.update_positions(app.XX,data.CurrentPosition(2),data.CurrentPosition(1)));

        end

        % Button pushed function: SelectButton
        function SelectButtonPushed(app, event)
            app.FigXY_slice = drawline(app.UIAxes,'Color','r');
            dx = app.FigXY_slice.Position(2,1) - app.FigXY_slice.Position(1,1);
            dy = app.FigXY_slice.Position(2,2) - app.FigXY_slice.Position(1,2);

            ang = atand(dy/dx);
            len = sqrt(dx^2+dy^2);
            app.AngleDegEditField.Value = ang;
            app.LengthAEditField.Value = len;

            addlistener(app.FigXY_slice,'ROIMoved',@(src,data) app.update_slice_positions(data.CurrentPosition));

            % slice data
            Npoints = app.NPointsEditField.Value;
            xs = linspace(app.FigXY_slice.Position(1,1), app.FigXY_slice.Position(2,1), Npoints);
            ys = linspace(app.FigXY_slice.Position(1,2), app.FigXY_slice.Position(2,2), Npoints);
            ls = linspace(0, len, Npoints);

            % ----- build 2D sampling surface (line × z) -----
            % size: [Npoints x Nz]
            [Xq, Zq] = meshgrid(xs, app.DATA_IN.z);   % careful: meshgrid swaps order
            [Yq, ~ ] = meshgrid(ys, app.DATA_IN.z);

            % ----- interpolate using interp3 -----

            slice = interp3(app.DATA_IN.y, app.DATA_IN.x, app.DATA_IN.z, app.DATA_IN.value, Yq',Xq', Zq', 'linear', NaN);

            app.Fig_slice_h = figure("Name",'Data Slice','Visible',app.SliceDataWindowCheckBox.Value);
            ax = axes('Parent',app.Fig_slice_h);
            app.FigXY_slice = imagesc(ax,ls,app.DATA_IN.z,slice');
            axis tight
            set(ax, 'YDir', 'normal');
            xlabel(ax,'{\itk}_{//} (Å^{-1})');
            ylabel(ax,'{\itE} - {\itE}_F (eV)');
            colormap(ax, colormap(app.UIAxes2));       % Apply it to fig2

        end

        % Value changed function: SliceDataWindowCheckBox
        function SliceDataWindowCheckBoxValueChanged(app, event)
            value = app.SliceDataWindowCheckBox.Value;
            if value
                set(app.Fig_slice_h,'Visible','on');
            else
                set(app.Fig_slice_h,'Visible','off');
            end
        end

        % Button pushed function: ClearButton
        function ClearButtonPushed(app, event)
            delete(app.FigXY_slice);
            lines = findobj(app.UIAxes,'Type','images.roi.Line');
            delete(lines);
            close(app.Fig_slice_h);
        end

        % Button pushed function: CalculateButton
        function CalculateButtonPushed(app, event)
            EID = ox_energy_intensity_distribution(app.DATA_IN);

            % plot eid & EDC
            % app.UIAxes7.Visible = "on";
            hold(app.UIAxes7,"on");
            imagesc(app.UIAxes7,EID.x,EID.y,EID.value');
            set(app.UIAxes7,'YDir','normal');
            colormap(app.UIAxes7,flipud(gray));
            clim(app.UIAxes7,[0 app.DATA_VALUE_MAX*app.ColorLimitSlider.Value/100]);

            app.UIAxes7
            for i = 1:size(EID.info.eid_bkgd,2)
                plot(app.UIAxes7,EID.info.eid_bkgd(:,i),EID.y);
            end
            colororder(app.UIAxes7,summer(size(EID.info.eid_bkgd,2)));
            hold(app.UIAxes7,"off");

            app.DATA_EID = EID;

        end

        % Value changed function: ColorLimitSlider
        function ColorLimitSliderValueChanged(app, event)
            value = app.ColorLimitSlider.Value;
            clim(app.UIAxes7,[0 app.DATA_VALUE_MAX*value/100]);
        end

        % Value changed function: UnitsCheckBox
        function UnitsCheckBoxValueChanged(app, event)
            value = app.UnitsCheckBox.Value;
            if value == 1
                app.UIAxes.XLabel.String = [app.DATA_IN.x_name ' (' app.DATA_IN.x_unit ')'];
                app.UIAxes.YLabel.String = [app.DATA_IN.y_name ' (' app.DATA_IN.y_unit ')'];
                app.UIAxes2.XLabel.String = [app.DATA_IN.z_name ' (' app.DATA_IN.z_unit ')'];
                app.UIAxes3.YLabel.String = [app.DATA_IN.z_name ' (' app.DATA_IN.z_unit ')'];
                app.UIAxes4.XLabel.String = 'Counts (a.u.)';
                app.UIAxes5.YLabel.String = 'Counts (a.u.)';
            else
                app.UIAxes.XLabel.String = [];
                app.UIAxes.YLabel.String = [];
                app.UIAxes2.XLabel.String = [];
                app.UIAxes3.YLabel.String = [];
                app.UIAxes4.XLabel.String = [];
                app.UIAxes5.YLabel.String = [];
            end
        end

        % Value changed function: TempKEditField
        function TempKEditFieldValueChanged(app, event)
            value = app.TempKEditField.Value;
            app.DATA_IN.info.temperature = value;
        end

        % Value changed function: hveVEditField
        function hveVEditFieldValueChanged(app, event)
            value = app.hveVEditField.Value;
            app.DATA_IN.info.photon_energy = value;
        end

        % Button pushed function: FitFermiLevelButton
        function FitFermiLevelButtonPushed(app, event)

            results = repmat(fit_fermi_edge_ox([],[]),1,length(app.DATA_EID.info.eid_q));
            for i=1:length(app.DATA_EID.info.eid_q)
                results(i) = fit_fermi_edge_ox(app.DATA_EID.y,app.DATA_EID.info.eid_bkgd(:,i), ...
                    'Temperature', app.DATA_IN.info.temperature, ...
                    'Resolution', 0.05,...
                    'FitWindow',0.2,...
                    'FixTemperature', true,...
                    'FixResolution', false,...
                    'Debug', false);
            end
            % to be robust, fit again
            EF0 = mean([results.EF]);
            for i=1:length(app.DATA_EID.info.eid_q)
                results(i) = fit_fermi_edge_ox(app.DATA_EID.y,app.DATA_EID.info.eid_bkgd(:,i), ...
                    'Temperature', app.DATA_IN.info.temperature, ...
                    'Fermi0', EF0,...
                    'Resolution', 0.05,...
                    'FitWindow',0.2,...
                    'FixTemperature', true,...
                    'FixResolution', false,...
                    'Debug', false);
            end

            hold(app.UIAxes7,'on');
            CC = summer(size(app.DATA_EID.info.eid_bkgd,2));
            for i = 1:size(app.DATA_EID.info.eid_bkgd,2)
                I_EF = interp1(app.DATA_EID.y,app.DATA_EID.info.eid_bkgd(:,i),results(i).EF,"linear");
                scatter(app.UIAxes7,I_EF,results(i).EF,'MarkerEdgeColor',CC(i,:));
            end

            idx = (app.DATA_EID.info.eid_q <= 0.35 & app.DATA_EID.info.eid_q >= 0.15);
            if any(arrayfun(@(s) isempty(s.EF), results(idx)))
                idx = (app.DATA_EID.info.eid_q <= 0.65 & app.DATA_EID.info.eid_q >= 0.35);
            end
            if any(arrayfun(@(s) isempty(s.EF), results(idx)))
                idx = (app.DATA_EID.info.eid_q <= 0.95 & app.DATA_EID.info.eid_q >= 0.65);
            end
            fl = mean([results(idx).EF]);
            app.DATA_IN.info.workfunction = app.DATA_IN.info.photon_energy - fl;
            app.WorkfuncEditField.Value = app.DATA_IN.info.workfunction;
        end

        % Button pushed function: CaptureImageButton
        function CaptureImageButtonPushed(app, event)
            copygraphics(app.GridLayout8,'ContentType',"image",'Resolution',300);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ARPES3DDataViewerUIFigure and hide until all components are created
            app.ARPES3DDataViewerUIFigure = uifigure('Visible', 'off');
            app.ARPES3DDataViewerUIFigure.Position = [100 100 828 749];
            app.ARPES3DDataViewerUIFigure.Name = 'ARPES 3D Data Viewer';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.ARPES3DDataViewerUIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {80, '1x'};
            app.GridLayout.ColumnSpacing = 5;
            app.GridLayout.RowSpacing = 5;
            app.GridLayout.Padding = [5 5 5 5];
            app.GridLayout.BackgroundColor = [1 1 1];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            % Create PositionTab
            app.PositionTab = uitab(app.TabGroup);
            app.PositionTab.Title = 'Position';

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.PositionTab);
            app.GridLayout2.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout2.ColumnSpacing = 3;
            app.GridLayout2.RowSpacing = 3;
            app.GridLayout2.Padding = [3 3 3 3];

            % Create ViewDirectionDropDownLabel
            app.ViewDirectionDropDownLabel = uilabel(app.GridLayout2);
            app.ViewDirectionDropDownLabel.Layout.Row = 1;
            app.ViewDirectionDropDownLabel.Layout.Column = 1;
            app.ViewDirectionDropDownLabel.Text = 'View Direction';

            % Create ViewDirectionDropDown
            app.ViewDirectionDropDown = uidropdown(app.GridLayout2);
            app.ViewDirectionDropDown.Items = {'X-Y', 'Y-X'};
            app.ViewDirectionDropDown.ValueChangedFcn = createCallbackFcn(app, @ViewDirectionDropDownValueChanged, true);
            app.ViewDirectionDropDown.Layout.Row = 1;
            app.ViewDirectionDropDown.Layout.Column = 2;
            app.ViewDirectionDropDown.Value = 'X-Y';

            % Create XEditFieldLabel
            app.XEditFieldLabel = uilabel(app.GridLayout2);
            app.XEditFieldLabel.HorizontalAlignment = 'right';
            app.XEditFieldLabel.Layout.Row = 1;
            app.XEditFieldLabel.Layout.Column = 3;
            app.XEditFieldLabel.Text = 'X';

            % Create XEditField
            app.XEditField = uieditfield(app.GridLayout2, 'numeric');
            app.XEditField.ValueDisplayFormat = '%.4f';
            app.XEditField.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.XEditField.Layout.Row = 1;
            app.XEditField.Layout.Column = 4;

            % Create YEditFieldLabel
            app.YEditFieldLabel = uilabel(app.GridLayout2);
            app.YEditFieldLabel.HorizontalAlignment = 'right';
            app.YEditFieldLabel.Layout.Row = 1;
            app.YEditFieldLabel.Layout.Column = 5;
            app.YEditFieldLabel.Text = 'Y';

            % Create YEditField
            app.YEditField = uieditfield(app.GridLayout2, 'numeric');
            app.YEditField.ValueDisplayFormat = '%.4f';
            app.YEditField.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.YEditField.Layout.Row = 1;
            app.YEditField.Layout.Column = 6;

            % Create ZEditFieldLabel
            app.ZEditFieldLabel = uilabel(app.GridLayout2);
            app.ZEditFieldLabel.HorizontalAlignment = 'right';
            app.ZEditFieldLabel.Layout.Row = 1;
            app.ZEditFieldLabel.Layout.Column = 7;
            app.ZEditFieldLabel.Text = 'Z';

            % Create ZEditField
            app.ZEditField = uieditfield(app.GridLayout2, 'numeric');
            app.ZEditField.ValueDisplayFormat = '%.4f';
            app.ZEditField.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.ZEditField.Layout.Row = 1;
            app.ZEditField.Layout.Column = 8;

            % Create XEditField_2Label
            app.XEditField_2Label = uilabel(app.GridLayout2);
            app.XEditField_2Label.HorizontalAlignment = 'right';
            app.XEditField_2Label.Layout.Row = 2;
            app.XEditField_2Label.Layout.Column = 3;
            app.XEditField_2Label.Text = 'ΔX';

            % Create XEditField_2
            app.XEditField_2 = uieditfield(app.GridLayout2, 'numeric');
            app.XEditField_2.ValueDisplayFormat = '%.4f';
            app.XEditField_2.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.XEditField_2.Layout.Row = 2;
            app.XEditField_2.Layout.Column = 4;

            % Create YEditField_2Label
            app.YEditField_2Label = uilabel(app.GridLayout2);
            app.YEditField_2Label.HorizontalAlignment = 'right';
            app.YEditField_2Label.Layout.Row = 2;
            app.YEditField_2Label.Layout.Column = 5;
            app.YEditField_2Label.Text = 'ΔY';

            % Create YEditField_2
            app.YEditField_2 = uieditfield(app.GridLayout2, 'numeric');
            app.YEditField_2.ValueDisplayFormat = '%.4f';
            app.YEditField_2.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.YEditField_2.Layout.Row = 2;
            app.YEditField_2.Layout.Column = 6;
            app.YEditField_2.Value = 0.05;

            % Create ZEditField_2Label
            app.ZEditField_2Label = uilabel(app.GridLayout2);
            app.ZEditField_2Label.HorizontalAlignment = 'right';
            app.ZEditField_2Label.Layout.Row = 2;
            app.ZEditField_2Label.Layout.Column = 7;
            app.ZEditField_2Label.Text = 'ΔZ';

            % Create ZEditField_2
            app.ZEditField_2 = uieditfield(app.GridLayout2, 'numeric');
            app.ZEditField_2.ValueDisplayFormat = '%.4f';
            app.ZEditField_2.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.ZEditField_2.Layout.Row = 2;
            app.ZEditField_2.Layout.Column = 8;
            app.ZEditField_2.Value = 0.05;

            % Create CrosshairCheckBox
            app.CrosshairCheckBox = uicheckbox(app.GridLayout2);
            app.CrosshairCheckBox.ValueChangedFcn = createCallbackFcn(app, @CrosshairCheckBoxValueChanged, true);
            app.CrosshairCheckBox.Text = 'Crosshair';
            app.CrosshairCheckBox.Layout.Row = 2;
            app.CrosshairCheckBox.Layout.Column = 2;
            app.CrosshairCheckBox.Value = true;

            % Create UnitsCheckBox
            app.UnitsCheckBox = uicheckbox(app.GridLayout2);
            app.UnitsCheckBox.ValueChangedFcn = createCallbackFcn(app, @UnitsCheckBoxValueChanged, true);
            app.UnitsCheckBox.Text = 'Units';
            app.UnitsCheckBox.Layout.Row = 2;
            app.UnitsCheckBox.Layout.Column = 1;
            app.UnitsCheckBox.Value = true;

            % Create ColourTab
            app.ColourTab = uitab(app.TabGroup);
            app.ColourTab.Title = 'Colour';

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.ColourTab);
            app.GridLayout3.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout3.ColumnSpacing = 3;
            app.GridLayout3.RowSpacing = 3;
            app.GridLayout3.Padding = [3 3 3 3];

            % Create FlipCheckBox
            app.FlipCheckBox = uicheckbox(app.GridLayout3);
            app.FlipCheckBox.ValueChangedFcn = createCallbackFcn(app, @ColourMapDropDownValueChanged, true);
            app.FlipCheckBox.Text = 'Flip';
            app.FlipCheckBox.Layout.Row = 2;
            app.FlipCheckBox.Layout.Column = 1;
            app.FlipCheckBox.Value = true;

            % Create ColourRangeLabel
            app.ColourRangeLabel = uilabel(app.GridLayout3);
            app.ColourRangeLabel.HorizontalAlignment = 'right';
            app.ColourRangeLabel.Layout.Row = [1 2];
            app.ColourRangeLabel.Layout.Column = 3;
            app.ColourRangeLabel.Text = 'Colour Range (%)';

            % Create ColourRangeSlider
            app.ColourRangeSlider = uislider(app.GridLayout3, 'range');
            app.ColourRangeSlider.ValueChangedFcn = createCallbackFcn(app, @ColourMapDropDownValueChanged, true);
            app.ColourRangeSlider.Layout.Row = [1 2];
            app.ColourRangeSlider.Layout.Column = [4 6];

            % Create ColourMapDropDownLabel
            app.ColourMapDropDownLabel = uilabel(app.GridLayout3);
            app.ColourMapDropDownLabel.HorizontalAlignment = 'right';
            app.ColourMapDropDownLabel.Layout.Row = 1;
            app.ColourMapDropDownLabel.Layout.Column = 1;
            app.ColourMapDropDownLabel.Text = 'Colour Map';

            % Create ColourMapDropDown
            app.ColourMapDropDown = uidropdown(app.GridLayout3);
            app.ColourMapDropDown.Items = {'gray', 'hot', 'cool', 'jet', 'parula', 'turbo', 'hsv', 'sky', 'abyss', 'oxa_blue', 'oxa_heat'};
            app.ColourMapDropDown.ValueChangedFcn = createCallbackFcn(app, @ColourMapDropDownValueChanged, true);
            app.ColourMapDropDown.Layout.Row = 1;
            app.ColourMapDropDown.Layout.Column = 2;
            app.ColourMapDropDown.Value = 'oxa_blue';

            % Create FixColourRangeCheckBox
            app.FixColourRangeCheckBox = uicheckbox(app.GridLayout3);
            app.FixColourRangeCheckBox.Text = 'Fix Colour Range';
            app.FixColourRangeCheckBox.Layout.Row = 2;
            app.FixColourRangeCheckBox.Layout.Column = 2;

            % Create SliceTab
            app.SliceTab = uitab(app.TabGroup);
            app.SliceTab.Title = 'Slice';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.SliceTab);
            app.GridLayout4.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout4.ColumnSpacing = 3;
            app.GridLayout4.RowSpacing = 3;
            app.GridLayout4.Padding = [3 3 3 3];

            % Create SliceDataWindowCheckBox
            app.SliceDataWindowCheckBox = uicheckbox(app.GridLayout4);
            app.SliceDataWindowCheckBox.ValueChangedFcn = createCallbackFcn(app, @SliceDataWindowCheckBoxValueChanged, true);
            app.SliceDataWindowCheckBox.Text = 'Slice Data Window';
            app.SliceDataWindowCheckBox.Layout.Row = 1;
            app.SliceDataWindowCheckBox.Layout.Column = 1;
            app.SliceDataWindowCheckBox.Value = true;

            % Create SelectButton
            app.SelectButton = uibutton(app.GridLayout4, 'push');
            app.SelectButton.ButtonPushedFcn = createCallbackFcn(app, @SelectButtonPushed, true);
            app.SelectButton.Layout.Row = 2;
            app.SelectButton.Layout.Column = 1;
            app.SelectButton.Text = 'Select';

            % Create AngleDegEditFieldLabel
            app.AngleDegEditFieldLabel = uilabel(app.GridLayout4);
            app.AngleDegEditFieldLabel.HorizontalAlignment = 'right';
            app.AngleDegEditFieldLabel.Layout.Row = 1;
            app.AngleDegEditFieldLabel.Layout.Column = 5;
            app.AngleDegEditFieldLabel.Text = 'Angle (Deg)';

            % Create AngleDegEditField
            app.AngleDegEditField = uieditfield(app.GridLayout4, 'numeric');
            app.AngleDegEditField.Layout.Row = 1;
            app.AngleDegEditField.Layout.Column = 6;

            % Create LengthAEditFieldLabel
            app.LengthAEditFieldLabel = uilabel(app.GridLayout4);
            app.LengthAEditFieldLabel.HorizontalAlignment = 'right';
            app.LengthAEditFieldLabel.Layout.Row = 2;
            app.LengthAEditFieldLabel.Layout.Column = 5;
            app.LengthAEditFieldLabel.Text = 'Length (A)';

            % Create LengthAEditField
            app.LengthAEditField = uieditfield(app.GridLayout4, 'numeric');
            app.LengthAEditField.Layout.Row = 2;
            app.LengthAEditField.Layout.Column = 6;

            % Create NPointsEditFieldLabel
            app.NPointsEditFieldLabel = uilabel(app.GridLayout4);
            app.NPointsEditFieldLabel.HorizontalAlignment = 'right';
            app.NPointsEditFieldLabel.Layout.Row = 1;
            app.NPointsEditFieldLabel.Layout.Column = 3;
            app.NPointsEditFieldLabel.Text = 'NPoints';

            % Create NPointsEditField
            app.NPointsEditField = uieditfield(app.GridLayout4, 'numeric');
            app.NPointsEditField.Layout.Row = 1;
            app.NPointsEditField.Layout.Column = 4;
            app.NPointsEditField.Value = 200;

            % Create SaveSliceButton
            app.SaveSliceButton = uibutton(app.GridLayout4, 'push');
            app.SaveSliceButton.Layout.Row = 2;
            app.SaveSliceButton.Layout.Column = 2;
            app.SaveSliceButton.Text = 'Save Slice';

            % Create ClearButton
            app.ClearButton = uibutton(app.GridLayout4, 'push');
            app.ClearButton.ButtonPushedFcn = createCallbackFcn(app, @ClearButtonPushed, true);
            app.ClearButton.Layout.Row = 1;
            app.ClearButton.Layout.Column = 2;
            app.ClearButton.Text = 'Clear';

            % Create EnergyDistributionTab
            app.EnergyDistributionTab = uitab(app.TabGroup);
            app.EnergyDistributionTab.Title = 'Energy Distribution';

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.EnergyDistributionTab);
            app.GridLayout5.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout5.RowHeight = {'1x'};
            app.GridLayout5.ColumnSpacing = 3;
            app.GridLayout5.RowSpacing = 3;
            app.GridLayout5.Padding = [3 3 3 3];

            % Create CalculateButton
            app.CalculateButton = uibutton(app.GridLayout5, 'push');
            app.CalculateButton.ButtonPushedFcn = createCallbackFcn(app, @CalculateButtonPushed, true);
            app.CalculateButton.Layout.Row = 1;
            app.CalculateButton.Layout.Column = 1;
            app.CalculateButton.Text = 'Calculate';

            % Create ColorLimitLabel
            app.ColorLimitLabel = uilabel(app.GridLayout5);
            app.ColorLimitLabel.HorizontalAlignment = 'right';
            app.ColorLimitLabel.Layout.Row = 1;
            app.ColorLimitLabel.Layout.Column = 3;
            app.ColorLimitLabel.Text = 'Color Limit (%)';

            % Create ColorLimitSlider
            app.ColorLimitSlider = uislider(app.GridLayout5);
            app.ColorLimitSlider.ValueChangedFcn = createCallbackFcn(app, @ColorLimitSliderValueChanged, true);
            app.ColorLimitSlider.Layout.Row = 1;
            app.ColorLimitSlider.Layout.Column = [4 6];
            app.ColorLimitSlider.Value = 18;

            % Create FitFermiLevelButton
            app.FitFermiLevelButton = uibutton(app.GridLayout5, 'push');
            app.FitFermiLevelButton.ButtonPushedFcn = createCallbackFcn(app, @FitFermiLevelButtonPushed, true);
            app.FitFermiLevelButton.Layout.Row = 1;
            app.FitFermiLevelButton.Layout.Column = 2;
            app.FitFermiLevelButton.Text = 'Fit Fermi Level';

            % Create OperationTab
            app.OperationTab = uitab(app.TabGroup);
            app.OperationTab.Title = 'Operation';

            % Create GridLayout7
            app.GridLayout7 = uigridlayout(app.OperationTab);
            app.GridLayout7.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout7.ColumnSpacing = 3;
            app.GridLayout7.RowSpacing = 3;
            app.GridLayout7.Padding = [3 3 3 3];

            % Create CaptureImageButton
            app.CaptureImageButton = uibutton(app.GridLayout7, 'push');
            app.CaptureImageButton.ButtonPushedFcn = createCallbackFcn(app, @CaptureImageButtonPushed, true);
            app.CaptureImageButton.Layout.Row = 1;
            app.CaptureImageButton.Layout.Column = 1;
            app.CaptureImageButton.Text = 'Capture Image';

            % Create KconvertButton
            app.KconvertButton = uibutton(app.GridLayout7, 'push');
            app.KconvertButton.Layout.Row = 1;
            app.KconvertButton.Layout.Column = 2;
            app.KconvertButton.Text = 'K-convert';

            % Create InfoTab
            app.InfoTab = uitab(app.TabGroup);
            app.InfoTab.Title = 'Info';

            % Create GridLayout6
            app.GridLayout6 = uigridlayout(app.InfoTab);
            app.GridLayout6.ColumnWidth = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout6.ColumnSpacing = 3;
            app.GridLayout6.RowSpacing = 3;
            app.GridLayout6.Padding = [3 3 3 3];

            % Create hveVEditFieldLabel
            app.hveVEditFieldLabel = uilabel(app.GridLayout6);
            app.hveVEditFieldLabel.HorizontalAlignment = 'right';
            app.hveVEditFieldLabel.Layout.Row = 1;
            app.hveVEditFieldLabel.Layout.Column = 1;
            app.hveVEditFieldLabel.Text = 'hv (eV)';

            % Create hveVEditField
            app.hveVEditField = uieditfield(app.GridLayout6, 'numeric');
            app.hveVEditField.ValueChangedFcn = createCallbackFcn(app, @hveVEditFieldValueChanged, true);
            app.hveVEditField.Layout.Row = 1;
            app.hveVEditField.Layout.Column = 2;

            % Create PolarizationEditFieldLabel
            app.PolarizationEditFieldLabel = uilabel(app.GridLayout6);
            app.PolarizationEditFieldLabel.HorizontalAlignment = 'right';
            app.PolarizationEditFieldLabel.Layout.Row = 2;
            app.PolarizationEditFieldLabel.Layout.Column = 1;
            app.PolarizationEditFieldLabel.Text = 'Polarization';

            % Create PolarizationEditField
            app.PolarizationEditField = uieditfield(app.GridLayout6, 'text');
            app.PolarizationEditField.Layout.Row = 2;
            app.PolarizationEditField.Layout.Column = 2;

            % Create ModeEditFieldLabel
            app.ModeEditFieldLabel = uilabel(app.GridLayout6);
            app.ModeEditFieldLabel.HorizontalAlignment = 'right';
            app.ModeEditFieldLabel.Layout.Row = 1;
            app.ModeEditFieldLabel.Layout.Column = 3;
            app.ModeEditFieldLabel.Text = 'Mode';

            % Create ModeEditField
            app.ModeEditField = uieditfield(app.GridLayout6, 'text');
            app.ModeEditField.Layout.Row = 1;
            app.ModeEditField.Layout.Column = 4;

            % Create PEEditFieldLabel
            app.PEEditFieldLabel = uilabel(app.GridLayout6);
            app.PEEditFieldLabel.HorizontalAlignment = 'right';
            app.PEEditFieldLabel.Layout.Row = 2;
            app.PEEditFieldLabel.Layout.Column = 3;
            app.PEEditFieldLabel.Text = 'PE';

            % Create PEEditField
            app.PEEditField = uieditfield(app.GridLayout6, 'numeric');
            app.PEEditField.Layout.Row = 2;
            app.PEEditField.Layout.Column = 4;

            % Create TempKEditFieldLabel
            app.TempKEditFieldLabel = uilabel(app.GridLayout6);
            app.TempKEditFieldLabel.HorizontalAlignment = 'right';
            app.TempKEditFieldLabel.Layout.Row = 1;
            app.TempKEditFieldLabel.Layout.Column = 5;
            app.TempKEditFieldLabel.Text = 'Temp. (K)';

            % Create TempKEditField
            app.TempKEditField = uieditfield(app.GridLayout6, 'numeric');
            app.TempKEditField.ValueChangedFcn = createCallbackFcn(app, @TempKEditFieldValueChanged, true);
            app.TempKEditField.Layout.Row = 1;
            app.TempKEditField.Layout.Column = 6;

            % Create BeamlineEditFieldLabel
            app.BeamlineEditFieldLabel = uilabel(app.GridLayout6);
            app.BeamlineEditFieldLabel.HorizontalAlignment = 'right';
            app.BeamlineEditFieldLabel.Layout.Row = 2;
            app.BeamlineEditFieldLabel.Layout.Column = 5;
            app.BeamlineEditFieldLabel.Text = 'Beamline';

            % Create BeamlineEditField
            app.BeamlineEditField = uieditfield(app.GridLayout6, 'text');
            app.BeamlineEditField.Layout.Row = 2;
            app.BeamlineEditField.Layout.Column = 6;

            % Create WorkfuncLabel
            app.WorkfuncLabel = uilabel(app.GridLayout6);
            app.WorkfuncLabel.HorizontalAlignment = 'right';
            app.WorkfuncLabel.Layout.Row = 1;
            app.WorkfuncLabel.Layout.Column = 7;
            app.WorkfuncLabel.Text = 'Work func. ';

            % Create WorkfuncEditField
            app.WorkfuncEditField = uieditfield(app.GridLayout6, 'numeric');
            app.WorkfuncEditField.Layout.Row = 1;
            app.WorkfuncEditField.Layout.Column = 8;

            % Create GridLayout8
            app.GridLayout8 = uigridlayout(app.GridLayout);
            app.GridLayout8.ColumnWidth = {'3x', '1x', '1x', '1x'};
            app.GridLayout8.RowHeight = {'3x', '2x', '1x'};
            app.GridLayout8.ColumnSpacing = 0;
            app.GridLayout8.RowSpacing = 0;
            app.GridLayout8.Padding = [0 0 0 0];
            app.GridLayout8.Layout.Row = 2;
            app.GridLayout8.Layout.Column = 1;
            app.GridLayout8.BackgroundColor = [1 1 1];

            % Create UIAxes
            app.UIAxes = uiaxes(app.GridLayout8);
            app.UIAxes.XLimitMethod = 'tight';
            app.UIAxes.YLimitMethod = 'tight';
            app.UIAxes.ZLimitMethod = 'tight';
            app.UIAxes.Layer = 'top';
            app.UIAxes.XAxisLocation = 'top';
            app.UIAxes.XTickLabelRotation = 0;
            app.UIAxes.YTickLabelRotation = 90;
            app.UIAxes.Box = 'on';
            app.UIAxes.TickDir = 'in';
            app.UIAxes.Layout.Row = 1;
            app.UIAxes.Layout.Column = 1;
            colormap(app.UIAxes, 'sky')

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.GridLayout8);
            app.UIAxes2.XLimitMethod = 'tight';
            app.UIAxes2.YLimitMethod = 'tight';
            app.UIAxes2.ZLimitMethod = 'tight';
            app.UIAxes2.Layer = 'top';
            app.UIAxes2.XAxisLocation = 'top';
            app.UIAxes2.YAxisLocation = 'right';
            app.UIAxes2.YTickLabelRotation = 90;
            app.UIAxes2.Box = 'on';
            app.UIAxes2.TickDir = 'in';
            app.UIAxes2.Layout.Row = 1;
            app.UIAxes2.Layout.Column = [2 3];
            colormap(app.UIAxes2, 'sky')

            % Create UIAxes4
            app.UIAxes4 = uiaxes(app.GridLayout8);
            app.UIAxes4.YLimitMethod = 'tight';
            app.UIAxes4.XAxisLocation = 'top';
            app.UIAxes4.YAxisLocation = 'right';
            app.UIAxes4.YTickLabelRotation = 90;
            app.UIAxes4.YTickLabel = '';
            app.UIAxes4.Box = 'on';
            app.UIAxes4.TickDir = 'in';
            app.UIAxes4.Layout.Row = 1;
            app.UIAxes4.Layout.Column = 4;

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.GridLayout8);
            app.UIAxes3.XLimitMethod = 'tight';
            app.UIAxes3.YLimitMethod = 'tight';
            app.UIAxes3.ZLimitMethod = 'tight';
            app.UIAxes3.Layer = 'top';
            app.UIAxes3.XTickLabelRotation = 0;
            app.UIAxes3.YTickLabelRotation = 90;
            app.UIAxes3.Box = 'on';
            app.UIAxes3.TickDir = 'in';
            app.UIAxes3.Layout.Row = 2;
            app.UIAxes3.Layout.Column = 1;
            colormap(app.UIAxes3, 'sky')

            % Create UIAxes6
            app.UIAxes6 = uiaxes(app.GridLayout8);
            app.UIAxes6.YLimitMethod = 'tight';
            app.UIAxes6.YTickLabelRotation = 90;
            app.UIAxes6.Box = 'on';
            app.UIAxes6.TickDir = 'in';
            app.UIAxes6.Layout.Row = 2;
            app.UIAxes6.Layout.Column = 2;

            % Create UIAxes7
            app.UIAxes7 = uiaxes(app.GridLayout8);
            zlabel(app.UIAxes7, 'Z')
            app.UIAxes7.XLimitMethod = 'tight';
            app.UIAxes7.YLimitMethod = 'tight';
            app.UIAxes7.Layer = 'top';
            app.UIAxes7.Box = 'on';
            app.UIAxes7.Layout.Row = 2;
            app.UIAxes7.Layout.Column = [3 4];

            % Create UIAxes5
            app.UIAxes5 = uiaxes(app.GridLayout8);
            app.UIAxes5.XLimitMethod = 'tight';
            app.UIAxes5.XTickLabel = '';
            app.UIAxes5.YTickLabelRotation = 90;
            app.UIAxes5.Box = 'on';
            app.UIAxes5.TickDir = 'in';
            app.UIAxes5.Layout.Row = 3;
            app.UIAxes5.Layout.Column = 1;

            % Show the figure after all components are created
            app.ARPES3DDataViewerUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = OxArpes_DataViewer_3D_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ARPES3DDataViewerUIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ARPES3DDataViewerUIFigure)
        end
    end
end