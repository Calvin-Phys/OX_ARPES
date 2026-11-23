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

For FDD Fermi-edge fitting changes, run the two FDD suites:

```matlab
results = runtests({fullfile(root, 'tests', 'TestFDDCore.m'), ...
                    fullfile(root, 'tests', 'TestFDDGui.m')});
assertSuccess(results);
```

`TestFDDCore` checks the model against an independent `integral` oracle (via
`fdd_synthetic`), parameter recovery, error identifiers and corrections of struct and
`OxA_CUT`/`OxA_MAP` copies. `TestFDDGui` builds a hidden `FDD_fit_app` and drives it
through its public methods with `fddtest_*` base-workspace fixtures that it removes
afterwards. `fdd_recovery_table` prints the fitted-vs-true table quoted in
`doc/FDD_improvement_log.md`.

Report the executed suite, MATLAB release, passed/failed/incomplete counts, and
warnings. An old review log is not evidence that the current suite passed.
Synthetic checks do not establish beamline calibration or all-release GUI
compatibility. Any measured-data comparison is a separate task with explicit
inputs and outputs; keep private measurement paths/IDs out of reusable tests.
