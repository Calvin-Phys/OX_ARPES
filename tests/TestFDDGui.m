function tests = TestFDDGui
%TESTFDDGUI  Behavioural tests of FDD_fit_app through its public API.
%   Uses isolated base-workspace variables prefixed fddtest_ and removes
%   them afterwards. The app is built hidden; no user figures are touched.
tests = functiontests(localfunctions);
end

function setupOnce(tc)
here = fileparts(mfilename('fullpath'));
root = fileparts(here);
tc.TestData.oldPath = addpath(fullfile(root, 'GUI', 'FDD'), fullfile(root, 'DataType'), here);
x = -12:0.25:12; y = -3:1:3;
truth = struct('Amplitude', 900, 'Slope', -600, 'EF', 16.8317, 'Temperature', 30, ...
    'Resolution', 0.015, 'Background', 35);
[E, ~] = fdd_synthetic('EF', truth.EF, 'Noise', 'none', 'Step', 0.002);
edc = fdd_model(E', truth);
rng(11);
cut = struct('x', x, 'y', E', 'value', repmat(edc, numel(x), 1));
cut.value = cut.value + sqrt(cut.value) .* randn(size(cut.value));
map = struct('x', x, 'y', y, 'z', E', 'value', repmat(reshape(edc, 1, 1, []), numel(x), numel(y)));
assignin('base', 'fddtest_cut', cut);
assignin('base', 'fddtest_map', map);
assignin('base', 'fddtest_notdata', magic(3));
tc.TestData.truth = truth;
tc.TestData.cut = cut;
end

function teardownOnce(tc)
evalin('base', 'clear fddtest_*');
path(tc.TestData.oldPath);
end

function setup(tc)
tc.TestData.app = FDD_fit_app('Visible', 'off');
end

function teardown(tc)
delete(tc.TestData.app);
end

function testListFiltersDataVariables(tc)
app = tc.TestData.app;
names = app.refreshList();
tc.verifyTrue(all(ismember({'fddtest_cut', 'fddtest_map'}, names)));
tc.verifyFalse(ismember('fddtest_notdata', names));
end

function testCutWorkflowRecoversParameters(tc)
app = tc.TestData.app; t = tc.TestData.truth;
app.selectData('fddtest_cut');
app.setWindows('XRange', [-6 6]);
app.extractEDC();
app.setModel('Mod 6');
app.setStart('Temperature', 30);
R = app.fit();
tc.verifyEqual(R.params.EF, t.EF, 'AbsTol', 5e-4);
tc.verifyEqual(R.params.Resolution, t.Resolution, 'RelTol', 0.1);
tc.verifyEqual(R.params.Temperature, 30);
s = app.getState();
tc.verifyEqual(s.table.Fitted(3), R.params.EF);
tc.verifyEqual(s.windows.x, [-6 6]);
s2 = app.getState();                                % read does not reset
tc.verifyEqual(s2.result.params, R.params);
summary = findobj(app.UIFigure, 'Tag', 'Summary');
tc.verifyTrue(any(contains(summary.Value, 'E_F')));
end

function testApplyWritesCopiesAndRefusesOverwrite(tc)
app = tc.TestData.app;
app.selectData('fddtest_cut');
app.setModel('rcfd_lin_bg_T'); app.setStart('Temperature', 30);
app.fit();
name = app.applyCorrection('renormalise', 'fddtest_cut_FDD');
tc.verifyEqual(name, 'fddtest_cut_FDD');
out = evalin('base', 'fddtest_cut_FDD');
tc.verifyEqual(out.y, tc.TestData.cut.y - app.Result.params.EF, 'AbsTol', 1e-12);
tc.verifyEqual(evalin('base', 'fddtest_cut'), tc.TestData.cut);  % source untouched
tc.verifyError(@() app.applyCorrection('offset', 'fddtest_cut_FDD'), 'FDD:VariableExists');
app.applyCorrection('offset', 'fddtest_cut_FDD', 'Overwrite', true);
tc.verifyEqual(evalin('base', 'fddtest_cut_FDD.value'), tc.TestData.cut.value);
tc.verifyError(@() app.applyCorrection('offset', 'fddtest_cut'), 'FDD:WouldOverwriteSource');
app.multiplyFD(20, 'fddtest_cut_xFDD');
tc.verifyTrue(evalin('base', 'exist(''fddtest_cut_xFDD'',''var'')') == 1);
evalin('base', 'clear fddtest_cut_FDD fddtest_cut_xFDD');
end

function testMapWorkflowUsesYWindow(tc)
app = tc.TestData.app; t = tc.TestData.truth;
app.selectData('fddtest_map');
s = app.getState();
tc.verifyEqual(s.windows.y, [-3 3]);
app.setWindows('YRange', [-1 1]);
app.extractEDC();
app.setModel('Mod 6'); app.setStart('Temperature', 30);
R = app.fit();
tc.verifyEqual(R.params.EF, t.EF, 'AbsTol', 1e-4);
end

function testErrorsBeforeDataOrFit(tc)
app = tc.TestData.app;
tc.verifyError(@() app.fit(), 'FDD:NoEDC');
tc.verifyError(@() app.applyCorrection('offset', 'x_out'), 'FDD:NoData');
tc.verifyError(@() app.selectData('fddtest_missing'), 'FDD:UnknownVariable');
tc.verifyError(@() app.setModel('Mod 7'), 'FDD:UnknownModel');
app.selectData('fddtest_cut');
tc.verifyError(@() app.applyCorrection('offset', 'x_out'), 'FDD:NoFit');
tc.verifyError(@() app.setStart('Temperature', NaN), 'FDD:InvalidParameter');
end

function testNewEDCClearsStaleFit(tc)
% Added in the second review: a new EDC or dataset must not show the old fit.
app = tc.TestData.app;
app.selectData('fddtest_cut');
app.setModel('Mod 6'); app.setStart('Temperature', 30);
app.fit();
s = app.getState();
tc.verifyTrue(all(isfinite(s.table.Fitted([1 3 5]))));
app.setWindows('XRange', [-3 3]);
app.extractEDC();
s = app.getState();
tc.verifyEmpty(s.result);
tc.verifyTrue(all(isnan(s.table.Fitted)) && all(isnan(s.table.StdErr)));
summary = findobj(app.UIFigure, 'Tag', 'Summary');
tc.verifyEqual(summary.Value, {'No fit yet.'});
tc.verifyEqual(s.table.Start(4), 30);                      % start values are kept
tc.verifyError(@() app.applyCorrection('offset', 'x_out'), 'FDD:NoFit');
tc.verifyError(@() app.selectData('a''); disp(1); %'), 'FDD:UnknownVariable');  % not evaluated
end

function testInfoTemperatureFillsHeldT(tc)
% GUI feedback 23 Nov: a finite data.info.temperature becomes the held T.
app = tc.TestData.app;
cut = tc.TestData.cut; cut.info = struct('temperature', 30);
assignin('base', 'fddtest_cutT', cut);
nan2 = cut; nan2.info.temperature = NaN;
assignin('base', 'fddtest_cutTnan', nan2);
cleanup = onCleanup(@() evalin('base', 'clear fddtest_cutT fddtest_cutTnan fddtest_oxcut'));
app.setModel('Mod 6');
app.setStart('Temperature', 12);
app.selectData('fddtest_cut');                         % no info: typed value kept
s = app.getState();
tc.verifyEqual(s.table.Start(4), 12);
tc.verifyEqual(s.temperatureSource, '');
app.selectData('fddtest_cutT');                        % info.temperature -> Start T
s = app.getState();
tc.verifyEqual(s.table.Start(4), 30);
tc.verifyEqual(s.temperatureSource, 'info.temperature');
tc.verifyEqual(findobj(app.UIFigure, 'Tag', 'MultiplyT').Value, 30);
R = app.fit();
tc.verifyFalse(R.free(4));
tc.verifyEqual(R.params.Temperature, 30);
app.setStart('Temperature', 25);                       % user edit survives a refit
app.extractEDC(); app.fit();
tc.verifyEqual(app.Result.params.Temperature, 25);
app.selectData('fddtest_cutTnan');                     % NaN is ignored
tc.verifyEqual(app.getState().table.Start(4), 25);
ox = OxA_CUT(cut.x, cut.y, cut.value);                 % OX object with info property
ox.info.temperature = [6.5 7.5];                       % logged readings -> mean
assignin('base', 'fddtest_oxcut', ox);
app.selectData('fddtest_oxcut');
tc.verifyEqual(app.getState().table.Start(4), 7, 'AbsTol', 1e-12);
tc.verifyEmpty(fdd_info_temperature(struct('info', struct('temperature', -1))));
tc.verifyEmpty(fdd_info_temperature(struct('info', struct('temperature', 'warm'))));
tc.verifyEmpty(fdd_info_temperature(magic(3)));
clear cleanup
end

function testFitStatusIndicator(tc)
% GUI feedback 23 Nov: the status lamp shows Idle / Done / Failed and the Fit
% button is enabled again after the fit.
app = tc.TestData.app;
lamp = findobj(app.UIFigure, 'Tag', 'FitStatusLamp');
word = findobj(app.UIFigure, 'Tag', 'FitStatus');
btn = findobj(app.UIFigure, 'Tag', 'Fit');
tc.verifyEqual(app.getState().fitStatus, 'Idle');
tc.verifyEqual(word.Text, 'Idle');
app.selectData('fddtest_cut');
app.setModel('Mod 6'); app.setStart('Temperature', 30);
app.fit();
tc.verifyEqual(app.getState().fitStatus, 'Done');
tc.verifyEqual(word.Text, 'Done');
tc.verifyEqual(lamp.Color, [0.20 0.70 0.25], 'AbsTol', 1e-12);
tc.verifyEqual(char(btn.Enable), 'on');
app.setFitWindow([16.0 16.001]);                       % too few points -> fit fails
tc.verifyError(@() app.fit(), 'FDD:TooFewPoints');
tc.verifyEqual(word.Text, 'Failed');
tc.verifyEqual(char(btn.Enable), 'on');
tc.verifyEqual(char(app.UIFigure.Pointer), 'arrow');
app.extractEDC();                                      % new EDC invalidates -> Idle
tc.verifyEqual(word.Text, 'Idle');
end

function testCompactWindowSize(tc)
% GUI feedback 23 Nov: window is ~80 % of the former 1360 x 780.
pos = tc.TestData.app.UIFigure.Position;
tc.verifyEqual(pos(3:4), [1088 624]);
end
