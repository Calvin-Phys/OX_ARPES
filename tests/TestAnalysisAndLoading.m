classdef TestAnalysisAndLoading < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            testsFolder = fileparts(mfilename('fullpath'));
            root = fileparts(testsFolder);
            oldPath = path;
            addpath(fullfile(root,'DataType'));
            addpath(genpath(fullfile(root,'DataLoader')));
            addpath(genpath(fullfile(root,'DataAnalysis')));
            testCase.addTeardown(@() path(oldPath));
        end
    end

    methods (Test)
        function energyDistributionHandlesNegativeAndSmallData(testCase)
            data = OxA_CUT(1:2,[-1 0],[-2 -1; 0 2]);
            distribution = ox_energy_intensity_distribution(data);
            testCase.verifyLessThan(distribution.x(1),0);
            testCase.verifySize(distribution.info.eid_bkgd,[2 10]);
            testCase.verifyTrue(all(isfinite(distribution.info.eid_bkgd),'all'));
        end

        function perPhotonEnergyBackgroundBroadcastsCorrectly(testCase)
            value = reshape(1:12,[2 2 3]);
            data = OxA_KZ([40 50],[-1 1],[-0.2 0 0.2],value);
            distribution = ox_energy_intensity_distribution_per_hv(data);
            out = ox_remove_background(data,distribution,0.15);
            testCase.verifySize(out.value,size(value));
            testCase.verifyGreaterThanOrEqual(min(out.value,[],'all'),0);
        end

        function singletonThreeDimensionalEidUsesEnergyAxis(testCase)
            data = OxA_KZ(40,[-1 1],[-0.2 0 0.2],reshape(1:6,[1 2 3]));
            distribution = ox_energy_intensity_distribution(data);
            testCase.verifyEqual(distribution.y,data.z);
            testCase.verifySize(distribution.info.eid_bkgd,[3 10]);
        end

        function invalidResolutionFitModeIsNamed(testCase)
            E = linspace(-0.2,0.2,21);
            I = 1./(exp(E/0.01)+1);
            testCase.verifyError(@() fit_fermi_edge_ox(E,I, ...
                'FixResolution',false,'FixTemperature',false), ...
                'OxArpes:InvalidFitOptions');
        end

        function fuzzyClusteringIsCallable(testCase)
            spectra = [1 0; 0 1; 0.9 0.1; 0.1 0.9];
            value = reshape(spectra,[2 2 2]);
            [labelMap,membership,centres,history,info] = ...
                custom_fcm(value,2,'cosine',2,30,1e-5);
            testCase.verifySize(labelMap,[2 2]);
            testCase.verifySize(membership,[2 4]);
            testCase.verifySize(centres,[2 2]);
            testCase.verifyNotEmpty(history);
            testCase.verifyEqual(info.nValidSites,4);
        end

        function descendingEnergyShiftIsSupported(testCase)
            data = OxA_KZ([40 50],[-1 1],[0.1 0 -0.1],reshape(1:12,[2 2 3]));
            out = ox_apply_fermi_shift_extended(data,[0 0]);
            testCase.verifyTrue(all(diff(out.z)>0));
            testCase.verifySize(out.value,[2 2 numel(out.z)]);
        end

        function matLoadingHasNoWorkspaceSideEffect(testCase)
            filePath = [tempname '.mat'];
            cleanup = onCleanup(@() delete_if_present(filePath)); %#ok<NASGU>
            sampleValue = magic(3); %#ok<NASGU>
            save(filePath,'sampleValue');
            [loaded,report] = load_arpes(filePath);
            testCase.verifyEqual(loaded.sampleValue,magic(3));
            testCase.verifyEqual(report.loader,'load_mat_file');
            testCase.verifyFalse(report.validated);
        end

        function explicitLoaderOverrideIsWhitelisted(testCase)
            filePath = [tempname '.mat'];
            cleanup = onCleanup(@() delete_if_present(filePath)); %#ok<NASGU>
            value = 1; %#ok<NASGU>
            save(filePath,'value');
            testCase.verifyError(@() load_arpes(filePath,'Format','delete'), ...
                'OxArpes:UnknownLoader');
            testCase.verifyTrue(isfile(filePath));
        end
    end
end

function delete_if_present(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end
