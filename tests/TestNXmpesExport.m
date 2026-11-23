classdef TestNXmpesExport < matlab.unittest.TestCase
    properties
        Prefix
    end
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            previous = path;
            addpath(fullfile(root,'GUI'));
            addpath(fullfile(root,'DataType'));
            addpath(genpath(fullfile(root,'DataLoader')));
            testCase.addTeardown(@() path(previous));
        end
    end
    methods (TestMethodSetup)
        function isolateWorkspace(testCase)
            [~,testCase.Prefix] = fileparts(tempname);
            testCase.addTeardown(@() clear_prefix(testCase.Prefix));
        end
    end
    methods (Test)
        function completeListRefreshAndIncompatibleSelection(testCase)
            source = [testCase.Prefix '_cut'];
            other = [testCase.Prefix '_number'];
            assignin('base',source,OxA_CUT([0 1],[4 5],magic(2)));
            assignin('base',other,42);
            before = evalin('base','who');
            fig = testCase.openWindow();
            list = findobj(fig,'Tag','NXmpesVariables');
            testCase.verifyEqual(sort(list.Data(:,2)),sort(before(:)));
            testCase.tick(list,source,true);
            testCase.tick(list,other,true);
            row = strcmp(list.Data(:,2),other);
            testCase.verifyFalse(list.Data{row,1});
            status = findobj(fig,'Tag','NXmpesStatus');
            testCase.verifySubstring(status.Text,'not a scalar OX dataset');
            added = [testCase.Prefix '_new'];
            assignin('base',added,'new variable');
            refresh = findobj(fig,'Tag','NXmpesRefresh');
            refresh.ButtonPushedFcn(refresh,[]);
            testCase.verifyTrue(ismember(added,list.Data(:,2)));
            row = strcmp(list.Data(:,2),source);
            testCase.verifyTrue(list.Data{row,1});
        end
        function saveButtonExportsCheckedVariablesOnly(testCase)
            cutName = [testCase.Prefix '_cut'];
            mapName = [testCase.Prefix '_map'];
            skipName = [testCase.Prefix '_skip'];
            cut = OxA_CUT([-1 0 2],[10 12],single(reshape(1:6,[3 2])));
            map = OxA_MAP([0 1],[-1 0 1],[8 9],reshape(1:12,[2 3 2]));
            assignin('base',cutName,cut);
            assignin('base',mapName,map);
            assignin('base',skipName,cut);
            fig = testCase.openWindow();
            list = findobj(fig,'Tag','NXmpesVariables');
            testCase.tick(list,cutName,true);
            testCase.tick(list,mapName,true);
            file = [tempname '.nxs'];
            testCase.addTeardown(@() delete_file(file));
            destination = findobj(fig,'Tag','NXmpesPath');
            destination.Value = file(1:end-4); % Missing extension is added.
            saveButton = findobj(fig,'Tag','NXmpesSave');
            saveButton.ButtonPushedFcn(saveButton,[]);
            testCase.verifyTrue(isfile(file));
            loaded = load_nxmpes(file);
            testCase.verifyEqual(sort(fieldnames(loaded)),sort({cutName;mapName}));
            testCase.verifyEqual(loaded.(cutName),cut);
            testCase.verifyEqual(loaded.(mapName),map);
            testCase.verifyEqual(evalin('base',cutName),cut);
            testCase.verifyEqual(evalin('base',mapName),map);
            report = getappdata(fig,'LastExportReport');
            testCase.verifyNumElements(report.entries,2);
            status = findobj(fig,'Tag','NXmpesStatus');
            testCase.verifySubstring(status.Text,'Saved 2 dataset(s)');
            testCase.verifyEqual(saveButton.Enable,matlab.lang.OnOffSwitchState.on);
        end
        function staleAndFailedExportsShowErrorsWithoutFiles(testCase)
            source = [testCase.Prefix '_cut'];
            assignin('base',source,OxA_CUT([0 1],[4 5],magic(2)));
            fig = testCase.openWindow();
            list = findobj(fig,'Tag','NXmpesVariables');
            testCase.tick(list,source,true);
            file = [tempname '.nxs'];
            testCase.addTeardown(@() delete_file(file));
            destination = findobj(fig,'Tag','NXmpesPath');
            destination.Value = file;
            saveButton = findobj(fig,'Tag','NXmpesSave');
            evalin('base',['clear ' source]);
            saveButton.ButtonPushedFcn(saveButton,[]);
            status = findobj(fig,'Tag','NXmpesStatus');
            testCase.verifySubstring(status.Text,'no longer available');
            testCase.verifyFalse(isfile(file));
            bad = OxA_CUT([0 1],[4 5],magic(2));
            bad.info.unsupported = @sin;
            assignin('base',source,bad);
            saveButton.ButtonPushedFcn(saveButton,[]);
            testCase.verifySubstring(status.Text,'not supported');
            testCase.verifyFalse(isfile(file));
            testCase.verifyEmpty(getappdata(fig,'LastExportReport'));
            testCase.verifyEqual(saveButton.Enable,matlab.lang.OnOffSwitchState.on);
        end
    end
    methods (Access=private)
        function fig = openWindow(testCase)
            fig = export_nxmpes_UI();
            testCase.addTeardown(@() delete_figure(fig));
            fig.Visible = 'off';
        end
        function tick(~,list,name,value)
            row = find(strcmp(list.Data(:,2),name));
            list.Data{row,1} = value;
            list.CellEditCallback(list,struct('Indices',[row 1],'NewData',value));
        end
    end
end

function clear_prefix(prefix)
    names = evalin('base','who');
    names = names(startsWith(names,prefix));
    if ~isempty(names), evalin('base',['clear ' strjoin(names(:).',' ')]); end
end

function delete_figure(fig)
    if isvalid(fig), delete(fig); end
end

function delete_file(file)
    if isfile(file), delete(file); end
end
