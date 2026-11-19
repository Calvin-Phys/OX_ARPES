classdef OxArpes_DataViewer_2D_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ARPES2DDataViewerUIFigure   matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        GridLayout2                 matlab.ui.container.GridLayout
        UIAxes3                     matlab.ui.control.UIAxes
        UIAxes2                     matlab.ui.control.UIAxes
        UIAxes                      matlab.ui.control.UIAxes
        TabGroup                    matlab.ui.container.TabGroup
        PositionTab                 matlab.ui.container.Tab
        GridLayout3                 matlab.ui.container.GridLayout
        AxisUnitCheckBox            matlab.ui.control.CheckBox
        EqualAxisCheckBox           matlab.ui.control.CheckBox
        ShowCrossHairCheckBox       matlab.ui.control.CheckBox
        YEditField_2                matlab.ui.control.NumericEditField
        YEditField_2Label           matlab.ui.control.Label
        XEditField_2                matlab.ui.control.NumericEditField
        XEditField_2Label           matlab.ui.control.Label
        YEditField                  matlab.ui.control.NumericEditField
        YEditFieldLabel             matlab.ui.control.Label
        XEditField                  matlab.ui.control.NumericEditField
        XEditFieldLabel             matlab.ui.control.Label
        ColourTab                   matlab.ui.container.Tab
        GridLayout4                 matlab.ui.container.GridLayout
        ColourMapDropDown           matlab.ui.control.DropDown
        ColourMapDropDownLabel      matlab.ui.control.Label
        FlipCheckBox                matlab.ui.control.CheckBox
        ColourRangeSlider           matlab.ui.control.RangeSlider
        ColourRangeSliderLabel      matlab.ui.control.Label
        OperationTab                matlab.ui.container.Tab
        GridLayout5                 matlab.ui.container.GridLayout
        KconvertButton              matlab.ui.control.Button
        CaptureImageButton          matlab.ui.control.Button
        CalEIDFitFLButton           matlab.ui.control.Button
        InfoTab                     matlab.ui.container.Tab
        GridLayout6                 matlab.ui.container.GridLayout
        WorkfuncEditField           matlab.ui.control.NumericEditField
        WorkfuncEditFieldLabel      matlab.ui.control.Label
        TempKEditField              matlab.ui.control.NumericEditField
        TempKEditFieldLabel         matlab.ui.control.Label
        ModeEditField               matlab.ui.control.EditField
        ModeEditFieldLabel          matlab.ui.control.Label
        BeamlineEditField           matlab.ui.control.EditField
        BeamlineEditFieldLabel      matlab.ui.control.Label
        PEEditField                 matlab.ui.control.NumericEditField
        PEEditFieldLabel            matlab.ui.control.Label
        PolarizationEditField       matlab.ui.control.EditField
        PolarizationEditFieldLabel  matlab.ui.control.Label
        hveVEditField               matlab.ui.control.NumericEditField
        hveVEditFieldLabel          matlab.ui.control.Label
    end


    properties (Access = private)
        DATA_IN
        XX % Description
        YY
        DATA_X_
        DATA_Y_

        FigX_
        FigY_
        FigXY
        FigXY_ch

        DATA_VALUE_MAX
        C % colour order
    end

    methods (Access = private)

        function slice_data(app)
            % YZ
            cond1 = ( abs(app.DATA_IN.x - app.XX) <= app.XEditField_2.Value);
            if ~any(cond1)
                [~,cond1] = min(abs(app.DATA_IN.x - app.XX));
            end
            app.DATA_X_ = squeeze(mean(app.DATA_IN.value(cond1,:),1))';

            % XZ
            cond2 = ( abs(app.DATA_IN.y - app.YY) <= app.YEditField_2.Value);
            if ~any(cond2)
                [~,cond2] = min(abs(app.DATA_IN.y - app.YY));
            end
            app.DATA_Y_ = squeeze(mean(app.DATA_IN.value(:,cond2),2))';

        end

        function display_data(app)
            app.FigXY = imagesc(app.UIAxes,app.DATA_IN.x,app.DATA_IN.y,app.DATA_IN.value');
            set(app.UIAxes,'YDir','normal');

            app.FigX_ = plot(app.UIAxes2,app.DATA_X_,app.DATA_IN.y,'Color',app.C(1,:));
            app.FigY_ = plot(app.UIAxes3,app.DATA_IN.x,app.DATA_Y_,'Color',app.C(1,:));

            value = app.AxisUnitCheckBox.Value;
            if value == 1
                app.UIAxes.XLabel.String = [app.DATA_IN.x_name ' (' app.DATA_IN.x_unit ')' ];
                app.UIAxes.YLabel.String = [app.DATA_IN.y_name ' (' app.DATA_IN.y_unit ')' ];
                app.UIAxes2.XLabel.String = 'Counts (a.u.)';
                app.UIAxes3.YLabel.String = 'Counts (a.u.)';
            else
                app.UIAxes.XLabel.String = [];
                app.UIAxes.YLabel.String = [];
                app.UIAxes2.XLabel.String = [];
                app.UIAxes3.YLabel.String = [];
            end

        end

        function update_positions(app,x,y)
            app.XX = x;
            app.YY = y;
            app.XEditField.Value = x;
            app.YEditField.Value = y;

            app.slice_data();
            app.update_images();

            app.FigXY_ch.Position = [x y];

        end

        function update_images(app)
            app.FigX_.XData = app.DATA_X_;
            app.FigY_.YData = app.DATA_Y_;

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
            else
                colormap(app.UIAxes,eval(cm));
            end

            llmm = app.ColourRangeSlider.Value ./100 .*app.DATA_VALUE_MAX;
            clim(app.UIAxes,llmm);


        end

        function update_info(app)
            if isfield(app.DATA_IN.info,'photon_energy')
                app.hveVEditField.Value = app.DATA_IN.info.photon_energy;
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
                app.WorkfuncEditField.Value = app.DATA_IN.info.workfunction;
            end
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, DATA_INPUT)
            app.DATA_IN = DATA_INPUT;
            app.ARPES2DDataViewerUIFigure.Name = ['ARPES 2D Data Viewer - ' app.DATA_IN.name];
            app.C = orderedcolors("gem");

            % initialise
            app.XX = mean(app.DATA_IN.x);
            app.YY = mean(app.DATA_IN.y);
            app.XEditField.Value = app.XX;
            app.YEditField.Value = app.YY;

            app.DATA_VALUE_MAX = max(app.DATA_IN.value,[],'all');

            % slice data
            app.slice_data();

            % display data
            app.display_data();
            app.update_colourmap();

            % set crosshair
            app.FigXY_ch = drawcrosshair('Parent',app.UIAxes,'Position',[app.XX app.YY],'LineWidth',0.5,'Color',app.C(6,:),'Deletable',0);
            addlistener(app.FigXY_ch,'MovingROI',@(src,data) app.update_positions(data.CurrentPosition(1),data.CurrentPosition(2)));

            % update info
            app.update_info();
        end

        % Value changed function: ColourMapDropDown, ColourRangeSlider,
        % ...and 1 other component
        function ColourMapDropDownValueChanged(app, event)
            value = app.ColourMapDropDown.Value;
            app.update_colourmap();
        end

        % Value changed function: ShowCrossHairCheckBox
        function ShowCrossHairCheckBoxValueChanged(app, event)
            value = app.ShowCrossHairCheckBox.Value;
            if value == 1
                app.FigXY_ch.Visible = 'on';
            else
                app.FigXY_ch.Visible = 'off';
            end
        end

        % Value changed function: AxisUnitCheckBox
        function AxisUnitCheckBoxValueChanged(app, event)
            value = app.AxisUnitCheckBox.Value;
            if value == 1
                app.UIAxes.XLabel.String = [app.DATA_IN.x_name ' (' app.DATA_IN.x_unit ')' ];
                app.UIAxes.YLabel.String = [app.DATA_IN.y_name ' (' app.DATA_IN.y_unit ')' ];
                app.UIAxes2.XLabel.String = 'Counts (a.u.)';
                app.UIAxes3.YLabel.String = 'Counts (a.u.)';
            else
                app.UIAxes.XLabel.String = [];
                app.UIAxes.YLabel.String = [];
                app.UIAxes2.XLabel.String = [];
                app.UIAxes3.YLabel.String = [];
            end
        end

        % Value changed function: XEditField, XEditField_2, YEditField,
        % ...and 1 other component
        function XEditFieldValueChanged(app, event)
            value = app.XEditField.Value;
            app.update_positions(app.XEditField.Value,app.YEditField.Value);
        end

        % Button pushed function: CaptureImageButton
        function CaptureImageButtonPushed(app, event)
            copygraphics(app.GridLayout2,'ContentType',"image",'Resolution',300);
        end

        % Button pushed function: CalEIDFitFLButton
        function CalEIDFitFLButtonPushed(app, event)

            data_eid = ox_energy_intensity_distribution(app.DATA_IN);

            results = repmat(fit_fermi_edge_ox([],[]),1,length(data_eid.info.eid_q));
            for i=1:length(data_eid.info.eid_q)
                results(i) = fit_fermi_edge_ox(data_eid.y,data_eid.info.eid_bkgd(:,i), ...
                    'Temperature', data_eid.info.temperature, ...
                    'Resolution', 0.05,...
                    'FitWindow',0.2,...
                    'FixTemperature', true,...
                    'FixResolution', false,...
                    'Debug', false);
            end
            % to be robust, fit again
            EF0 = mean([results.EF]);
            for i=1:length(data_eid.info.eid_q)
                results(i) = fit_fermi_edge_ox(data_eid.y,data_eid.info.eid_bkgd(:,i), ...
                    'Temperature', data_eid.info.temperature, ...
                    'Fermi0', EF0,...
                    'Resolution', 0.05,...
                    'FitWindow',0.2,...
                    'FixTemperature', true,...
                    'FixResolution', false,...
                    'Debug', false);
            end

            % plot
            data_eid.show();
            clim([0,max(data_eid.value,[],'all')*0.2]);
            CC = cool(size(data_eid.info.eid_bkgd,2));
            hold on
            for i = 1:size(data_eid.info.eid_bkgd,2)
                plot(data_eid.info.eid_bkgd(:,i),data_eid.y,'Color',CC(i,:));
                I_EF = interp1(data_eid.y,data_eid.info.eid_bkgd(:,i),results(i).EF,"linear");
                scatter(I_EF,results(i).EF,'MarkerEdgeColor',CC(i,:));
            end

            idx = (data_eid.info.eid_q <= 0.35 & data_eid.info.eid_q >= 0.15);
            fl = mean([results(idx).EF]);
            app.DATA_IN.info.workfunction = app.DATA_IN.info.photon_energy - fl;
            app.WorkfuncEditField.Value = app.DATA_IN.info.workfunction;

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

        % Button pushed function: KconvertButton
        function KconvertButtonPushed(app, event)
            app.DATA_IN.info.thetay_offset = app.XX;

            prompt = {'Photon Energy (eV)','Work Function (eV)', 'Y offset (deg)'};
            dlgtitle = 'Cut K-space Conversion';
            definput = {num2str(app.DATA_IN.info.photon_energy),num2str(app.DATA_IN.info.workfunction), ...
                num2str(app.DATA_IN.info.thetay_offset)};
            dims = [1 60];
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            if isempty(answer)
                return
            end

            app.DATA_IN.info.photon_energy = str2num(answer{1});
            app.DATA_IN.info.workfunction = str2num(answer{2});
            app.DATA_IN.info.thetay_offset = str2num(answer{3});

            KCUT = app.DATA_IN.kconvert();
            assignin("base",[app.DATA_IN.name '_ksp'],KCUT);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ARPES2DDataViewerUIFigure and hide until all components are created
            app.ARPES2DDataViewerUIFigure = uifigure('Visible', 'off');
            app.ARPES2DDataViewerUIFigure.NumberTitle = 'on';
            app.ARPES2DDataViewerUIFigure.Color = [1 1 1];
            app.ARPES2DDataViewerUIFigure.Position = [100 100 557 577];
            app.ARPES2DDataViewerUIFigure.Name = 'ARPES 2D Data Viewer';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.ARPES2DDataViewerUIFigure);
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
            app.PositionTab.BackgroundColor = [1 1 1];

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.PositionTab);
            app.GridLayout3.ColumnWidth = {'2x', '2x', '1x', '2x', '1x', '2x'};
            app.GridLayout3.ColumnSpacing = 3;
            app.GridLayout3.RowSpacing = 3;
            app.GridLayout3.Padding = [3 3 3 3];
            app.GridLayout3.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create XEditFieldLabel
            app.XEditFieldLabel = uilabel(app.GridLayout3);
            app.XEditFieldLabel.HorizontalAlignment = 'right';
            app.XEditFieldLabel.FontWeight = 'bold';
            app.XEditFieldLabel.Layout.Row = 1;
            app.XEditFieldLabel.Layout.Column = 3;
            app.XEditFieldLabel.Text = 'X';

            % Create XEditField
            app.XEditField = uieditfield(app.GridLayout3, 'numeric');
            app.XEditField.ValueDisplayFormat = '%.4f';
            app.XEditField.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.XEditField.HorizontalAlignment = 'center';
            app.XEditField.FontWeight = 'bold';
            app.XEditField.Layout.Row = 1;
            app.XEditField.Layout.Column = 4;

            % Create YEditFieldLabel
            app.YEditFieldLabel = uilabel(app.GridLayout3);
            app.YEditFieldLabel.HorizontalAlignment = 'right';
            app.YEditFieldLabel.FontWeight = 'bold';
            app.YEditFieldLabel.Layout.Row = 1;
            app.YEditFieldLabel.Layout.Column = 5;
            app.YEditFieldLabel.Text = 'Y';

            % Create YEditField
            app.YEditField = uieditfield(app.GridLayout3, 'numeric');
            app.YEditField.ValueDisplayFormat = '%.4f';
            app.YEditField.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.YEditField.HorizontalAlignment = 'center';
            app.YEditField.FontWeight = 'bold';
            app.YEditField.Layout.Row = 1;
            app.YEditField.Layout.Column = 6;

            % Create XEditField_2Label
            app.XEditField_2Label = uilabel(app.GridLayout3);
            app.XEditField_2Label.HorizontalAlignment = 'right';
            app.XEditField_2Label.FontWeight = 'bold';
            app.XEditField_2Label.Layout.Row = 2;
            app.XEditField_2Label.Layout.Column = 3;
            app.XEditField_2Label.Text = 'ΔX';

            % Create XEditField_2
            app.XEditField_2 = uieditfield(app.GridLayout3, 'numeric');
            app.XEditField_2.ValueDisplayFormat = '%.4f';
            app.XEditField_2.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.XEditField_2.HorizontalAlignment = 'center';
            app.XEditField_2.FontWeight = 'bold';
            app.XEditField_2.Layout.Row = 2;
            app.XEditField_2.Layout.Column = 4;
            app.XEditField_2.Value = 0.05;

            % Create YEditField_2Label
            app.YEditField_2Label = uilabel(app.GridLayout3);
            app.YEditField_2Label.HorizontalAlignment = 'right';
            app.YEditField_2Label.FontWeight = 'bold';
            app.YEditField_2Label.Layout.Row = 2;
            app.YEditField_2Label.Layout.Column = 5;
            app.YEditField_2Label.Text = 'ΔY';

            % Create YEditField_2
            app.YEditField_2 = uieditfield(app.GridLayout3, 'numeric');
            app.YEditField_2.ValueDisplayFormat = '%.4f';
            app.YEditField_2.ValueChangedFcn = createCallbackFcn(app, @XEditFieldValueChanged, true);
            app.YEditField_2.HorizontalAlignment = 'center';
            app.YEditField_2.FontWeight = 'bold';
            app.YEditField_2.Layout.Row = 2;
            app.YEditField_2.Layout.Column = 6;
            app.YEditField_2.Value = 0.05;

            % Create ShowCrossHairCheckBox
            app.ShowCrossHairCheckBox = uicheckbox(app.GridLayout3);
            app.ShowCrossHairCheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowCrossHairCheckBoxValueChanged, true);
            app.ShowCrossHairCheckBox.Text = 'Show Cross Hair';
            app.ShowCrossHairCheckBox.Layout.Row = 2;
            app.ShowCrossHairCheckBox.Layout.Column = [1 2];
            app.ShowCrossHairCheckBox.Value = true;

            % Create EqualAxisCheckBox
            app.EqualAxisCheckBox = uicheckbox(app.GridLayout3);
            app.EqualAxisCheckBox.Text = 'Equal Axis';
            app.EqualAxisCheckBox.Layout.Row = 1;
            app.EqualAxisCheckBox.Layout.Column = 1;

            % Create AxisUnitCheckBox
            app.AxisUnitCheckBox = uicheckbox(app.GridLayout3);
            app.AxisUnitCheckBox.ValueChangedFcn = createCallbackFcn(app, @AxisUnitCheckBoxValueChanged, true);
            app.AxisUnitCheckBox.Text = 'Axis Unit';
            app.AxisUnitCheckBox.Layout.Row = 1;
            app.AxisUnitCheckBox.Layout.Column = 2;
            app.AxisUnitCheckBox.Value = true;

            % Create ColourTab
            app.ColourTab = uitab(app.TabGroup);
            app.ColourTab.Title = 'Colour';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.ColourTab);
            app.GridLayout4.ColumnWidth = {'1x', '1x', '1x', '3x'};
            app.GridLayout4.ColumnSpacing = 3;
            app.GridLayout4.RowSpacing = 3;
            app.GridLayout4.Padding = [3 3 3 3];
            app.GridLayout4.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create ColourRangeSliderLabel
            app.ColourRangeSliderLabel = uilabel(app.GridLayout4);
            app.ColourRangeSliderLabel.HorizontalAlignment = 'center';
            app.ColourRangeSliderLabel.Layout.Row = [1 2];
            app.ColourRangeSliderLabel.Layout.Column = 3;
            app.ColourRangeSliderLabel.Text = 'Colour Range';

            % Create ColourRangeSlider
            app.ColourRangeSlider = uislider(app.GridLayout4, 'range');
            app.ColourRangeSlider.Limits = [0 200];
            app.ColourRangeSlider.ValueChangedFcn = createCallbackFcn(app, @ColourMapDropDownValueChanged, true);
            app.ColourRangeSlider.Layout.Row = [1 2];
            app.ColourRangeSlider.Layout.Column = 4;

            % Create FlipCheckBox
            app.FlipCheckBox = uicheckbox(app.GridLayout4);
            app.FlipCheckBox.ValueChangedFcn = createCallbackFcn(app, @ColourMapDropDownValueChanged, true);
            app.FlipCheckBox.Text = 'Flip';
            app.FlipCheckBox.Layout.Row = 2;
            app.FlipCheckBox.Layout.Column = 2;
            app.FlipCheckBox.Value = true;

            % Create ColourMapDropDownLabel
            app.ColourMapDropDownLabel = uilabel(app.GridLayout4);
            app.ColourMapDropDownLabel.HorizontalAlignment = 'center';
            app.ColourMapDropDownLabel.Layout.Row = 1;
            app.ColourMapDropDownLabel.Layout.Column = 1;
            app.ColourMapDropDownLabel.Text = 'Colour Map';

            % Create ColourMapDropDown
            app.ColourMapDropDown = uidropdown(app.GridLayout4);
            app.ColourMapDropDown.Items = {'gray', 'hot', 'cool', 'jet', 'parula', 'turbo', 'hsv', 'oxa_blue', 'oxa_heat', 'oxa_redwhiteblue'};
            app.ColourMapDropDown.ValueChangedFcn = createCallbackFcn(app, @ColourMapDropDownValueChanged, true);
            app.ColourMapDropDown.Layout.Row = 1;
            app.ColourMapDropDown.Layout.Column = 2;
            app.ColourMapDropDown.Value = 'oxa_blue';

            % Create OperationTab
            app.OperationTab = uitab(app.TabGroup);
            app.OperationTab.Title = 'Operation';

            % Create GridLayout5
            app.GridLayout5 = uigridlayout(app.OperationTab);
            app.GridLayout5.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.GridLayout5.ColumnSpacing = 3;
            app.GridLayout5.RowSpacing = 3;
            app.GridLayout5.Padding = [3 3 3 3];

            % Create CalEIDFitFLButton
            app.CalEIDFitFLButton = uibutton(app.GridLayout5, 'push');
            app.CalEIDFitFLButton.ButtonPushedFcn = createCallbackFcn(app, @CalEIDFitFLButtonPushed, true);
            app.CalEIDFitFLButton.Tooltip = {'Calculate energy intensity distribution and fit the Fermi level'};
            app.CalEIDFitFLButton.Layout.Row = 1;
            app.CalEIDFitFLButton.Layout.Column = 1;
            app.CalEIDFitFLButton.Text = 'Cal. EID & Fit FL';

            % Create CaptureImageButton
            app.CaptureImageButton = uibutton(app.GridLayout5, 'push');
            app.CaptureImageButton.ButtonPushedFcn = createCallbackFcn(app, @CaptureImageButtonPushed, true);
            app.CaptureImageButton.Layout.Row = 2;
            app.CaptureImageButton.Layout.Column = 1;
            app.CaptureImageButton.Text = 'Capture Image';

            % Create KconvertButton
            app.KconvertButton = uibutton(app.GridLayout5, 'push');
            app.KconvertButton.ButtonPushedFcn = createCallbackFcn(app, @KconvertButtonPushed, true);
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

            % Create WorkfuncEditFieldLabel
            app.WorkfuncEditFieldLabel = uilabel(app.GridLayout6);
            app.WorkfuncEditFieldLabel.HorizontalAlignment = 'right';
            app.WorkfuncEditFieldLabel.Layout.Row = 1;
            app.WorkfuncEditFieldLabel.Layout.Column = 7;
            app.WorkfuncEditFieldLabel.Text = 'Work func.';

            % Create WorkfuncEditField
            app.WorkfuncEditField = uieditfield(app.GridLayout6, 'numeric');
            app.WorkfuncEditField.Layout.Row = 1;
            app.WorkfuncEditField.Layout.Column = 8;

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.GridLayout);
            app.GridLayout2.ColumnWidth = {'3x', '1x'};
            app.GridLayout2.RowHeight = {'3x', '1x'};
            app.GridLayout2.ColumnSpacing = 0;
            app.GridLayout2.RowSpacing = 0;
            app.GridLayout2.Padding = [0 0 0 0];
            app.GridLayout2.Layout.Row = 2;
            app.GridLayout2.Layout.Column = 1;
            app.GridLayout2.BackgroundColor = [1 1 1];

            % Create UIAxes
            app.UIAxes = uiaxes(app.GridLayout2);
            app.UIAxes.XLimitMethod = 'tight';
            app.UIAxes.YLimitMethod = 'tight';
            app.UIAxes.Layer = 'top';
            app.UIAxes.YTickLabelRotation = 90;
            app.UIAxes.LineWidth = 1;
            app.UIAxes.Box = 'on';
            app.UIAxes.TickDir = 'in';
            app.UIAxes.FontSize = 14;
            app.UIAxes.Layout.Row = 1;
            app.UIAxes.Layout.Column = 1;
            colormap(app.UIAxes, 'gray')

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.GridLayout2);
            app.UIAxes2.YLimitMethod = 'tight';
            app.UIAxes2.GridLineWidth = 1;
            app.UIAxes2.YTickLabelRotation = 90;
            app.UIAxes2.LineWidth = 1;
            app.UIAxes2.Box = 'on';
            app.UIAxes2.TickDir = 'in';
            app.UIAxes2.FontSize = 14;
            app.UIAxes2.Layout.Row = 1;
            app.UIAxes2.Layout.Column = 2;

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.GridLayout2);
            app.UIAxes3.XLimitMethod = 'tight';
            app.UIAxes3.GridLineWidth = 1;
            app.UIAxes3.YTickLabelRotation = 90;
            app.UIAxes3.LineWidth = 1;
            app.UIAxes3.Box = 'on';
            app.UIAxes3.TickDir = 'in';
            app.UIAxes3.FontSize = 14;
            app.UIAxes3.Layout.Row = 2;
            app.UIAxes3.Layout.Column = 1;

            % Show the figure after all components are created
            app.ARPES2DDataViewerUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = OxArpes_DataViewer_2D_exported(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ARPES2DDataViewerUIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ARPES2DDataViewerUIFigure)
        end
    end
end