---
name: ox-arpes-data-process
description: Operate every OX ARPES Data Process panel feature through its MATLAB agent API, including workspace selection, crop, Gaussian smoothing, derivatives, normalisation, median filtering, block reduction and slice previews.
---

# OX ARPES Data Process

Use the live MATLAB session containing the user's data. This repository skill
is not globally installed. The maintained entry point is
`GUI/OxArpes_DataProcess.m`; `GUI/OxArpes_DataProcess_legacy.mlapp`
preserves the legacy App Designer implementation.
Verify the expected workspace names before acting: subagent MATLAB connectors
can open a separate empty session. For an independent evaluation in that case,
have the subagent author its test function and review the results after the
coordinator executes that function unchanged in the session owning the data.

## Setup and inspect

Set `root` to the OX_ARPES checkout selected for the current project, then add
its `GUI` and `DataType` folders. Use runtime discovery or the supplied project
location, not a personal directory layout. Use the public
facade rather than clicking pixels or calling private callbacks:

```matlab
addpath(fullfile(root,'GUI'),fullfile(root,'DataType'));
inventory = ox_data_process_agent('list');  % no panel opened, no selection reset
state = ox_data_process_agent('open');     % reuse/raise one live panel, else create
state = ox_data_process_agent('read');     % inspect without refresh/reset
```

When multiple panels exist, pass `struct('App',appHandle)` to disambiguate.
`state.App` and `state.Figure` identify the selected panel. `state.Selected`,
`Available`, `Parameters`, `Status`, and `ColumnWidths` describe its current
state. Read/list never open a panel; other GUI actions require a live one.

## Whole-panel coverage

| Panel feature | Agent action / processing Operation |
|---|---|
| Refresh workspace | `refresh` |
| Select one dataset | `select`, with `SourceName` |
| Inspect selection and every control value | `read` |
| Crop X/Y/Z, coordinate or index bounds | `process`, Operation `truncate` |
| Full range button | `resetcrop`; restores Min/Max and retains crop scale |
| Gaussian plane smoothing | `process`, Operation `smooth` |
| Two second derivatives | `process`, Operation `derivative` |
| Z-only Gaussian smoothing | `process`, Operation `zsmooth` |
| Mean/peak normalisation, axis/plane and reference region | `process`, Operation `normalise` |
| Median filter, window and actual array axis | `process`, Operation `median` |
| X/Y/Z block averaging | `process`, Operation `reduce` |
| Preview 2-D map / three central 3-D slices | `preview` |

Read [API fields, defaults, units and numerical conventions](references/api.md)
before selecting non-default options. Read [agent workflows and runnable
recipes](references/agent-workflows.md) for request syntax, current-GUI-parameter
processing, all operations, preview ownership and realistic measured-data use.

## Processing contract

```matlab
state = ox_data_process_agent('select',struct('SourceName','myData'));
report = ox_data_process_agent('process',struct( ...
    'Operation','reduce','Parameters',struct('Factors',[2 3 2])));
disp(report.OutputNames);
```

`process` uses the current selection when `SourceName` is omitted. An explicit
`SourceName` can run without a panel and does not change a live selection.
`Parameters` uses backend defaults for omitted fields. To use the current GUI
settings, pass `state.Parameters.(operation)` explicitly. Unknown request/option
fields and ambiguous panels are errors. Processing returns `SourceName`,
`OutputNames`, `Outputs`, and `Details` and refreshes an existing unambiguous
panel while retaining the source selection and control values.

Names default to operation suffixes; collisions append `_2`, `_3`, etc. Block
reduction uses `_rd`. Explicit `OutputNames` require distinct valid identifiers;
existing names require `Overwrite=true`. The source cannot be an output. All
names/conflicts are checked before assignment. Source data/class/metadata are
retained. Keep measured originals and user figures intact.

For calculations without workspace or figure effects, use
`[outputs,details] = ox_data_process(data,operation,parameters)`; outputs is a
cell array. `ox_data_process_workspace` is the lower-level named-input adapter.
Both share the GUI backend. `app.selectData`, `readState`, `resetCrop`,
`refreshData`, `process` and `preview` are also public.

## Verification and evaluation

Check output names, class, shape, coordinates, effective `Details`, and suitable
numerical invariants. Reduction averages values and coordinates, discards
incomplete trailing blocks, and reports `DroppedSamples`. Normalisation should
have unit mean/peak over its reference; zero divisors fail before assignment.
3-D plane filters/derivatives act on Y/Z, not X/Y. Preview follows actual sample
cell edges, including nonuniform/descending coordinates.

Large live scans can be hundreds of MB. For testing several operations, crop a
bounded region from a measured workspace object first. Use names unique to the
evaluation, validate outputs against the source region and independent block
means, and clean up only those outputs/figures. Do not clear classes or the
workspace while another agent uses the shared MATLAB session.

Focused regressions: `runtests(fullfile(root,'tests','TestDataProcess.m'))`.
Implementation evidence and the requested independent measured-data evaluation
are recorded in `doc/DataProcess_improvement_log.md` and
`doc/DataProcess_agent_validation.md`. This skill is repository-local; do not
claim automatic installation or compatibility beyond tested releases.
