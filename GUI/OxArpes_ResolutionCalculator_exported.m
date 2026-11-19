classdef OxArpes_ResolutionCalculator_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ResolutionCalculatorUIFigure    matlab.ui.Figure
        GridLayout                      matlab.ui.container.GridLayout
        ResultsPanel                    matlab.ui.container.Panel
        GridLayout3                     matlab.ui.container.GridLayout
        Label                           matlab.ui.control.Label
        BeamlineResolutionmeVEditField  matlab.ui.control.NumericEditField
        BeamlineResolutionmeVEditFieldLabel  matlab.ui.control.Label
        AnalyzerResolutionmeVEditField  matlab.ui.control.NumericEditField
        AnalyzerResolutionmeVEditFieldLabel  matlab.ui.control.Label
        TempUncertaintymeVEditField     matlab.ui.control.NumericEditField
        TempUncertaintymeVEditFieldLabel  matlab.ui.control.Label
        NoiseFloormeVEditField          matlab.ui.control.NumericEditField
        NoiseFloormeVEditFieldLabel     matlab.ui.control.Label
        TotalResolutionmeVEditField     matlab.ui.control.NumericEditField
        TotalResolutionmeVEditFieldLabel  matlab.ui.control.Label
        UpdateButton                    matlab.ui.control.Button
        ParametersPanel                 matlab.ui.container.Panel
        GridLayout2                     matlab.ui.container.GridLayout
        ExitSlitmEditField              matlab.ui.control.NumericEditField
        ExitSlitmEditFieldLabel         matlab.ui.control.Label
        BeamlineDropDown                matlab.ui.control.DropDown
        BeamlineDropDownLabel           matlab.ui.control.Label
        TemperatureKEditField           matlab.ui.control.NumericEditField
        TemperatureKEditFieldLabel      matlab.ui.control.Label
        HemisphereRadiusmmDropDown      matlab.ui.control.DropDown
        HemisphereRadiusmmDropDownLabel  matlab.ui.control.Label
        AnalyserSlitmDropDown           matlab.ui.control.DropDown
        AnalyserSlitmDropDownLabel      matlab.ui.control.Label
        PassEnergyeVDropDown            matlab.ui.control.DropDown
        PassEnergyeVDropDownLabel       matlab.ui.control.Label
        EhvEditField                    matlab.ui.control.NumericEditField
        EhvLabel                        matlab.ui.control.Label
        PhotonEnergyeVEditField         matlab.ui.control.NumericEditField
        PhotonEnergyeVEditFieldLabel    matlab.ui.control.Label
    end


    methods (Access = private)

        function results = getAnalyzerResolution(app)
            passEnergy_eV = str2num(app.PassEnergyeVDropDown.Value);
            slit_mm = str2num(app.AnalyserSlitmDropDown.Value) / 1000;
            hemisphereRadius_mm = str2num(app.HemisphereRadiusmmDropDown.Value);

            results = 1000*passEnergy_eV*slit_mm/(2*hemisphereRadius_mm);
        end

        function results = getTemperatureUncertainty(app)
            results = 0.08617 * app.TemperatureKEditField.Value;
        end

        function results = getBeamlineResolution(app)

            switch app.BeamlineDropDown.Value
                case 'DLS'

                    x = [0  20 40 60 80 100 400];
                    y = [2.6 3.5 4.6 5.9 7.5 8.6 35];
                    MBR_ref = interp1(x,y,app.ExitSlitmEditField.Value,'makima','extrap'); % 62.7eV, 800I/mm
                    app.EhvEditField.Value = MBR_ref / 62.7 /1000;
                    results = app.PhotonEnergyeVEditField.Value / 62.7 * MBR_ref;
                otherwise
                    results = app.PhotonEnergyeVEditField.Value * app.EhvEditField.Value * 1000;
            end


        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.UpdateButtonPushed()
        end

        % Button pushed function: UpdateButton
        function UpdateButtonPushed(app, event)
            ana = app.getAnalyzerResolution();
            tem = app.getTemperatureUncertainty();

            app.AnalyzerResolutionmeVEditField.Value = ana;
            app.TempUncertaintymeVEditField.Value = tem;

            bmln = app.getBeamlineResolution();
            app.BeamlineResolutionmeVEditField.Value = bmln;

            nos = app.NoiseFloormeVEditField.Value;

            Tot = sqrt(ana^2 +tem^2 + bmln^2 +nos^2);
            app.TotalResolutionmeVEditField.Value = Tot;

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ResolutionCalculatorUIFigure and hide until all components are created
            app.ResolutionCalculatorUIFigure = uifigure('Visible', 'off');
            app.ResolutionCalculatorUIFigure.Position = [100 100 318 542];
            app.ResolutionCalculatorUIFigure.Name = 'Resolution Calculator';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.ResolutionCalculatorUIFigure);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {'7x', 35, '5x'};

            % Create ParametersPanel
            app.ParametersPanel = uipanel(app.GridLayout);
            app.ParametersPanel.Title = 'Parameters';
            app.ParametersPanel.Layout.Row = 1;
            app.ParametersPanel.Layout.Column = 1;

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.ParametersPanel);
            app.GridLayout2.ColumnWidth = {'3x', '2x'};
            app.GridLayout2.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};
            app.GridLayout2.ColumnSpacing = 5;
            app.GridLayout2.RowSpacing = 5;
            app.GridLayout2.Padding = [5 5 5 5];

            % Create PhotonEnergyeVEditFieldLabel
            app.PhotonEnergyeVEditFieldLabel = uilabel(app.GridLayout2);
            app.PhotonEnergyeVEditFieldLabel.HorizontalAlignment = 'center';
            app.PhotonEnergyeVEditFieldLabel.FontColor = [0.0745 0.6235 1];
            app.PhotonEnergyeVEditFieldLabel.Layout.Row = 2;
            app.PhotonEnergyeVEditFieldLabel.Layout.Column = 1;
            app.PhotonEnergyeVEditFieldLabel.Text = 'Photon Energy (eV)';

            % Create PhotonEnergyeVEditField
            app.PhotonEnergyeVEditField = uieditfield(app.GridLayout2, 'numeric');
            app.PhotonEnergyeVEditField.Limits = [0 Inf];
            app.PhotonEnergyeVEditField.HorizontalAlignment = 'center';
            app.PhotonEnergyeVEditField.Layout.Row = 2;
            app.PhotonEnergyeVEditField.Layout.Column = 2;
            app.PhotonEnergyeVEditField.Value = 100;

            % Create EhvLabel
            app.EhvLabel = uilabel(app.GridLayout2);
            app.EhvLabel.HorizontalAlignment = 'center';
            app.EhvLabel.FontColor = [0.0745 0.6235 1];
            app.EhvLabel.Layout.Row = 4;
            app.EhvLabel.Layout.Column = 1;
            app.EhvLabel.Text = 'ΔE / hv';

            % Create EhvEditField
            app.EhvEditField = uieditfield(app.GridLayout2, 'numeric');
            app.EhvEditField.ValueDisplayFormat = '%e';
            app.EhvEditField.HorizontalAlignment = 'center';
            app.EhvEditField.Layout.Row = 4;
            app.EhvEditField.Layout.Column = 2;
            app.EhvEditField.Value = 0.0001;

            % Create PassEnergyeVDropDownLabel
            app.PassEnergyeVDropDownLabel = uilabel(app.GridLayout2);
            app.PassEnergyeVDropDownLabel.HorizontalAlignment = 'center';
            app.PassEnergyeVDropDownLabel.FontColor = [0.3922 0.8314 0.0745];
            app.PassEnergyeVDropDownLabel.Layout.Row = 5;
            app.PassEnergyeVDropDownLabel.Layout.Column = 1;
            app.PassEnergyeVDropDownLabel.Text = 'Pass Energy (eV)';

            % Create PassEnergyeVDropDown
            app.PassEnergyeVDropDown = uidropdown(app.GridLayout2);
            app.PassEnergyeVDropDown.Items = {'1', '2', '5', '10', '20', '50', '100', '200'};
            app.PassEnergyeVDropDown.Layout.Row = 5;
            app.PassEnergyeVDropDown.Layout.Column = 2;
            app.PassEnergyeVDropDown.Value = '20';

            % Create AnalyserSlitmDropDownLabel
            app.AnalyserSlitmDropDownLabel = uilabel(app.GridLayout2);
            app.AnalyserSlitmDropDownLabel.HorizontalAlignment = 'center';
            app.AnalyserSlitmDropDownLabel.FontColor = [0.3922 0.8314 0.0745];
            app.AnalyserSlitmDropDownLabel.Layout.Row = 6;
            app.AnalyserSlitmDropDownLabel.Layout.Column = 1;
            app.AnalyserSlitmDropDownLabel.Text = 'Analyser Slit (μm)';

            % Create AnalyserSlitmDropDown
            app.AnalyserSlitmDropDown = uidropdown(app.GridLayout2);
            app.AnalyserSlitmDropDown.Items = {'50', '100', '200', '300', '400', '500', '800', '1000'};
            app.AnalyserSlitmDropDown.Layout.Row = 6;
            app.AnalyserSlitmDropDown.Layout.Column = 2;
            app.AnalyserSlitmDropDown.Value = '200';

            % Create HemisphereRadiusmmDropDownLabel
            app.HemisphereRadiusmmDropDownLabel = uilabel(app.GridLayout2);
            app.HemisphereRadiusmmDropDownLabel.HorizontalAlignment = 'center';
            app.HemisphereRadiusmmDropDownLabel.FontColor = [0.3922 0.8314 0.0745];
            app.HemisphereRadiusmmDropDownLabel.Layout.Row = 7;
            app.HemisphereRadiusmmDropDownLabel.Layout.Column = 1;
            app.HemisphereRadiusmmDropDownLabel.Text = 'Hemisphere Radius (mm)';

            % Create HemisphereRadiusmmDropDown
            app.HemisphereRadiusmmDropDown = uidropdown(app.GridLayout2);
            app.HemisphereRadiusmmDropDown.Items = {'180', '200'};
            app.HemisphereRadiusmmDropDown.Layout.Row = 7;
            app.HemisphereRadiusmmDropDown.Layout.Column = 2;
            app.HemisphereRadiusmmDropDown.Value = '200';

            % Create TemperatureKEditFieldLabel
            app.TemperatureKEditFieldLabel = uilabel(app.GridLayout2);
            app.TemperatureKEditFieldLabel.HorizontalAlignment = 'center';
            app.TemperatureKEditFieldLabel.FontColor = [1 0.4118 0.1608];
            app.TemperatureKEditFieldLabel.Layout.Row = 8;
            app.TemperatureKEditFieldLabel.Layout.Column = 1;
            app.TemperatureKEditFieldLabel.Text = 'Temperature (K)';

            % Create TemperatureKEditField
            app.TemperatureKEditField = uieditfield(app.GridLayout2, 'numeric');
            app.TemperatureKEditField.Limits = [0 Inf];
            app.TemperatureKEditField.HorizontalAlignment = 'center';
            app.TemperatureKEditField.Layout.Row = 8;
            app.TemperatureKEditField.Layout.Column = 2;
            app.TemperatureKEditField.Value = 20;

            % Create BeamlineDropDownLabel
            app.BeamlineDropDownLabel = uilabel(app.GridLayout2);
            app.BeamlineDropDownLabel.HorizontalAlignment = 'center';
            app.BeamlineDropDownLabel.Layout.Row = 1;
            app.BeamlineDropDownLabel.Layout.Column = 1;
            app.BeamlineDropDownLabel.Text = 'Beamline';

            % Create BeamlineDropDown
            app.BeamlineDropDown = uidropdown(app.GridLayout2);
            app.BeamlineDropDown.Items = {'DLS', 'Others'};
            app.BeamlineDropDown.Layout.Row = 1;
            app.BeamlineDropDown.Layout.Column = 2;
            app.BeamlineDropDown.Value = 'DLS';

            % Create ExitSlitmEditFieldLabel
            app.ExitSlitmEditFieldLabel = uilabel(app.GridLayout2);
            app.ExitSlitmEditFieldLabel.HorizontalAlignment = 'center';
            app.ExitSlitmEditFieldLabel.FontColor = [0.0745 0.6235 1];
            app.ExitSlitmEditFieldLabel.Layout.Row = 3;
            app.ExitSlitmEditFieldLabel.Layout.Column = 1;
            app.ExitSlitmEditFieldLabel.Text = 'Exit Slit (μm)';

            % Create ExitSlitmEditField
            app.ExitSlitmEditField = uieditfield(app.GridLayout2, 'numeric');
            app.ExitSlitmEditField.HorizontalAlignment = 'center';
            app.ExitSlitmEditField.Layout.Row = 3;
            app.ExitSlitmEditField.Layout.Column = 2;
            app.ExitSlitmEditField.Value = 100;

            % Create UpdateButton
            app.UpdateButton = uibutton(app.GridLayout, 'push');
            app.UpdateButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateButtonPushed, true);
            app.UpdateButton.FontWeight = 'bold';
            app.UpdateButton.Layout.Row = 2;
            app.UpdateButton.Layout.Column = 1;
            app.UpdateButton.Text = ' Update';

            % Create ResultsPanel
            app.ResultsPanel = uipanel(app.GridLayout);
            app.ResultsPanel.Title = 'Results';
            app.ResultsPanel.Layout.Row = 3;
            app.ResultsPanel.Layout.Column = 1;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.ResultsPanel);
            app.GridLayout3.ColumnWidth = {'3x', '2x'};
            app.GridLayout3.RowHeight = {'1x', '1x', '1x', '1x', '0.5x', '1x'};
            app.GridLayout3.ColumnSpacing = 5;
            app.GridLayout3.RowSpacing = 5;
            app.GridLayout3.Padding = [5 5 5 5];

            % Create TotalResolutionmeVEditFieldLabel
            app.TotalResolutionmeVEditFieldLabel = uilabel(app.GridLayout3);
            app.TotalResolutionmeVEditFieldLabel.HorizontalAlignment = 'center';
            app.TotalResolutionmeVEditFieldLabel.FontWeight = 'bold';
            app.TotalResolutionmeVEditFieldLabel.Layout.Row = 6;
            app.TotalResolutionmeVEditFieldLabel.Layout.Column = 1;
            app.TotalResolutionmeVEditFieldLabel.Text = 'Total Resolution (meV)';

            % Create TotalResolutionmeVEditField
            app.TotalResolutionmeVEditField = uieditfield(app.GridLayout3, 'numeric');
            app.TotalResolutionmeVEditField.Editable = 'off';
            app.TotalResolutionmeVEditField.HorizontalAlignment = 'center';
            app.TotalResolutionmeVEditField.FontWeight = 'bold';
            app.TotalResolutionmeVEditField.Layout.Row = 6;
            app.TotalResolutionmeVEditField.Layout.Column = 2;

            % Create NoiseFloormeVEditFieldLabel
            app.NoiseFloormeVEditFieldLabel = uilabel(app.GridLayout3);
            app.NoiseFloormeVEditFieldLabel.HorizontalAlignment = 'center';
            app.NoiseFloormeVEditFieldLabel.FontColor = [0.7176 0.2745 1];
            app.NoiseFloormeVEditFieldLabel.Layout.Row = 4;
            app.NoiseFloormeVEditFieldLabel.Layout.Column = 1;
            app.NoiseFloormeVEditFieldLabel.Text = 'Noise Floor (meV)';

            % Create NoiseFloormeVEditField
            app.NoiseFloormeVEditField = uieditfield(app.GridLayout3, 'numeric');
            app.NoiseFloormeVEditField.Limits = [0 Inf];
            app.NoiseFloormeVEditField.HorizontalAlignment = 'center';
            app.NoiseFloormeVEditField.Layout.Row = 4;
            app.NoiseFloormeVEditField.Layout.Column = 2;

            % Create TempUncertaintymeVEditFieldLabel
            app.TempUncertaintymeVEditFieldLabel = uilabel(app.GridLayout3);
            app.TempUncertaintymeVEditFieldLabel.HorizontalAlignment = 'center';
            app.TempUncertaintymeVEditFieldLabel.FontColor = [1 0.4118 0.1608];
            app.TempUncertaintymeVEditFieldLabel.Layout.Row = 3;
            app.TempUncertaintymeVEditFieldLabel.Layout.Column = 1;
            app.TempUncertaintymeVEditFieldLabel.Text = 'Temp. Uncertainty (meV)';

            % Create TempUncertaintymeVEditField
            app.TempUncertaintymeVEditField = uieditfield(app.GridLayout3, 'numeric');
            app.TempUncertaintymeVEditField.Editable = 'off';
            app.TempUncertaintymeVEditField.HorizontalAlignment = 'center';
            app.TempUncertaintymeVEditField.Layout.Row = 3;
            app.TempUncertaintymeVEditField.Layout.Column = 2;

            % Create AnalyzerResolutionmeVEditFieldLabel
            app.AnalyzerResolutionmeVEditFieldLabel = uilabel(app.GridLayout3);
            app.AnalyzerResolutionmeVEditFieldLabel.HorizontalAlignment = 'center';
            app.AnalyzerResolutionmeVEditFieldLabel.FontColor = [0.3922 0.8314 0.0745];
            app.AnalyzerResolutionmeVEditFieldLabel.Layout.Row = 2;
            app.AnalyzerResolutionmeVEditFieldLabel.Layout.Column = 1;
            app.AnalyzerResolutionmeVEditFieldLabel.Text = 'Analyzer Resolution (meV)';

            % Create AnalyzerResolutionmeVEditField
            app.AnalyzerResolutionmeVEditField = uieditfield(app.GridLayout3, 'numeric');
            app.AnalyzerResolutionmeVEditField.Editable = 'off';
            app.AnalyzerResolutionmeVEditField.HorizontalAlignment = 'center';
            app.AnalyzerResolutionmeVEditField.Layout.Row = 2;
            app.AnalyzerResolutionmeVEditField.Layout.Column = 2;

            % Create BeamlineResolutionmeVEditFieldLabel
            app.BeamlineResolutionmeVEditFieldLabel = uilabel(app.GridLayout3);
            app.BeamlineResolutionmeVEditFieldLabel.HorizontalAlignment = 'center';
            app.BeamlineResolutionmeVEditFieldLabel.FontColor = [0.0745 0.6235 1];
            app.BeamlineResolutionmeVEditFieldLabel.Layout.Row = 1;
            app.BeamlineResolutionmeVEditFieldLabel.Layout.Column = 1;
            app.BeamlineResolutionmeVEditFieldLabel.Text = 'Beamline Resolution (meV)';

            % Create BeamlineResolutionmeVEditField
            app.BeamlineResolutionmeVEditField = uieditfield(app.GridLayout3, 'numeric');
            app.BeamlineResolutionmeVEditField.HorizontalAlignment = 'center';
            app.BeamlineResolutionmeVEditField.Layout.Row = 1;
            app.BeamlineResolutionmeVEditField.Layout.Column = 2;

            % Create Label
            app.Label = uilabel(app.GridLayout3);
            app.Label.HorizontalAlignment = 'center';
            app.Label.Layout.Row = 5;
            app.Label.Layout.Column = [1 2];
            app.Label.Text = '===============================';

            % Show the figure after all components are created
            app.ResolutionCalculatorUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = OxArpes_ResolutionCalculator_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ResolutionCalculatorUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ResolutionCalculatorUIFigure)
        end
    end
end