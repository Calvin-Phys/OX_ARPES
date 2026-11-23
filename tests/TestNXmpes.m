classdef TestNXmpes < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            oldPath = path;
            addpath(fullfile(root,'DataType'));
            addpath(genpath(fullfile(root,'DataLoader')));
            testCase.addTeardown(@() path(oldPath));
        end
    end
    methods (Test)
        function cutRoundTripPreservesTypedMetadata(testCase)
            file = testCase.newFile();
            data = OxA_CUT([3 1 -2],[10 12 15 19],single(reshape(1:12,[3 4])));
            data.name = 'Synthetic cut µ Δ';
            data.info.notes = 'Unknown';
            data.info.lens_mod = 'legacy metadata alias';
            data.info.tags = ["alpha",missing,"beta"];
            data.info.mask = logical([1 0;0 1]);
            data.info.large = uint64(2)^60 + uint64(7);
            data.info.nan_values = [NaN Inf -Inf];
            data.info.nested = {struct('unit','eV','values',int16([-2 4])),[],{true,'text'}};
            data.info.empty = struct('empty',{});
            [~,report] = testCase.roundTrip(file,data);
            testCase.verifyEqual(load_arpes(file),data);
            testCase.verifyEqual(string(h5read(file,'/entry/title')),string(data.name));
            testCase.verifyEqual(report.validation,'not_run');
            testCase.verifyTrue(ismember('sample/name',report.entries.missing_required));
        end
        function allDimensionsAndSingletonsRoundTrip(testCase)
            inputs = {OxArpes_1D_Data([4 2 1],uint16([5 6 7])), ...
                OxArpes_1D_Data(7,single(9)), ...
                OxArpes_1D_Data([1 2],logical([1 0])), ...
                OxArpes_2D_Data([1 2],[3 4],[NaN Inf;-Inf 0]), ...
                OxA_MAP([1 2],[-2 0 3],[15 16 18 21],reshape(1:24,[2 3 4])), ...
                OxA_KZ(40,[-1 1],[-0.2 0 0.4],reshape(1:6,[1 2 3])), ...
                OxA_RSImage([0 1],[3 4 5],10,reshape(1:6,[2 3 1])), ...
                OxA_MAP_ToF([1 2],[-1 0 1],[8 9],reshape(1:12,[2 3 2])), ...
                OxArpes_4D_Data([1 2],[3 4 5],10,[-2 0 1 3],reshape(1:24,[2 3 4 1])), ...
                OxArpes_4D_Data(1,2,[7 8],3,reshape(1:2,[1 1 1 2]))};
            for i = 1:numel(inputs)
                testCase.roundTrip(testCase.newFile(),inputs{i});
            end
        end
        function multiEntryDispatchAndPickerWrapper(testCase)
            file = testCase.newFile();
            inputs = struct('cut',OxA_CUT([0 1],[4 5],magic(2)), ...
                'scan',OxA_KZ([40 50],[-1 0 1],[-0.1 0],reshape(1:12,[2 3 2])));
            save_nxmpes(file,inputs);
            [loaded,report] = load_arpes(file);
            testCase.verifyEqual(loaded.cut.value,inputs.cut.value);
            testCase.verifyEqual(loaded.scan.value,inputs.scan.value);
            testCase.verifyEqual(report.loader,'load_nxmpes');
            testCase.verifyTrue(report.validated);
            selected = loader_UI(file,'Entry','scan','AssignToBase',false);
            testCase.verifyEqual(selected,inputs.scan);
        end
        function standardFileUsesCOrderAndPermutesEnergyFirst(testCase)
            file = testCase.newFile();
            testCase.externalCut(file,'kinetic');
            [data,report] = load_nxmpes(file);
            testCase.verifyClass(data,'OxA_CUT');
            testCase.verifyEqual(data.x,[-2 0 3]);
            testCase.verifyEqual(data.y,[10 12]);
            testCase.verifyEqual(data.value,[1 4;2 5;3 6]);
            testCase.verifyEqual(report.entries.permutation,[2 1]);
            testCase.verifyFalse(isfield(data.info,'workfunction'));
            testCase.verifyFalse(isfield(data.info,'thetay_offset'));
        end
        function bindingEnergyKeepsSignAndGenericContainer(testCase)
            file = testCase.newFile();
            testCase.externalCut(file,'binding');
            data = load_nxmpes(file);
            testCase.verifyClass(data,'OxArpes_2D_Data');
            testCase.verifyEqual(data.x,[10 12]);
            testCase.verifyEqual(data.value,[1 2 3;4 5 6]);
            testCase.verifyEqual(data.info.nexus.axes{1}.type,'binding');
        end
        function fixedWidthAxisAttributeIsDecoded(testCase)
            file = testCase.newFile();
            testCase.externalCut(file,'kinetic');
            id = H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');
            c1 = onCleanup(@() H5F.close(id));
            group = H5G.open(id,'/entry/view');
            c2 = onCleanup(@() H5G.close(group));
            H5A.delete(group,'axes');
            datatype = H5T.copy('H5T_C_S1');
            c3 = onCleanup(@() H5T.close(datatype));
            H5T.set_size(datatype,8);
            space = H5S.create_simple(1,2,[]);
            c4 = onCleanup(@() H5S.close(space));
            attribute = H5A.create(group,'axes',datatype,space,'H5P_DEFAULT');
            c5 = onCleanup(@() H5A.close(attribute));
            H5A.write(attribute,datatype,char('energy','angular0').');
            clear c5 c4 c3 c2 c1
            data = load_nxmpes(file);
            testCase.verifyEqual(data.value,[1 4;2 5;3 6]);
        end
        function exportedPhysicalLayoutMatchesNexus(testCase)
            file = testCase.newFile();
            data = OxArpes_4D_Data([1 2],[10 20 30],[5 6 7 8 9],[-2 0 3 4], ...
                reshape(single(1:120),[2 3 4 5]));
            data.k_name = 'Angle'; data.k_unit = 'deg';
            data.z_name = 'Kinetic Energy'; data.z_unit = 'eV';
            save_nxmpes(file,data);
            id = H5F.open(file);
            c1 = onCleanup(@() H5F.close(id));
            dataset = H5D.open(id,'/entry/data/data');
            c2 = onCleanup(@() H5D.close(dataset));
            space = H5D.get_space(dataset);
            c3 = onCleanup(@() H5S.close(space));
            [rank,shape] = H5S.get_simple_extent_dims(space);
            testCase.verifyEqual(rank,4);
            testCase.verifyEqual(shape,[2 3 4 5]);
            raw = H5D.read(dataset);
            testCase.verifyEqual(raw(5,4,3,2),data.value(2,3,4,5));
            testCase.verifyEqual(raw(2,3,1,2),data.value(2,1,3,2));
            axes = cellstr(string(h5readatt(file,'/entry/data','axes')));
            testCase.verifyEqual(axes(:),{'spatial0';'spatial1';'angular0';'energy'});
            testCase.verifyEqual(h5readatt(file,'/entry/data','energy_indices'),int32(3));
        end
        function energyConventionsAreExplicit(testCase)
            file = testCase.newFile();
            data = OxA_KZ([40 50],[-1 0],[-0.1 0 0.2],reshape(1:12,[2 2 3]));
            save_nxmpes(file,data);
            testCase.verifyEqual(h5readatt(file,'/entry/data/energy','type'),'kinetic');
            testCase.verifyEqual(h5readatt(file,'/entry/data/energy','ox_energy_convention'),'relative');
            loaded = load_nxmpes(file);
            testCase.verifyEqual(loaded.z,data.z);
            testCase.verifyEqual(loaded.value,data.value);
        end
        function overrideMetadataAndCompression(testCase)
            file = testCase.newFile();
            data = OxA_CUT([0 1],[4 5],magic(2));
            metadata = struct('sample_name','Synthetic sample','start_time','2026-01-02T12:30:00Z', ...
                'photon_energy',50,'collection_column_scheme','angular dispersive', ...
                'energy_dispersion_scheme','hemispherical');
            report = save_nxmpes(file,data,'Metadata',metadata,'Compression',9,'SignalUnits','counts');
            testCase.verifyEmpty(report.entries.missing_required);
            testCase.verifyEqual(h5read(file,'/entry/instrument/beam_probe/incident_energy'),50);
            loaded = load_nxmpes(file);
            testCase.verifyEqual(loaded.info,data.info);
            testCase.verifyEqual(loaded.value,data.value);
        end
        function refusesOverwriteAndPublishesOnlyCompleteWrites(testCase)
            file = testCase.newFile();
            data = OxA_CUT([0 1],[4 5],magic(2));
            save_nxmpes(file,data);
            testCase.verifyError(@() save_nxmpes(file,data),'OxArpes:NexusFileExists');
            bad = data;
            bad.info.unsupported = @sin;
            testCase.verifyError(@() save_nxmpes(file,bad,'Overwrite',true), ...
                'OxArpes:UnsupportedNexusMetadata');
            testCase.verifyEqual(load_nxmpes(file),data);
        end
        function malformedAxesAndUnknownEntryFail(testCase)
            file = testCase.newFile();
            testCase.externalCut(file,'kinetic');
            testCase.verifyError(@() load_nxmpes(file,'Entry','absent'),'OxArpes:NexusEntryNotFound');
            h5writeatt(file,'/entry/view','angular0_indices',int32(0));
            testCase.verifyError(@() load_nxmpes(file),'OxArpes:UnsupportedNexusAxes');
        end
        function explorerWithoutDefinitionAndBooleanMetadata(testCase)
            file = testCase.newFile();
            testCase.externalCut(file,'kinetic');
            id = H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');
            H5L.delete(id,'/entry/definition','H5P_DEFAULT');
            group = H5G.create(id,'/entry/arpes_explorer',0); H5G.close(group);
            group = H5G.create(id,'/entry/arpes_explorer/metadata',0); H5G.close(group);
            % Independent h5py-compatible bool enum, unsupported by h5info in R2024a.
            datatype = H5T.enum_create('H5T_NATIVE_UCHAR');
            H5T.enum_insert(datatype,'FALSE',uint8(0));
            H5T.enum_insert(datatype,'TRUE',uint8(1));
            space = H5S.create('H5S_SCALAR');
            dataset = H5D.create(id,'/entry/arpes_explorer/metadata/normalised',datatype,space,'H5P_DEFAULT');
            H5D.write(dataset,datatype,'H5S_ALL','H5S_ALL','H5P_DEFAULT',uint8(1));
            H5D.close(dataset); H5S.close(space); H5T.close(datatype); H5F.close(id);
            h5writeatt(file,'/','arpes_explorer_export','true');
            h5writeatt(file,'/entry/arpes_explorer','python_class','ARPESCutData');
            [data,report] = load_arpes(file);
            testCase.verifyEqual(data.value,[1 4;2 5;3 6]);
            testCase.verifyTrue(data.info.nexus.explorer_metadata.normalised);
            testCase.verifyNotEmpty(report.warnings);
            testCase.verifyEqual(report.loader,'load_nxmpes');
        end
    end
    methods (Access=private)
        function file = newFile(testCase)
            file = [tempname '.nxs'];
            testCase.addTeardown(@() delete_if_present(file));
        end
        function [loaded,report] = roundTrip(testCase,file,data)
            report = save_nxmpes(file,data);
            loaded = load_nxmpes(file);
            testCase.verifyEqual(loaded,data);
        end
        function externalCut(~,file,energyType)
            id = H5F.create(file);
            group = H5G.create(id,'/entry',0); H5G.close(group);
            group = H5G.create(id,'/entry/view',0); H5G.close(group);
            % Physical C shape [energy=2, angle=3], consecutive C-order counts.
            space = H5S.create_simple(2,[2 3],[]);
            dataset = H5D.create(id,'/entry/view/data','H5T_NATIVE_DOUBLE',space,'H5P_DEFAULT');
            H5D.write(dataset,'H5ML_DEFAULT','H5S_ALL','H5S_ALL','H5P_DEFAULT',reshape(1:6,[3 2]));
            H5D.close(dataset); H5S.close(space); H5F.close(id);
            h5create(file,'/entry/definition',1,'Datatype','string');
            h5write(file,'/entry/definition',"NXmpes");
            h5create(file,'/entry/view/energy',2); h5write(file,'/entry/view/energy',[10 12]);
            h5create(file,'/entry/view/angular0',3); h5write(file,'/entry/view/angular0',[-2 0 3]);
            h5writeatt(file,'/entry','NX_class','NXentry');
            h5writeatt(file,'/entry','default','view');
            h5writeatt(file,'/entry/view','NX_class','NXdata');
            h5writeatt(file,'/entry/view','signal','data');
            h5writeatt(file,'/entry/view','axes',["energy","angular0"]);
            h5writeatt(file,'/entry/view/energy','type',energyType);
            h5writeatt(file,'/entry/view/energy','units','eV');
            h5writeatt(file,'/entry/view/angular0','units','deg');
        end
    end
end

function delete_if_present(file)
    if isfile(file), delete(file); end
end
