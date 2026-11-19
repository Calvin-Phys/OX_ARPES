classdef TestDataProcess < matlab.unittest.TestCase
    properties
        Prefix
    end
    methods (TestClassSetup)
        function setupPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            previous = path;
            addpath(fullfile(root,'GUI'),fullfile(root,'DataType'));
            testCase.addTeardown(@() path(previous));
        end
    end
    methods (TestMethodSetup)
        function isolatedWorkspace(testCase)
            [~,token] = fileparts(tempname);
            testCase.Prefix = matlab.lang.makeValidName(['oxaDPTest_' token]);
            prefix = testCase.Prefix;
            testCase.addTeardown(@() TestDataProcess.clearFixtures(prefix));
        end
    end
    methods (Test)
        function blockReductionMeansCoordinatesAndTails(testCase)
            values = reshape(1:35,5,7);
            data = OxArpes_2D_Data([10 8 6 4 2],1:7,values);
            data.info = struct('marker','retained');
            [out,info] = ox_data_process(data,'reduce',struct('Factors',[2 3 NaN]));
            expected = zeros(2,2);
            for ix = 1:2
                for iy = 1:2
                    expected(ix,iy) = mean(values((ix-1)*2+(1:2),(iy-1)*3+(1:3)),'all');
                end
            end
            testCase.verifyEqual(out{1}.value,expected,'AbsTol',1e-12);
            testCase.verifyEqual(out{1}.x,[9 5]);
            testCase.verifyEqual(out{1}.y,[2 5]);
            testCase.verifyEqual(out{1}.info,data.info);
            testCase.verifyEqual(info.DroppedSamples,[1 1]);
            testCase.verifyEqual(info.Options.Factors,[2 3]);
            testCase.verifyEqual(info.Suffixes,{'_rd'});
            testCase.verifyEqual(data.value,values);
        end

        function blockReduction3DAndSingleton(testCase)
            values = reshape(1:315,5,7,9);
            data = OxArpes_3D_Data(1:5,1:7,9:-1:1,values);
            [out,info] = ox_data_process(data,'reduce',struct('Factors',[2;3;4]));
            expected = zeros(2,2,2);
            for ix = 1:2
                for iy = 1:2
                    for iz = 1:2
                        expected(ix,iy,iz) = mean(values((ix-1)*2+(1:2),(iy-1)*3+(1:3),(iz-1)*4+(1:4)),'all');
                    end
                end
            end
            testCase.verifyEqual(out{1}.value,expected,'AbsTol',1e-12);
            testCase.verifyEqual(out{1}.z,[7.5 3.5]);
            testCase.verifyEqual(info.DroppedSamples,[1 1 1]);
            singleton = OxArpes_3D_Data(1:4,1:6,2,ones(4,6));
            out = ox_data_process(singleton,'reduce',struct('Factors',[2 3 1]));
            testCase.verifyClass(out{1},'OxArpes_3D_Data');
            testCase.verifyEqual(out{1}.value,ones(2));
            out = ox_data_process(singleton,'reduce');
            testCase.verifyEqual(out{1},singleton);
            for invalid = {[0 1 1],[1.5 1 1],[1 NaN 1],[5 1 1],[1 1],[1 1 Inf]}
                testCase.verifyError(@() ox_data_process(singleton,'reduce',struct('Factors',invalid{1})), ...
                    'OxArpes:ProcessFactors');
            end
        end

        function agentFacadeAndCompactReductionCallback(testCase)
            source = [testCase.Prefix '_input'];
            data = OxArpes_2D_Data(1:5,1:7,reshape(1:35,5,7));
            assignin('base',source,data);
            app = OxArpes_DataProcess;
            testCase.addTeardown(@() delete(app));
            state = ox_data_process_agent('select',struct('App',app,'SourceName',source));
            testCase.verifyEqual(state.Selected,source);
            testCase.verifyEqual(state.ColumnWidths,[250,repmat(407*2/3,1,3)],'AbsTol',1e-10);
            testCase.verifyEqual(app.BlockZEditField.Enable,matlab.lang.OnOffSwitchState.off);
            app.BlockXEditField.Value = 2; app.BlockYEditField.Value = 3;
            app.EditField.Value = '2';
            before = ox_data_process_agent('read',struct('App',app));
            raised = ox_data_process_agent('open',struct('App',app));
            testCase.verifyEqual(raised.Parameters,before.Parameters);
            listed = ox_data_process_agent('list');
            testCase.verifyTrue(ismember(string(source),listed.Name));
            testCase.press(app.BlockReduceButton);
            testCase.verifyEqual(evalin('base',[source '_rd']).value,[6.5 21.5;8.5 23.5]);
            report = ox_data_process_agent('process',struct('App',app,'Operation','reduce', ...
                'Parameters',before.Parameters.reduce));
            testCase.verifyEqual(report.OutputNames,{[source '_rd_2']});
            state = ox_data_process_agent('refresh',struct('App',app));
            testCase.verifyEqual(state.Selected,source);
            testCase.verifyEqual(state.Parameters.truncate.Bounds{1,1},'2');
            state = ox_data_process_agent('resetcrop',struct('App',app));
            testCase.verifyEqual(state.Parameters.truncate.Bounds{1,1},'Min');
            testCase.verifyError(@() ox_data_process_agent('list',struct('Typo',1)),'OxArpes:ProcessOptions');
            testCase.verifyError(@() ox_data_process_agent('select',struct('App',app,'SourceName','missing-data')), ...
                'OxArpes:ProcessSelection');
            testCase.verifyEqual(evalin('base',source),data);
        end

        function cropDescendingReversedAndInactiveZ(testCase)
            data = OxArpes_2D_Data([8 4 1 -2],[10 20 40],reshape(1:12,4,3));
            opts = struct('Bounds',{{-1,5;39,11;'invalid','ignored'}});
            [out,info] = ox_data_process(data,'truncate',opts);
            testCase.verifyEqual(out{1}.x,[4 1 -2]);
            testCase.verifyEqual(out{1}.y,[10 20 40]);
            testCase.verifyEqual(out{1}.value,data.value(2:4,:));
            testCase.verifyEqual(info.Indices,{[2 4],[1 3]});
            testCase.verifyEqual(data.x,[8 4 1 -2]);
            opts.Bounds = {'min','MAX';-100,1000};
            out = ox_data_process(data,'truncate',opts);
            testCase.verifyEqual(out{1}.value,data.value);
        end

        function cropIndexValidationAndExpressionRejection(testCase)
            data = OxArpes_2D_Data(1:4,1:3,ones(4,3));
            opts = struct('Bounds',{{4,2;1,3}},'Scale','indices');
            out = ox_data_process(data,'truncate',opts);
            testCase.verifySize(out{1}.value,[3 3]);
            for invalid = {0,1.5,5,NaN,Inf,'1+1','[1 2]',1i}
                opts.Bounds{1,1} = invalid{1};
                testCase.verifyError(@() ox_data_process(data,'truncate',opts),'OxArpes:ProcessBounds');
            end
        end

        function normaliseMeanPeakAndDescendingRegion(testCase)
            data = OxArpes_2D_Data([3 1 -1],[2 4],[2 4;4 8;6 12]);
            meanOut = ox_data_process(data,'normalise');
            peakOut = ox_data_process(data,'normalise',struct('Peak',true));
            testCase.verifyEqual(meanOut{1}.value,[0.5 0.5;1 1;1.5 1.5],'AbsTol',1e-12);
            testCase.verifyEqual(peakOut{1}.value,[1/3 1/3;2/3 2/3;1 1],'AbsTol',1e-12);
            opts = struct('Direction','X','Bounds',{{-1,1}});
            out = ox_data_process(data,'normalise',opts);
            testCase.verifyEqual(out{1}.value,[0.4 0.4;0.8 0.8;1.2 1.2],'AbsTol',1e-12);
        end

        function normalisePlanesAndSingleton3D(testCase)
            values = reshape(1:24,[2 3 4]);
            data = OxArpes_3D_Data(1:2,1:3,1:4,values);
            directions = {'XY','XZ','YZ'};
            for k = 1:3
                direction = directions{k};
                opts = struct('Direction',direction,'Bounds',{{'ignored','ignored'}},'Scale','ignored');
                out = ox_data_process(data,'normalise',opts);
                dims = find(ismember('XYZ',direction));
                testCase.verifyEqual(mean(out{1}.value,dims),ones(size(mean(values,dims))),'AbsTol',1e-12);
            end
            singleton = OxArpes_3D_Data(1,1:3,1,reshape([2 4 6],[1 3 1]));
            out = ox_data_process(singleton,'normalise',struct('Direction','Z'));
            testCase.verifyEqual(out{1}.value,ones(1,3));
            testCase.verifyClass(out{1},'OxArpes_3D_Data');
        end

        function rejectsInvalidAndZeroDivisors(testCase)
            data = OxArpes_2D_Data(1:2,1:2,[1 0;-1 0]);
            testCase.verifyError(@() ox_data_process(data,'normalise'),'OxArpes:ProcessDivisor');
            testCase.verifyError(@() ox_data_process(data,'smooth',struct('Typo',3)),'OxArpes:ProcessOptions');
            testCase.verifyError(@() ox_data_process(data,'normalise',struct('Direction','XY')),'OxArpes:ProcessDimension');
            testCase.verifyError(@() ox_data_process(data,'zsmooth'),'OxArpes:ProcessDimension');
            testCase.verifyError(@() ox_data_process(zeros(2),'truncate'),'OxArpes:ProcessData');
        end

        function gaussianConstantAndSliceIsolation(testCase)
            data = OxArpes_3D_Data(1:2,1:20,1:21,cat(1,7*ones(1,20,21),11*ones(1,20,21)));
            [out,info] = ox_data_process(data,'smooth',struct('Sigma',[1;1.5]));
            testCase.verifyEqual(out{1}.value,data.value,'AbsTol',1e-11);
            testCase.verifyEqual(info.Axes,'YZ');
            testCase.verifyEqual(info.Options.Sigma,[1 1.5]);
            out = ox_data_process(data,'zsmooth',struct('SigmaZ',1));
            testCase.verifyEqual(out{1}.value,data.value,'AbsTol',1e-11);
            testCase.verifyError(@() ox_data_process(data,'smooth',struct('Sigma',[20 1])),'OxArpes:ProcessSigma');
        end

        function derivativeQuadraticSignAndAxes(testCase)
            [xx,yy] = ndgrid(-20:20,-20:20);
            data = OxArpes_2D_Data(-20:20,-20:20,xx.^2+3*yy.^2);
            out = ox_data_process(data,'derivative',struct('Sigma',[1 1]));
            testCase.verifyEqual(out{1}.value(12:30,12:30),-2*ones(19),'AbsTol',1e-10);
            testCase.verifyEqual(out{2}.value(12:30,12:30),-6*ones(19),'AbsTol',1e-10);
            volume = OxArpes_3D_Data(1:2,-20:20,-20:20,repmat(reshape(data.value,[1 41 41]),[2 1 1]));
            [out,info] = ox_data_process(volume,'derivative',struct('Sigma',[1 1]));
            testCase.verifyEqual(out{1}.value(:,12:30,12:30),-2*ones(2,19,19),'AbsTol',1e-10);
            testCase.verifyEqual(out{2}.value(:,12:30,12:30),-6*ones(2,19,19),'AbsTol',1e-10);
            testCase.verifyEqual(info.Axes,'YZ');
        end

        function medianRemovesImpulseAlongChosenAxis(testCase)
            testCase.assumeNotEmpty(which('medfilt1'));
            values = ones(7,8); values(4,4) = 100;
            data = OxArpes_2D_Data(1:7,1:8,values);
            out = ox_data_process(data,'median',struct('Window',3,'Axis',1));
            testCase.verifyEqual(out{1}.value,ones(7,8));
            testCase.verifyError(@() ox_data_process(data,'median',struct('Window',1.5)),'MATLAB:expectedInteger');
        end

        function workspaceNamesAndValidationBeforeAssignment(testCase)
            source = [testCase.Prefix '_input'];
            data = OxArpes_2D_Data(1:20,1:20,ones(20));
            assignin('base',source,data);
            first = ox_data_process_workspace(source,'smooth');
            second = ox_data_process_workspace(source,'smooth');
            testCase.verifyEqual(first.OutputNames,{[source '_sm']});
            testCase.verifyEqual(second.OutputNames,{[source '_sm_2']});
            testCase.verifyEqual(evalin('base',source),data);
            testCase.verifyError(@() ox_data_process_workspace(source,'smooth',struct(),source,true),'OxArpes:ProcessOutput');
            testCase.verifyError(@() ox_data_process_workspace(source,'smooth',struct(),first.OutputNames),'OxArpes:ProcessOutput');
            explicit = [testCase.Prefix '_explicit'];
            testCase.verifyError(@() ox_data_process_workspace(source,'derivative',struct(), ...
                {explicit,first.OutputNames{1}}),'OxArpes:ProcessOutput');
            testCase.verifyFalse(ismember(explicit,evalin('base','who')));
            report = ox_data_process_workspace(source,'smooth',struct(),first.OutputNames,true);
            testCase.verifyEqual(report.OutputNames,first.OutputNames);
        end

        function savedCallbacksAndLifecycle(testCase)
            source = [testCase.Prefix '_input'];
            volumeName = [testCase.Prefix '_volume'];
            data = OxArpes_2D_Data(1:25,1:30,repmat((1:25)',1,30));
            assignin('base',source,data);
            assignin('base',volumeName,OxArpes_3D_Data(1:2,1:25,1:30,ones(2,25,30)));
            app = OxArpes_DataProcess;
            testCase.addTeardown(@() delete(app));
            testCase.select(app,source);
            testCase.verifyEqual(app.ZSmoothButton.Enable,matlab.lang.OnOffSwitchState.off);
            app.sigma_xEditField.Value = 1;
            testCase.press(app.SmoothButton);
            testCase.verifyTrue(ismember([source '_sm'],evalin('base','who')));
            testCase.press(app.ndDerivativeButton);
            testCase.verifyTrue(ismember([source '_d2y'],evalin('base','who')));
            testCase.press(app.NormaliseButton);
            testCase.verifyEqual(mean(evalin('base',[source '_X_snor']).value,1),ones(1,30),'AbsTol',1e-12);
            app.NormalisetopeakCheckBox.Value = true;
            testCase.press(app.NormaliseButton);
            testCase.verifyEqual(max(evalin('base',[source '_X_snor_2']).value,[],1),ones(1,30));
            app.EditField.Value = '5'; app.EditField_4.Value = '10';
            testCase.press(app.TruncateDataButton);
            testCase.verifySize(evalin('base',[source '_tk']).value,[6 30]);
            testCase.press(app.ResetButton);
            testCase.verifyEqual(app.EditField.Value,'Min');
            if ~isempty(which('medfilt1')), testCase.press(app.RemoveButton); end
            testCase.select(app,volumeName);
            testCase.verifyEqual(app.ZSmoothButton.Enable,matlab.lang.OnOffSwitchState.on);
            testCase.press(app.SmoothButton);
            testCase.press(app.ZSmoothButton);
            testCase.verifyTrue(ismember([volumeName '_zsm'],evalin('base','who')));
            app.NormalisationdirectionButtonGroup.SelectedObject = app.XYButton;
            app.NormalisationdirectionButtonGroup.SelectionChangedFcn(app.NormalisationdirectionButtonGroup,[]);
            testCase.verifyEqual(app.FromEditField.Enable,matlab.lang.OnOffSwitchState.off);
            app.FromEditField.Value = 'ignored';
            testCase.press(app.NormaliseButton);
            testCase.press(app.RefreshButton);
            testCase.verifyEqual(app.ListBox.Value,volumeName);
            testCase.verifyEqual(app.NormalisationdirectionButtonGroup.SelectedObject,app.XYButton);
            testCase.verifyEqual(app.sigma_xEditField.Value,1);
            testCase.select(app,source);
            testCase.verifyEqual(app.NormalisationdirectionButtonGroup.SelectedObject,app.XButton);
            testCase.verifyEqual(app.FromEditField.Enable,matlab.lang.OnOffSwitchState.on);
            namesBefore = evalin('base','who');
            testCase.press(app.NormaliseButton); % invalid scalar text retained after plane mode
            testCase.verifyEqual(evalin('base','who'),namesBefore);
            status = findall(app.UIFigure,'Tag','StatusLabel');
            testCase.verifySubstring(status.Text,'Bounds must be finite real scalars');
            testCase.verifyEqual(evalin('base',source),data);
            delete(app);
            reopened = OxArpes_DataProcess;
            testCase.addTeardown(@() delete(reopened));
            testCase.verifyEqual(reopened.UIFigure.Visible,matlab.lang.OnOffSwitchState.on);
        end

        function previewOwnsOnlyNewGraphicsAndKeepsCoordinates(testCase)
            source = [testCase.Prefix '_input'];
            data = OxArpes_2D_Data([0 1 5],[10 8],reshape(1:6,3,2));
            assignin('base',source,data);
            unrelated = figure('Visible','off');
            testCase.addTeardown(@() delete(unrelated));
            ax = axes(unrelated); measured = plot(ax,1:4,4:-1:1);
            ax.XLim = [0 5]; ax.YLimMode = 'auto'; ax.NextPlot = 'add';
            app = OxArpes_DataProcess;
            testCase.addTeardown(@() delete(app));
            testCase.select(app,source);
            fig = app.preview();
            testCase.addTeardown(@() delete(fig));
            graphic = findall(fig,'Type','surface');
            testCase.verifyEqual(graphic.XData(1,:),[-0.5 0.5 3 7]);
            testCase.verifyEqual(graphic.YData(:),[11;9;7]);
            testCase.verifyEqual([min(graphic.CData(:)),max(graphic.CData(:))],[1 6]);
            testCase.verifyTrue(isvalid(measured));
            testCase.verifyEqual(ax.XLim,[0 5]);
            testCase.verifyEqual(ax.YLimMode,'auto');
            testCase.verifyEqual(ax.NextPlot,'add');
        end
    end
    methods (Access = private)
        function select(~,app,name)
            app.ListBox.Value = name;
            app.ListBox.ValueChangedFcn(app.ListBox,[]);
        end
        function press(~,button)
            button.ButtonPushedFcn(button,[]);
        end
    end
    methods (Static, Access = private)
        function clearFixtures(prefix)
            names = evalin('base','who');
            names = names(startsWith(names,prefix));
            for k = 1:numel(names), evalin('base',['clear ' names{k}]); end
        end
    end
end
