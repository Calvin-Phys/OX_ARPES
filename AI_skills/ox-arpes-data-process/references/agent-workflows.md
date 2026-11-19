# Agent requests and recipes

Use the live MATLAB tools; batch MATLAB has a separate workspace. Keep the
loaded source variables and user figures. All calls below use public functions
on the checkout's GUI path. Names such as `sample_cut` and `sample_map` are
illustrative: replace them with actual names discovered from the inventory.
Read `api.md` for exact axes/defaults and constraints.

## Inspect, select, and read panel settings

```matlab
inventory = ox_data_process_agent('list');
state = ox_data_process_agent('open');
state = ox_data_process_agent('select',struct('SourceName','sample_cut'));
state = ox_data_process_agent('read');
state = ox_data_process_agent('refresh'); % source and existing values retained
state = ox_data_process_agent('resetcrop'); % Min/Max bounds, same scale
```

Requests above assume a single panel. When more than one is open, include
`'App',state.App` in each GUI request and in process requests. `open` reuses and
raises an existing panel without reinitializing values. `read` does not refresh;
use it for inspection. The list includes compatible 2-D/3-D scalar objects;
4-D data and raw structures remain in the workspace but are outside this panel.

## Run every processing feature

Pick actual workspace names from `inventory`. Avoid processing full large
volumes repeatedly just to test the skill. This creates a bounded measured
region without modifying its source:

```matlab
crop = ox_data_process_agent('process',struct( ...
    'SourceName','sample_map','Operation','truncate', ...
    'Parameters',struct('Scale','indices','Bounds',{{1,12;1,48;1,64}})));
sampleName = crop.OutputNames{1};
```

For 2-D use two Bounds rows. Coordinate ranges use the existing axis units:
`struct('Scale','coordinates','Bounds',{{xmin,xmax;ymin,ymax;zmin,zmax}})`.
Min/Max are accepted instead of numbers; reversed and descending-axis ranges
are sorted after nearest-sample selection. Indices are inclusive, one based.

Run any operation with that bounded 3-D input:

```matlab
smoothed = ox_data_process_agent('process',struct('SourceName',sampleName, ...
    'Operation','smooth','Parameters',struct('Sigma',[1 1])));
derivatives = ox_data_process_agent('process',struct('SourceName',sampleName, ...
    'Operation','derivative','Parameters',struct('Sigma',[1 1])));
zSmoothed = ox_data_process_agent('process',struct('SourceName',sampleName, ...
    'Operation','zsmooth','Parameters',struct('SigmaZ',1)));
meanNormal = ox_data_process_agent('process',struct('SourceName',sampleName, ...
    'Operation','normalise','Parameters',struct('Direction','Y','Peak',false, ...
    'Scale','indices','Bounds',{{2,40}})));
peakNormal = ox_data_process_agent('process',struct('SourceName',sampleName, ...
    'Operation','normalise','Parameters',struct('Direction','YZ','Peak',true)));
medianFiltered = ox_data_process_agent('process',struct('SourceName',sampleName, ...
    'Operation','median','Parameters',struct('Window',3,'Axis',2)));
reduced = ox_data_process_agent('process',struct('SourceName',sampleName, ...
    'Operation','reduce','Parameters',struct('Factors',[2 3 4])));
```

The suffixes are `_sm`, `_d2x`/`_d2y`, `_zsm`, `_<direction>_snor`, `_rmspk`,
and `_rd`. The two derivative results follow X/Y for 2-D and Y/Z for 3-D, with
the existing negative sign and sample-unit scaling. For 2-D, omit zsmooth and
use two block factors. All plane/axis normalisation choices and mean/peak modes
are covered by the same Operation, with Direction/Peak specifying the mode.

OutputNames may be explicit strings or a cell array (two names for derivatives).
Check availability first; absent explicit names, safe suffixes are generated.
Default overwrite is false. Parameter and name errors create no output.

## Use current controls or deterministic defaults

```matlab
state = ox_data_process_agent('read');
operation = 'reduce';
report = ox_data_process_agent('process',struct('Operation',operation, ...
    'Parameters',state.Parameters.(operation))); % exactly these GUI factors

report = ox_data_process_agent('process',struct('Operation','reduce')); % [1 1 1]
```

Passing an explicit SourceName processes that input while leaving the current
GUI selection alone. Without SourceName, the selected input is used. The app's
public `process` follows the same backend-default rule. GUI buttons pass their
current parameters explicitly, so the formulas and naming are shared.

## Preview and verify

```matlab
preview = ox_data_process_agent('preview',struct('SourceName',sampleName));
% Inspect/export this owned figure if needed, then close only this figure.
delete(preview);
```

An explicit preview source becomes the selection; read it back if needed.
Each preview call opens a new independent figure. Closing the processing app
leaves previews open. The source does not change, and unrelated figures/axes
are not cleared or restyled.

Validate shape, class, coordinates and metadata, not only a successful return.
For reduction compare individual output pixels with means of the corresponding
input blocks and check coordinate means/tail counts. For normalisation check
unit mean or peak over the reference region or plane. For derivatives inspect
`Details.Axes` to disambiguate the legacy 3-D suffixes. For workspace operations
verify assigned values through `report.OutputNames`; the report also retains
returned output objects, so release temporary reports to avoid keeping large
results alive after deleting test variables. Restore any selection/settings
you intentionally changed, then refresh. Clean only names/figures created by
the evaluation. Never clear all workspace variables or all figures.
