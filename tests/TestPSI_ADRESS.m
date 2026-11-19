classdef TestPSI_ADRESS < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            testsFolder = fileparts(mfilename('fullpath'));
            root = fileparts(testsFolder);
            oldPath = path;
            addpath(fullfile(root,'DataType'));
            addpath(genpath(fullfile(root,'DataLoader')));
            testCase.addTeardown(@() path(oldPath));
        end
    end

    methods (Test)
        function twoDimensionalWaveLoadsAsCut(testCase)
            scaling = [0 0.5 0.25; 0 -1 -2];
            note = sprintf(['hv = 100\nPol = LV\nSlit = 120\nMode = MAM\n' ...
                'Epass = 40\nEk/Eb = Eb\nTemp = 20\n']);
            [filePath, expectedValue] = create_adress_fixture( ...
                [3 4], scaling, {'','degree','eV'}, note);
            cleanup = onCleanup(@() delete_if_present(filePath)); %#ok<NASGU>

            data = load_PSI_ADRESS(filePath);

            testCase.verifyClass(data, 'OxA_CUT');
            testCase.verifySize(data.value, [3 4]);
            testCase.verifyNumElements(data.x, 3);
            testCase.verifyNumElements(data.y, 4);
            testCase.verifyEqual(data.value, double(expectedValue));
            testCase.verifyEqual(data.x, [-1 -0.5 0]);
            testCase.verifyEqual(data.y, [93.5 93.75 94 94.25], 'AbsTol', 1e-12);
            testCase.verifyEqual(data.info.photon_energy, 100);
            testCase.verifyEqual(data.info.workfunction, 4.5);
            testCase.verifyEqual(data.info.polarization, 'LV');
            testCase.verifyEqual(data.info.pass_energy, 40);
        end

        function threeDimensionalTiltWaveLoadsAsMap(testCase)
            scaling = [0 0.5 0.25 1; 0 -1 -2 -1];
            note = sprintf(['hv = 100\nPol = LV\nMode = WAM\nEk/Eb = Eb\n' ...
                'Tilt = -1:1:1\n']);
            [filePath, expectedValue] = create_adress_fixture( ...
                [3 4 2], scaling, {'','degree','eV','degree'}, note);
            cleanup = onCleanup(@() delete_if_present(filePath)); %#ok<NASGU>

            data = load_PSI_ADRESS(filePath);

            testCase.verifyClass(data, 'OxA_MAP');
            testCase.verifyEqual(data.x_name, 'Polar');
            testCase.verifySize(data.value, [2 3 4]);
            testCase.verifyEqual(data.value, double(permute(expectedValue, [3 1 2])));
            testCase.verifyEqual(data.x, [-1 0]);
            testCase.verifyEqual(data.y, [-1 -0.5 0]);
            testCase.verifyEqual(data.z, [93.5 93.75 94 94.25], 'AbsTol', 1e-12);
            testCase.verifyEqual(data.info.polarization, 'LV');
            testCase.verifyEqual(data.info.energy_mode, 'EB');
        end

        function loaderUiDispatchesIgorWaveToAdress(testCase)
            scaling = [0 0.5 0.25; 0 -1 -2];
            note = sprintf('hv = 100\nPol = LV\nEk/Eb = Eb\n');
            [filePath, ~] = create_adress_fixture( ...
                [3 4], scaling, {'','degree','eV'}, note);
            cleanup = onCleanup(@() delete_if_present(filePath)); %#ok<NASGU>

            [data, report] = load_arpes(filePath);
            testCase.verifyClass(data, 'OxA_CUT');
            testCase.verifyEqual(report.loader, 'load_PSI_ADRESS');
            testCase.verifyTrue(report.validated);

            [explicitData, explicitReport] = load_arpes(filePath, ...
                'Format', 'load_PSI_ADRESS');
            testCase.verifyClass(explicitData, 'OxA_CUT');
            testCase.verifyEqual(explicitReport.loader, 'load_PSI_ADRESS');

            [uiData, uiReport] = loader_UI(filePath, ...
                'Progress', 'none', 'AssignToBase', false);
            testCase.verifyClass(uiData, 'OxA_CUT');
            testCase.verifyEqual(uiReport.loader, 'load_PSI_ADRESS');
        end

        function kineticEnergyAndDescendingScalesStayWithCounts(testCase)
            scaling = [0 -0.5 -0.25; 0 1 100];
            note = sprintf('hv = 110\nEk/Eb = Ek\n');
            [filePath, expectedValue] = create_adress_fixture( ...
                [3 4], scaling, {'','degree','eV'}, note);
            cleanup = onCleanup(@() delete_if_present(filePath)); %#ok<NASGU>

            data = load_PSI_ADRESS(filePath);

            testCase.verifyEqual(data.x, [1 0.5 0]);
            testCase.verifyEqual(data.y, [100 99.75 99.5 99.25]);
            testCase.verifyEqual(data.value, double(expectedValue));
            testCase.verifyEqual(data.info.energy_mode, 'EK');
        end

        function singletonTiltWaveKeepsAngleEnergyOrder(testCase)
            scaling = [0 0.5 0.25 1; 0 -1 -2 5];
            note = sprintf('hv = 100\nEk/Eb = Eb\n');
            [filePath, expectedValue] = create_adress_fixture( ...
                [3 4 1], scaling, {'','degree','eV','degree'}, note);
            cleanup = onCleanup(@() delete_if_present(filePath)); %#ok<NASGU>

            data = load_PSI_ADRESS(filePath);

            testCase.verifyClass(data, 'OxA_MAP');
            testCase.verifyEqual(data.x_name, 'Polar');
            testCase.verifySize(data.value, [1 3 4]);
            testCase.verifyEqual(data.x, 5);
            testCase.verifyEqual(data.y, [-1 -0.5 0]);
            testCase.verifyEqual(data.z, [93.5 93.75 94 94.25], 'AbsTol', 1e-12);
            testCase.verifyEqual(data.value, double(permute(expectedValue, [3 1 2])));
        end
    end
end

function [filePath, value] = create_adress_fixture(shape, scaling, units, note)
%CREATE_ADRESS_FIXTURE Shape and counts use Igor [angle, energy, scan] order.
% MATLAB h5write reverses dimensions on disk, so reverse them here to write
% an Igor-compatible dataset. h5read must return [scan, energy, angle].
    filePath = [tempname '.h5'];
    value = reshape(int32(1:prod(shape)), shape);
    storageOrder = numel(shape):-1:1;
    h5create(filePath, '/Matrix', shape(storageOrder), 'Datatype', 'int32');
    h5write(filePath, '/Matrix', permute(value, storageOrder));
    h5writeatt(filePath, '/Matrix', 'IGORWaveScaling', scaling);
    h5writeatt(filePath, '/Matrix', 'IGORWaveNote', note);
    h5writeatt(filePath, '/Matrix', 'IGORWaveUnits', units);
end

function delete_if_present(filePath)
%DELETE_IF_PRESENT Remove a temporary test fixture.
    if isfile(filePath)
        delete(filePath);
    end
end
