# NXmpes workspace loading and export GUI

Date: **23 November 2026**. Baseline: `15fdbd7` (NXmpes import/export backend).
This record covers the subsequent workspace, export-window and menu work.
See [NXmpes.md](NXmpes.md) for the maintained usage and format contract.

## Delivered behavior

`loader_UI` assigns individual NeXus datasets directly to the base workspace,
including scripted calls with explicit paths. It uses original dataset
names, makes them valid MATLAB identifiers, and adds suffixes to avoid
overwriting existing variables. Repeated loads create separate variables.
The report lists their names in `workspace_variables`. Calls without return
values also avoid creating a container in `ans`.

Explicit `'AssignToBase',false` remains available. Return values retain the
entry-keyed structure for scripts, and `load_arpes`/`load_nxmpes` continue to
return data without workspace assignment. Other scripted file formats keep
their existing assignment defaults.

The new [export_nxmpes_UI](../GUI/export_nxmpes_UI.m) window lists every base-
workspace variable using `whos`. It marks supported scalar OX objects,
allows checkbox selection of multiple datasets, refreshes the list while
retaining available selections, and accepts an editable output path or a
Browse dialog. Save calls the existing `save_nxmpes` backend and creates one
entry per checked workspace variable. Source objects are preserved.
Replacing an existing file requires confirmation. Stale variables,
unsupported metadata and write failures produce an error in the window.

The final default size is **400 x 400 pixels**, reduced from 800 x 560.
Narrower table columns, compact dimension strings and tighter spacing keep
all controls available. Instructions are combined below the title:
"Tick datasets, choose a file, then click Save NXmpes."
Save results and errors share that area. Removing the bottom text row gives
the variable list approximately 35 additional pixels at the default size.
The instruction area expands for errors, with full text available on hover.

Both yulinARPES entry points launch the same OX window:

| Browser | Menu |
|---|---|
| `ARPES_data_browser_v5` | Load → Export NXmpes... |
| `data_browser_demo_v32` | Loader → Export NXmpes... |

The OX `GUI` folder must be on the MATLAB path. Close and reopen an existing
export window to load changed layout code; reopen browsers to obtain newly
added menus. The matching yulinARPES repository records its menu changes in
its browser implementation log.

## Verification

Checks used isolated MATLAB **R2024a, 24.1.0.2537033** processes, preserving
the user's live MATLAB workspace and figures. Suites were run in focused
batches; the counts below are not a single combined full-suite run.

| Check | Result |
|---|---|
| Workspace update: `TestNXmpes` and `TestPSI_ADRESS` | 20 passed, 0 failed, 0 incomplete (15 + 5) |
| Initial GUI and NXmpes regression batch | 18 passed, 0 failed, 0 incomplete (3 + 15) |
| Final layout: `TestNXmpesExport` | 3 passed, 0 failed, 0 incomplete |
| Final GUI and GUI-test Code Analyzer | 0 notices on both files |
| Workspace loader Code Analyzer | Two existing notices: persistent placement and an obsolete suppression |
| Both yulinARPES menu callbacks | Opened the exporter and saved exact synthetic data |
| Added menu lines in both browsers | No Code Analyzer notices |

The three GUI tests cover the complete variable list, incompatible checkbox
selection, refresh preservation, actual Save callbacks, selective multi-entry
round-trips, unchanged source objects, stale variables and failed-write
recovery. Launch without a return value also exported successfully. Final
400 x 400 and smaller 360 x 360 renders were visually inspected, including
the consolidated instruction area and the taller list.

The supplied five-entry measured file created five individual OX workspace
objects. A repeated load preserved those objects and created five new,
uniquely named variables. Counts, coordinates and imported metadata retain
the preservation evidence recorded in the NXmpes guide. Five unsupported
optional boolean flags per entry remain explicit source references on
R2024a because of its HDF5 datatype-version limitation.

The earlier full-suite result (50/51, with the documented EID failure) is
historical backend acceptance evidence, not a new full-suite run for these
GUI changes. No full NXDL validation or R2025a runtime verification is
claimed. The provided Python reference and measured fixture remain local
inputs and are not required by the reusable tests.
