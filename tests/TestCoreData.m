classdef TestCoreData < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            testsFolder = fileparts(mfilename('fullpath'));
            root = fileparts(testsFolder);
            folders = {fullfile(root,'DataType'), ...
                fullfile(root,'DataAnalysis','symmetrise_interpolate')};
            oldPath = path;
            addpath(folders{:});
            testCase.addTeardown(@() path(oldPath));
        end
    end

    methods (Test)
        function rejectsMismatched2DShape(testCase)
            testCase.verifyError(@() OxArpes_2D_Data(1:3,1:4,zeros(4,3)), ...
                'OxArpes:DimensionMismatch');
        end

        function rejectsAxisThatChangesDirection(testCase)
            testCase.verifyError(@() OxArpes_1D_Data([0 2 1],[1 2 3]), ...
                'OxArpes:NonMonotonicAxis');
        end

        function truncatesWithReversedBounds(testCase)
            data = OxArpes_2D_Data(3:-1:0,10:13,reshape(1:16,4,4));
            out = data.truncate(1,3,13,11);
            testCase.verifyEqual(out.x,[3 2 1]);
            testCase.verifyEqual(out.y,[11 12 13]);
            testCase.verifySize(out.value,[3 3]);
        end

        function blockReduceKeepsTwoDimensions(testCase)
            value = reshape(1:24,4,6);
            data = OxArpes_2D_Data(1:4,1:6,value);
            out = data.block_reduce(2,3);
            expected = [mean(value(1:2,1:3),'all'), mean(value(1:2,4:6),'all'); ...
                        mean(value(3:4,1:3),'all'), mean(value(3:4,4:6),'all')];
            testCase.verifyEqual(out.value,expected,'AbsTol',1e-12);
            testCase.verifySize(out.value,[2 2]);
        end

        function zSmoothingActsOnlyAlongZ(testCase)
            value = zeros(2,3,7);
            value(:,:,4) = 1;
            data = OxArpes_3D_Data(1:2,1:3,1:7,value);
            out = data.Z_Gaussian_smoothen(1);
            testCase.verifyEqual(out.value(1,1,:),out.value(2,3,:),'AbsTol',1e-12);
            testCase.verifyGreaterThan(out.value(1,1,4),out.value(1,1,3));
        end

        function fourDimensionalContractAndReduction(testCase)
            value = reshape(1:120,[2 3 4 5]); % x,y,k,z
            data = OxArpes_4D_Data(1:2,1:3,1:5,1:4,value);
            out = data.block_reduce(1,1,5,4);
            testCase.verifyEqual(out.value,mean(value,[3 4]),'AbsTol',1e-12);
            testCase.verifyEqual(numel(out.k),1);
            testCase.verifyEqual(numel(out.z),1);
            testCase.verifyError(@() OxArpes_4D_Data(1:2,1:3,1:5,1:4, ...
                permute(value,[1 2 4 3])),'OxArpes:DimensionMismatch');
        end

        function fourDimensionalTruncationKeepsKBeforeEnergy(testCase)
            value = reshape(1:240,[3 4 4 5]); % x,y,k,z
            data = OxArpes_4D_Data(1:3,1:4,10:14,20:23,value);
            out = data.truncate_idx(3,2,4,2,5,3,4,2);
            expected = value(2:3,2:4,2:4,3:5);
            testCase.verifyEqual(out.value,expected);
            testCase.verifyEqual(out.k,21:23);
            testCase.verifyEqual(out.z,12:14);
        end

        function offCentreRotatedMapConverts(testCase)
            data = OxA_MAP(10:12,5:7,20:21,ones(3,3,2));
            data.info.photon_energy = 30;
            data.info.workfunction = 4.5;
            data.info.azimuth_offset = 15;
            out = data.kconvert();
            testCase.verifyClass(out,'OxA_MAP');
            testCase.verifySize(out.value,[numel(out.x),numel(out.y),2]);
            testCase.verifyTrue(all(isfinite(out.x)) && all(isfinite(out.y)));
        end

        function descendingMapAxesConvert(testCase)
            data = OxA_MAP(12:-1:10,7:-1:5,20:21,ones(3,3,2));
            data.info.photon_energy = 30;
            data.info.workfunction = 4.5;
            data.info.azimuth_offset = 15;
            out = data.kconvert();
            testCase.verifyTrue(all(isfinite(out.value),'all'));
            testCase.verifyGreaterThan(max(out.value,[],'all'),0);
        end

        function singletonSliceRetainsMatrixOrientation(testCase)
            data = OxArpes_3D_Data(1,1:3,10:13,reshape(1:12,[1 3 4]));
            cut = data.get_slice('x',1,0);
            testCase.verifySize(cut.value,[3 4]);
        end

        function realSpaceEnergyIntegration(testCase)
            value = reshape(1:24,[2 3 4]);
            data = OxA_RSImage(1:2,1:3,10:13,value);
            out = data.integrate_energy(12,11);
            testCase.verifyEqual(out.value,sum(value(:,:,2:3),3));
            testCase.verifyEqual(out.info.integration_range,[11 12]);
        end

        function symmetryFunctionMatchesFilename(testCase)
            data = OxA_MAP(-1:1,-1:1,0,reshape(1:9,[3 3 1]));
            opts = struct('x_out',-1:1,'y_out',-1:1,'pad_px',1, ...
                'feather_px',0,'min_weight',0);
            [out,debug] = sym_map_data_autoMask(data,opts);
            testCase.verifySize(out.value,[3 3]);
            testCase.verifySize(debug.accW{1},[3 3]);
        end
    end
end
