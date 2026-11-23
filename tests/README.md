# OX_ARPES regression tests

These tests construct synthetic arrays or temporary MAT/HDF5 files. They derive
source paths from their own location and use `tempname` for disposable files;
no personal checkout path, measured scan identifier, or private input dataset
is required. Numerical fixture values and class/error identifiers are test
contracts, not recorded measurement IDs.

From a selected OX_ARPES checkout, with `root` set to that checkout:

```matlab
addpath(fullfile(root, 'tests'));
results = run_tests();
assertSuccess(results);
```

For Data Process entry-point/API changes, run the focused synthetic suite:

```matlab
results = runtests(fullfile(root, 'tests', 'TestDataProcess.m'));
assertSuccess(results);
```

The processing suite launches `OxArpes_DataProcess.m` and checks numerical
operations, workspace naming, actual callbacks, app lifecycle, agent selection,
and preview ownership/coordinates. Median-filter checks require `medfilt1`.
Use an isolated MATLAB verification process when protecting an active user's
workspace and app instances. Other suites cover core data, analysis/loading,
and synthetic PSI ADRESS format/axis contracts.

`TestNXmpes.m` covers NXmpes import/export, physical HDF5 dimension order,
1D--4D classes and singleton dimensions, typed metadata, energy conventions,
multi-entry dispatch, individual workspace assignment, duplicate-name
protection and protection against incomplete writes. It generates
independent synthetic HDF5 layouts as well as round-trip files. The supplied
Python example and measured NeXus file are optional local acceptance inputs;
the reusable suite does not depend on them. See [the NXmpes guide](../doc/NXmpes.md).

`TestNXmpesExport.m` checks the export window's complete workspace list,
selection/refresh behavior, actual Save callback, file round-trip, source
preservation and errors after workspace changes or unsupported metadata.

Run that focused GUI suite in an isolated MATLAB process with:

```matlab
results = runtests(fullfile(root, 'tests', 'TestNXmpesExport.m'));
assertSuccess(results);
```

See the [NXmpes worklog](../doc/NXmpes_GUI_worklog.md) for dated final-layout
checks, menu integration and the distinction from historical full-suite results.

Report the executed suite, MATLAB release, passed/failed/incomplete counts, and
warnings. An old review log is not evidence that the current suite passed.
Synthetic checks do not establish beamline calibration or all-release GUI
compatibility. Any measured-data comparison is a separate task with explicit
inputs and outputs; keep private measurement paths/IDs out of reusable tests.
