classdef FDD_fit_app < handle
%FDD_FIT_APP  Fermi-edge fitting and Fermi-Dirac correction GUI (upgraded FDD_new).
%   app = FDD_FIT_APP opens the GUI and lists ARPES-like variables (fields
%   x, y, value[, z]) from the base workspace.
%   app = FDD_FIT_APP('Visible','off') builds it hidden (tests, export).
%
%   Workflow (left to right):
%     1. Data     choose a cut/map; set the angle (and map y) window and the
%                 energy window, or drag a rectangle on the preview.
%     2. Fit      choose a model, edit start values / Fix boxes, set the fit
%                 window, press Fit. Fitted values, 1-sigma errors and fit
%                 quality appear in the table and summary.
%     3. Apply    write a corrected COPY to the base workspace: shift to
%                 E-EF, shift and divide by the FD edge, or multiply by FD.
%
%   Scriptable interface (same backend as the buttons):
%     app.refreshList()                     re-read base workspace names
%     app.selectData(name)                  select a variable, reset windows
%     app.setWindows('XRange',[a b],'YRange',[c d],'ERange',[e f])
%     app.extractEDC()                      average EDC in the windows
%     app.setModel(key)                     key/legacy label, see FDD_MODELS
%     app.setFitWindow([Emin Emax])
%     app.setStart(Name,Value,...)          start values (struct fields of R.params)
%     app.setFixed(Name,true/false,...)     hold/free individual parameters
%     R = app.fit()                         run FDD_FIT_EDC, update GUI, return R
%     name = app.applyCorrection(mode, outName, 'Overwrite', tf)
%                                           mode 'offset' | 'renormalise'
%     name = app.multiplyFD(T, outName, 'Overwrite', tf)
%     s = app.getState()                    read-only snapshot (no reset)
%     app.exportFigure(file)                300 dpi PNG of the whole window
%   Base-workspace variables are never overwritten unless 'Overwrite' is
%   true (API) or the user confirms (GUI). Source variables are not changed.
%
%   Requires base MATLAB only (R2023a tested). PlotSlices (yulinARPES) is
%   optional and only used by "Open in PlotSlices".

    properties (SetAccess = private)
        UIFigure
        Handles = struct()
        DataName = ''
        Data = []
        EDC = struct('E', [], 'I', [])
        Result = []
    end

    properties (Access = private)
        DragStart = []
        ROIRect = gobjects(0)
    end

    properties (Constant)
        ParamNames = {'Amplitude','Slope','EF','Temperature','Resolution','Background'}
        ParamUnits = {'counts','counts/eV','eV','K','eV FWHM','counts'}
        Colors = struct('title', [0.10 0.20 0.45], 'data', [0.15 0.15 0.15], ...
            'window', [0.00 0.45 0.74], 'fit', [0.85 0.33 0.10], 'ef', [0.47 0.67 0.19], ...
            'renorm', [0.49 0.18 0.56])
    end

    methods
        function app = FDD_fit_app(varargin)
            p = inputParser;
            p.addParameter('Visible', 'on', @(v) any(strcmpi(v, {'on','off'})));
            p.parse(varargin{:});
            app.build(p.Results.Visible);
            app.refreshList();
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        % ---------------- scriptable interface ----------------
        function names = refreshList(app)
            vars = evalin('base', 'whos');
            keep = false(size(vars));
            for k = 1:numel(vars)
                if any(strcmp(vars(k).class, {'struct'})) || ~any(strcmp(vars(k).class, ...
                        {'double','single','char','string','logical','cell','function_handle', ...
                         'int8','int16','int32','int64','uint8','uint16','uint32','uint64','table'}))
                    try
                        v = evalin('base', vars(k).name);
                        fdd_energy_axis(v);
                        keep(k) = true;
                    catch
                        keep(k) = false;
                    end
                end
            end
            names = {vars(keep).name};
            h = app.Handles;
            if isempty(names)
                h.List.Items = {'(no cut/map in workspace)'};
                h.List.ItemsData = {''};
                h.List.Value = '';
            else
                h.List.Items = names;
                h.List.ItemsData = names;
                if any(strcmp(names, app.DataName))
                    h.List.Value = app.DataName;
                else
                    h.List.Value = names{1};
                end
            end
            app.status(sprintf('%d cut/map variable(s) found in the base workspace.', numel(names)));
        end

        function selectData(app, name)
            name = char(name);
            if ~isvarname(name) || ~evalin('base', sprintf('exist(''%s'', ''var'')', name))
                error('FDD:UnknownVariable', 'Base-workspace variable "%s" does not exist.', name);
            end
            data = evalin('base', name);
            [nd, eName] = fdd_energy_axis(data);
            app.Data = data;
            app.DataName = name;
            h = app.Handles;
            if any(strcmp(h.List.ItemsData, name)), h.List.Value = name; end
            x = double(data.x); E = double(data.(eName));
            h.XMin.Value = min(x); h.XMax.Value = max(x);
            h.EMin.Value = min(E); h.EMax.Value = max(E);
            isMap = nd == 3;
            h.YMin.Enable = isMap; h.YMax.Enable = isMap;
            if isMap
                y = double(data.y);
                h.YMin.Value = min(y); h.YMax.Value = max(y);
            end
            h.DataInfo.Text = sprintf('%s  |  %s  |  %s', name, class(data), mat2str(size(data.value)));
            app.clearFit();
            app.drawPreview();
            app.extractEDC();
        end

        function setWindows(app, varargin)
            p = inputParser;
            p.addParameter('XRange', [], @(v) isnumeric(v) && numel(v) == 2);
            p.addParameter('YRange', [], @(v) isnumeric(v) && numel(v) == 2);
            p.addParameter('ERange', [], @(v) isnumeric(v) && numel(v) == 2);
            p.parse(varargin{:});
            h = app.Handles; r = p.Results;
            if ~isempty(r.XRange), h.XMin.Value = min(r.XRange); h.XMax.Value = max(r.XRange); end
            if ~isempty(r.YRange), h.YMin.Value = min(r.YRange); h.YMax.Value = max(r.YRange); end
            if ~isempty(r.ERange), h.EMin.Value = min(r.ERange); h.EMax.Value = max(r.ERange); end
            app.drawROI();
        end

        function [E, I] = extractEDC(app)
            app.requireData();
            h = app.Handles;
            args = {'XRange', [h.XMin.Value h.XMax.Value], 'ERange', [h.EMin.Value h.EMax.Value]};
            if strcmp(h.YMin.Enable, 'on')
                args = [args, {'YRange', [h.YMin.Value h.YMax.Value]}];
            end
            [E, I, info] = fdd_extract_edc(app.Data, args{:});
            app.EDC = struct('E', E, 'I', I);
            app.clearFit();
            h.FitEMin.Value = min(E); h.FitEMax.Value = max(E);
            app.drawROI();
            app.drawEDC();
            app.status(sprintf('EDC: mean of %d spectra, %d energies (%.4g to %.4g eV).', ...
                info.nAngles, numel(E), min(E), max(E)));
        end

        function setModel(app, key)
            m = fdd_models(key);
            app.Handles.Model.Value = m.key;
            app.onModelChanged();
        end

        function setFitWindow(app, w)
            if ~(isnumeric(w) && numel(w) == 2 && all(isfinite(w)) && w(1) ~= w(2))
                error('FDD:InvalidWindow', 'Fit window must be [Emin Emax] with Emin ~= Emax.');
            end
            app.Handles.FitEMin.Value = min(w);
            app.Handles.FitEMax.Value = max(w);
            app.drawEDC();
        end

        function setStart(app, varargin)
            t = app.Handles.Table;
            for k = 1:2:numel(varargin)
                row = app.paramRow(varargin{k});
                v = varargin{k+1};
                if ~(isnumeric(v) && isscalar(v) && isfinite(v))
                    error('FDD:InvalidParameter', 'Start value for %s must be a finite scalar.', varargin{k});
                end
                t.Data{row, 3} = v;
            end
        end

        function setFixed(app, varargin)
            t = app.Handles.Table;
            for k = 1:2:numel(varargin)
                t.Data{app.paramRow(varargin{k}), 4} = logical(varargin{k+1});
            end
        end

        function R = fit(app)
            if isempty(app.EDC.E)
                error('FDD:NoEDC', 'Extract an EDC before fitting.');
            end
            h = app.Handles;
            d = h.Table.Data;
            initial = struct(); fixed = struct(); freeSet = struct();
            m = fdd_models(h.Model.Value);
            for r = 1:6
                n = app.ParamNames{r};
                % Start values are used for free parameters, user-fixed
                % parameters and T; other held parameters stay at 0.
                hasStart = ~isempty(d{r, 3}) && isfinite(d{r, 3});
                if hasStart && (m.free(r) || d{r, 4} || r == 4)
                    initial.(n) = d{r, 3};
                end
                if d{r, 4}
                    if ~isfield(initial, n)
                        error('FDD:InvalidParameter', '%s is fixed but has no start value.', n);
                    end
                    fixed.(n) = initial.(n);
                elseif ~m.free(r)
                    freeSet.(n) = false;
                end
            end
            T = [];
            if isfield(initial, 'Temperature') && initial.Temperature > 0, T = initial.Temperature; end
            R = fdd_fit_edc(app.EDC.E, app.EDC.I, 'Model', m.key, ...
                'Window', [h.FitEMin.Value h.FitEMax.Value], 'Temperature', T, ...
                'Initial', initial, 'Fixed', fixed, 'Free', freeSet, 'Weights', h.Weights.Value);
            app.Result = R;
            for r = 1:6
                n = app.ParamNames{r};
                h.Table.Data{r, 5} = R.params.(n);
                h.Table.Data{r, 6} = R.stderr.(n);
            end
            app.drawEDC();
            app.showSummary();
        end

        function name = applyCorrection(app, mode, outName, varargin)
            app.requireFit();
            p = inputParser;
            p.addParameter('Overwrite', false);
            p.parse(varargin{:});
            mode = validatestring(mode, {'offset', 'renormalise'});
            h = app.Handles;
            [out, info] = fdd_correct_data(app.Data, app.Result.params, ...
                'Renormalise', strcmp(mode, 'renormalise'), ...
                'UseResolution', app.Result.free(5) || app.Result.params.Resolution > 0, ...
                'MinOccupation', h.MinOcc.Value);
            name = app.assignOutput(outName, out, p.Results.Overwrite);
            if strcmp(mode, 'renormalise')
                app.status(sprintf('Wrote %s (E-EF, divided by FD; %d samples above the occupation cut-off set to NaN).', ...
                    name, info.masked));
            else
                app.status(sprintf('Wrote %s (energy axis shifted by %.5g eV).', name, -app.Result.params.EF));
            end
        end

        function name = multiplyFD(app, T, outName, varargin)
            app.requireData();
            p = inputParser;
            p.addParameter('Overwrite', false);
            p.addParameter('Resolution', 0);
            p.parse(varargin{:});
            out = fdd_multiply_fd(app.Data, T, 'Resolution', p.Results.Resolution);
            name = app.assignOutput(outName, out, p.Results.Overwrite);
            app.status(sprintf('Wrote %s (multiplied by FD at %.4g K).', name, T));
        end

        function s = getState(app)
            h = app.Handles;
            s.dataName = app.DataName;
            s.windows = struct('x', [h.XMin.Value h.XMax.Value], 'y', [h.YMin.Value h.YMax.Value], ...
                'e', [h.EMin.Value h.EMax.Value], 'fit', [h.FitEMin.Value h.FitEMax.Value]);
            s.model = h.Model.Value;
            s.weights = h.Weights.Value;
            s.table = cell2table(h.Table.Data, 'VariableNames', {'Parameter','Unit','Start','Fixed','Fitted','StdErr'});
            s.result = app.Result;
            s.nEDC = numel(app.EDC.E);
        end

        function exportFigure(app, file)
            drawnow;
            exportapp(app.UIFigure, file);
        end
    end

    methods (Access = private)
        function build(app, vis)
            C = app.Colors;
            f = uifigure('Visible', 'off', 'Name', 'Fermi Edge Fitting (upgraded)', ...
                'Position', [60 60 1360 780], 'Tag', 'FDD_fit_app');
            app.UIFigure = f;
            f.CloseRequestFcn = @(~, ~) delete(app);
            g = uigridlayout(f, [2 3], 'ColumnWidth', {330, '1x', 410}, 'RowHeight', {'1x', 24}, ...
                'Padding', [10 6 10 6], 'ColumnSpacing', 10, 'RowSpacing', 4);

            % ---- column 1: data ----
            p1 = uipanel(g, 'Title', '1. Data and EDC window', 'FontWeight', 'bold', 'ForegroundColor', C.title);
            p1.Layout.Row = 1; p1.Layout.Column = 1;
            g1 = uigridlayout(p1, [10 4], 'RowHeight', {130, 24, 22, '1x', 22, 22, 22, 22, 26, 22}, ...
                'ColumnWidth', {70, '1x', '1x', 24}, 'Padding', [8 8 8 8], 'RowSpacing', 5);
            h.List = uilistbox(g1, 'Tag', 'DataList', 'ValueChangedFcn', @(~, ~) app.guard(@() app.selectData(app.Handles.List.Value)));
            h.List.Layout.Row = 1; h.List.Layout.Column = [1 4];
            h.Refresh = uibutton(g1, 'Text', 'Refresh list', 'Tag', 'Refresh', 'ButtonPushedFcn', @(~, ~) app.guard(@() app.refreshList()));
            h.Refresh.Layout.Row = 2; h.Refresh.Layout.Column = [1 2];
            h.PlotSlices = uibutton(g1, 'Text', 'Open in PlotSlices', 'Tag', 'OpenPlotSlices', ...
                'ButtonPushedFcn', @(~, ~) app.guard(@() app.openPlotSlices()));
            h.PlotSlices.Layout.Row = 2; h.PlotSlices.Layout.Column = [3 4];
            h.DataInfo = uilabel(g1, 'Text', 'No data selected', 'FontColor', [0.35 0.35 0.35]);
            h.DataInfo.Layout.Row = 3; h.DataInfo.Layout.Column = [1 4];
            pv = uipanel(g1, 'BorderType', 'none');   % own container keeps the axes clipped to its row
            pv.Layout.Row = 4; pv.Layout.Column = [1 4];
            gpv = uigridlayout(pv, [1 1], 'Padding', [0 0 0 0]);
            h.Preview = uiaxes(gpv, 'Tag', 'PreviewAxes');
            title(h.Preview, 'Preview (drag to set window)', 'FontWeight', 'normal');
            xlabel(h.Preview, 'x (angle / k)'); ylabel(h.Preview, 'Energy (eV)');
            [h.XMin, h.XMax] = app.rangeRow(g1, 5, 'x range', 'XMin', 'XMax');
            [h.YMin, h.YMax] = app.rangeRow(g1, 6, 'y (maps)', 'YMin', 'YMax');
            [h.EMin, h.EMax] = app.rangeRow(g1, 7, 'E range (eV)', 'EMin', 'EMax');
            h.YMin.Enable = 'off'; h.YMax.Enable = 'off';
            lab = uilabel(g1, 'Text', 'EDC y scale'); lab.Layout.Row = 8; lab.Layout.Column = 1;
            h.YScale = uidropdown(g1, 'Items', {'Linear', 'Log'}, 'ItemsData', {'linear', 'log'}, 'Tag', 'YScale', ...
                'ValueChangedFcn', @(~, ~) app.drawEDC());
            h.YScale.Layout.Row = 8; h.YScale.Layout.Column = [2 3];
            h.Extract = uibutton(g1, 'Text', 'Extract EDC', 'Tag', 'ExtractEDC', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) app.guard(@() app.extractEDC()));
            h.Extract.Layout.Row = 9; h.Extract.Layout.Column = [1 4];

            % ---- column 2: plots ----
            g2 = uigridlayout(g, [2 1], 'RowHeight', {'3x', '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 4);
            g2.Layout.Row = 1; g2.Layout.Column = 2;
            h.Axes = uiaxes(g2, 'Tag', 'EDCAxes');
            title(h.Axes, 'EDC and fit'); xlabel(h.Axes, 'Energy (eV)'); ylabel(h.Axes, 'Mean intensity (counts)');
            box(h.Axes, 'on'); grid(h.Axes, 'on');
            h.ResAxes = uiaxes(g2, 'Tag', 'ResidualAxes');
            title(h.ResAxes, 'Residual (data - fit)', 'FontWeight', 'normal');
            xlabel(h.ResAxes, 'Energy (eV)'); ylabel(h.ResAxes, 'counts'); box(h.ResAxes, 'on'); grid(h.ResAxes, 'on');

            % ---- column 3: fit and apply ----
            g3 = uigridlayout(g, [2 1], 'RowHeight', {'1x', 150}, 'Padding', [0 0 0 0], 'RowSpacing', 8);
            g3.Layout.Row = 1; g3.Layout.Column = 3;
            p2 = uipanel(g3, 'Title', '2. Fit the Fermi edge', 'FontWeight', 'bold', 'ForegroundColor', C.title);
            gp = uigridlayout(p2, [8 4], 'RowHeight', {22, 22, 22, 22, 186, 28, '1x'}, ...
                'ColumnWidth', {78, '1x', '1x', 30}, 'Padding', [8 8 8 8], 'RowSpacing', 5);
            lab = uilabel(gp, 'Text', 'Model'); lab.Layout.Row = 1; lab.Layout.Column = 1;
            m = fdd_models();
            h.Model = uidropdown(gp, 'Items', cellfun(@(a, b) [a ': ' b], {m.legacy}, {m.label}, 'UniformOutput', false), 'ItemsData', {m.key}, ...
                'Value', 'rcfd_lin_bg_T', 'Tag', 'Model', 'ValueChangedFcn', @(~, ~) app.onModelChanged());
            h.Model.Layout.Row = 1; h.Model.Layout.Column = [2 4];
            lab = uilabel(gp, 'Text', 'Weights'); lab.Layout.Row = 2; lab.Layout.Column = 1;
            h.Weights = uidropdown(gp, 'Items', {'Unweighted', 'Poisson (raw counts)'}, 'ItemsData', {'none', 'poisson'}, 'Tag', 'Weights');
            h.Weights.Layout.Row = 2; h.Weights.Layout.Column = [2 4];
            [h.FitEMin, h.FitEMax] = app.rangeRow(gp, 3, 'Fit E (eV)', 'FitEMin', 'FitEMax');
            h.FitEMin.ValueChangedFcn = @(~, ~) app.drawEDC(); h.FitEMax.ValueChangedFcn = @(~, ~) app.drawEDC();
            h.Guess = uibutton(gp, 'Text', 'Auto start values', 'Tag', 'AutoStart', ...
                'ButtonPushedFcn', @(~, ~) app.guard(@() app.autoStart()));
            h.Guess.Layout.Row = 4; h.Guess.Layout.Column = [1 2];
            h.FitButton = uibutton(gp, 'Text', 'Fit', 'Tag', 'Fit', 'FontWeight', 'bold', ...
                'BackgroundColor', [0.86 0.92 1.0], 'ButtonPushedFcn', @(~, ~) app.guard(@() app.fit()));
            h.FitButton.Layout.Row = 4; h.FitButton.Layout.Column = [3 4];
            data = [app.ParamNames(:), app.ParamUnits(:), num2cell(nan(6, 1)), num2cell(false(6, 1)), ...
                num2cell(nan(6, 1)), num2cell(nan(6, 1))];
            h.Table = uitable(gp, 'Data', data, 'Tag', 'ParamTable', ...
                'ColumnName', {'Parameter', 'Unit', 'Start', 'Fix', 'Fitted', '±1σ'}, ...
                'ColumnEditable', [false false true true false false], ...
                'ColumnWidth', {80, 66, 62, 34, 74, 62}, 'RowName', {});
            h.Table.Layout.Row = 5; h.Table.Layout.Column = [1 4];
            h.Summary = uitextarea(gp, 'Editable', 'off', 'Tag', 'Summary', 'FontName', 'monospaced', ...
                'Value', {'No fit yet.'});
            h.Summary.Layout.Row = [6 7]; h.Summary.Layout.Column = [1 4];

            p3 = uipanel(g3, 'Title', '3. Apply to a copy of the data', 'FontWeight', 'bold', 'ForegroundColor', C.title);
            ga = uigridlayout(p3, [4 3], 'RowHeight', {22, 22, 24, 24}, 'ColumnWidth', {120, '1x', '1x'}, ...
                'Padding', [8 8 8 8], 'RowSpacing', 5);
            lab = uilabel(ga, 'Text', 'Output suffix'); lab.Layout.Row = 1; lab.Layout.Column = 1;
            h.Suffix = uieditfield(ga, 'text', 'Value', '_FDD', 'Tag', 'Suffix');
            h.Suffix.Layout.Row = 1; h.Suffix.Layout.Column = [2 3];
            lab = uilabel(ga, 'Text', 'Min. occupation'); lab.Layout.Row = 2; lab.Layout.Column = 1;
            h.MinOcc = uieditfield(ga, 'numeric', 'Value', 0.05, 'Limits', [0 0.49], 'Tag', 'MinOccupation', ...
                'Tooltip', 'Divided samples with FD occupation below this value become NaN');
            h.MinOcc.Layout.Row = 2; h.MinOcc.Layout.Column = 2;
            h.Offset = uibutton(ga, 'Text', 'Shift to E−E_F', 'Tag', 'Offset', ...
                'ButtonPushedFcn', @(~, ~) app.guard(@() app.applyCorrection('offset', app.outputName('_EF'))));
            h.Offset.Layout.Row = 3; h.Offset.Layout.Column = [1 2];
            h.Renorm = uibutton(ga, 'Text', 'Shift + divide by FD', 'Tag', 'OffsetRenormalise', ...
                'ButtonPushedFcn', @(~, ~) app.guard(@() app.applyCorrection('renormalise', app.outputName(app.Handles.Suffix.Value))));
            h.Renorm.Layout.Row = 3; h.Renorm.Layout.Column = 3;
            h.MultT = uieditfield(ga, 'numeric', 'Value', 10, 'Limits', [0.01 5000], 'Tag', 'MultiplyT', ...
                'ValueDisplayFormat', '%.4g K');
            h.MultT.Layout.Row = 4; h.MultT.Layout.Column = 1;
            h.Mult = uibutton(ga, 'Text', 'Multiply by FD (E−E_F axis)', 'Tag', 'MultiplyFD', ...
                'ButtonPushedFcn', @(~, ~) app.guard(@() app.multiplyFD(app.Handles.MultT.Value, app.outputName('_xFDD'))));
            h.Mult.Layout.Row = 4; h.Mult.Layout.Column = [2 3];

            h.Status = uilabel(g, 'Text', 'Ready.', 'Tag', 'Status', 'FontColor', [0.25 0.25 0.25]);
            h.Status.Layout.Row = 2; h.Status.Layout.Column = [1 3];

            app.Handles = h;
            f.WindowButtonMotionFcn = @(~, ~) app.onDragMove();
            f.WindowButtonUpFcn = @(~, ~) app.onDragEnd();
            app.onModelChanged();
            f.Visible = vis;
        end

        function [a, b] = rangeRow(~, parent, row, label, tagA, tagB)
            lab = uilabel(parent, 'Text', label);
            lab.Layout.Row = row; lab.Layout.Column = 1;
            a = uieditfield(parent, 'numeric', 'Tag', tagA, 'ValueDisplayFormat', '%.5g');
            a.Layout.Row = row; a.Layout.Column = 2;
            b = uieditfield(parent, 'numeric', 'Tag', tagB, 'ValueDisplayFormat', '%.5g');
            b.Layout.Row = row; b.Layout.Column = 3;
        end

        function onModelChanged(app)
            % The preset decides which parameters are free; the Fix column is a
            % per-parameter user override and is not changed here.
            m = fdd_models(app.Handles.Model.Value);
            if ~m.free(4)
                app.status('This model holds T at its Start value: enter the measured sample temperature (K).');
            else
                app.status(sprintf('Model: %s.', m.label));
            end
        end

        function autoStart(app)
            if isempty(app.EDC.E), error('FDD:NoEDC', 'Extract an EDC first.'); end
            h = app.Handles;
            keep = app.EDC.E >= h.FitEMin.Value & app.EDC.E <= h.FitEMax.Value;
            Tcur = h.Table.Data{4, 3};
            if isempty(Tcur) || ~isfinite(Tcur) || Tcur <= 0, Tcur = []; end
            p0 = fdd_initial_guess(app.EDC.E(keep), app.EDC.I(keep), Tcur);
            for r = 1:6
                h.Table.Data{r, 3} = p0.(app.ParamNames{r});
            end
            app.status('Start values estimated from the EDC (edge position, 10-90 % width, plateaus).');
        end

        function drawPreview(app)
            ax = app.Handles.Preview;
            cla(ax);
            [nd, eName] = fdd_energy_axis(app.Data);
            v = double(app.Data.value);
            if nd == 3
                v = squeeze(mean(v, 2, 'omitnan'));
            end
            im = imagesc(ax, double(app.Data.x), double(app.Data.(eName)), v');
            set(ax, 'YDir', 'normal');
            axis(ax, 'tight');
            colormap(ax, flipud(gray));
            im.ButtonDownFcn = @(~, ~) app.onDragStart();
            app.ROIRect = gobjects(0);
            app.drawROI();
        end

        function drawROI(app)
            if isempty(app.Data), return; end
            h = app.Handles; ax = h.Preview;
            pos = [min(h.XMin.Value, h.XMax.Value), min(h.EMin.Value, h.EMax.Value), ...
                abs(h.XMax.Value - h.XMin.Value), abs(h.EMax.Value - h.EMin.Value)];
            pos(3:4) = max(pos(3:4), eps);
            if isempty(app.ROIRect) || ~isvalid(app.ROIRect)
                app.ROIRect = rectangle(ax, 'Position', pos, 'EdgeColor', app.Colors.window, ...
                    'LineWidth', 1.5, 'LineStyle', '--', 'Tag', 'FDD_ROI', 'HitTest', 'off');
            else
                app.ROIRect.Position = pos;
            end
        end

        function onDragStart(app)
            cp = app.Handles.Preview.CurrentPoint;
            app.DragStart = cp(1, 1:2);
        end

        function onDragMove(app)
            if isempty(app.DragStart), return; end
            cp = app.Handles.Preview.CurrentPoint;
            app.setWindows('XRange', [app.DragStart(1) cp(1, 1)], 'ERange', [app.DragStart(2) cp(1, 2)]);
        end

        function onDragEnd(app)
            if isempty(app.DragStart), return; end
            app.DragStart = [];
            app.guard(@() app.extractEDC());
        end

        function drawEDC(app)
            h = app.Handles; ax = h.Axes; C = app.Colors;
            cla(ax); cla(h.ResAxes);
            if isempty(app.EDC.E), return; end
            hold(ax, 'on');
            E = app.EDC.E; I = app.EDC.I;
            plot(ax, E, I, '.', 'Color', C.data, 'MarkerSize', 8, 'DisplayName', 'EDC');
            inWin = E >= h.FitEMin.Value & E <= h.FitEMax.Value;
            plot(ax, E(inWin), I(inWin), 'o', 'Color', C.window, 'MarkerSize', 4, 'DisplayName', 'Fit window');
            R = app.Result;
            if ~isempty(R)
                Ef = linspace(min(E), max(E), 800)';
                plot(ax, Ef, fdd_model(Ef, R.params), '-', 'Color', C.fit, 'LineWidth', 2, 'DisplayName', 'Fit');
                xline(ax, R.params.EF, '-.', 'Color', C.ef, 'LineWidth', 1.5, ...
                    'Label', sprintf('E_F = %.4f eV', R.params.EF), 'DisplayName', 'E_F');
                plot(h.ResAxes, R.E, R.residual, '.', 'Color', C.fit);
                yline(h.ResAxes, 0, 'k-');
                xlim(h.ResAxes, [min(E) max(E)]);
            end
            hold(ax, 'off');
            ax.YScale = h.YScale.Value;
            xlim(ax, [min(E) max(E)]);
            legend(ax, 'Location', 'southwest');
            if ~isempty(app.DataName)
                title(ax, sprintf('EDC and fit: %s', app.DataName), 'Interpreter', 'none');
            end
        end

        function showSummary(app)
            R = app.Result; P = R.params; S = R.stderr;
            c = fdd_constants();
            lines = {
                sprintf('Model      %s (%d points, %d free)', R.model, numel(R.E), nnz(R.free))
                sprintf('E_F        %.5f ± %.5f eV', P.EF, S.EF)
                ifelse(R.free(4), sprintf('T          %.3g ± %.2g K', P.Temperature, S.Temperature), ...
                    sprintf('T          %.4g K (held)', P.Temperature))
                sprintf('Resolution %.2f ± %.2f meV FWHM', 1e3 * P.Resolution, 1e3 * S.Resolution)
                sprintf('4.4 kB·T   %.2f meV (thermal 10-90 %% width)', 1e3 * 4.394 * c.kB * P.Temperature)
                sprintf('chi2/dof   %.4g    R^2 %.5f', R.chi2red, R.rsquared)
                sprintf('Converged  %s after %d iterations', ifelse(R.converged, 'yes', 'NO'), R.iterations)
                };
            if ~isempty(R.warnings)
                lines = [lines; strcat({'WARNING: '}, R.warnings(:))];
            end
            app.Handles.Summary.Value = lines;
            app.status(sprintf('Fit done: E_F = %.5f ± %.5f eV.', P.EF, S.EF));
        end

        function clearFit(app)
            % A new dataset or EDC invalidates the previous fit: clear the
            % result and its Fitted/1-sigma columns and summary so stale
            % numbers are never shown next to new data.
            app.Result = [];
            app.Handles.Table.Data(:, 5:6) = {NaN};
            app.Handles.Summary.Value = {'No fit yet.'};
        end

        function name = outputName(app, suffix)
            name = [app.DataName suffix];
        end

        function name = assignOutput(app, name, value, overwrite)
            if ~isvarname(name)
                error('FDD:InvalidName', '"%s" is not a valid MATLAB variable name.', name);
            end
            if strcmp(name, app.DataName)
                error('FDD:WouldOverwriteSource', 'The output name equals the source variable; choose another suffix.');
            end
            exists = evalin('base', sprintf('exist(''%s'', ''var'')', name));
            if exists && ~overwrite
                if strcmp(app.UIFigure.Visible, 'on') && app.isInteractiveCall()
                    sel = uiconfirm(app.UIFigure, sprintf('Overwrite base-workspace variable %s?', name), ...
                        'Overwrite?', 'Options', {'Overwrite', 'Cancel'}, 'DefaultOption', 2);
                    if ~strcmp(sel, 'Overwrite')
                        error('FDD:Cancelled', 'Cancelled: %s was not overwritten.', name);
                    end
                else
                    error('FDD:VariableExists', 'Variable %s exists; pass ''Overwrite'', true to replace it.', name);
                end
            end
            assignin('base', name, value);
            app.refreshList();
        end

        function tf = isInteractiveCall(~)
            st = dbstack;
            tf = any(contains({st.name}, 'guard'));
        end

        function openPlotSlices(app)
            app.requireData();
            if exist('PlotSlices', 'file') ~= 2 && exist('PlotSlices', 'class') ~= 8
                error('FDD:MissingDependency', 'PlotSlices (yulinARPES) is not on the MATLAB path.');
            end
            [nd, ~] = fdd_energy_axis(app.Data);
            dirs = 'xz';
            PlotSlices(app.DataName, dirs(nd - 1));
        end

        function guard(app, fcn)
            try
                fcn();
            catch err
                app.status(['Error: ' err.message]);
                if strcmp(app.UIFigure.Visible, 'on')
                    uialert(app.UIFigure, err.message, 'FDD', 'Icon', 'error');
                end
            end
        end

        function requireData(app)
            if isempty(app.Data)
                error('FDD:NoData', 'Select a cut or map first.');
            end
        end

        function requireFit(app)
            app.requireData();
            if isempty(app.Result)
                error('FDD:NoFit', 'Run a fit first.');
            end
        end

        function row = paramRow(app, name)
            row = find(strcmpi(app.ParamNames, name), 1);
            if isempty(row)
                error('FDD:UnknownParameter', 'Unknown parameter "%s".', name);
            end
        end

        function status(app, msg)
            app.Handles.Status.Text = msg;
        end
    end
end

function out = ifelse(c, a, b)
if c, out = a; else, out = b; end
end
