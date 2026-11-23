# NXmpes import and export

`DataLoader/save_nxmpes.m` and `DataLoader/load_nxmpes.m` provide NeXus
exchange using base MATLAB HDF5 support. Import is integrated into
`load_arpes` and `loader_UI`. No Python installation is required.
The mapping follows the NeXus **v2026.01**
[NXmpes definition](https://manual.nexusformat.org/classes/applications/NXmpes.html)
and [versioned NXDL source](https://github.com/nexusformat/definitions/blob/v2026.01/applications/NXmpes.nxdl.xml).

## Basic use

Add `DataType` and `DataLoader` to the MATLAB path as in the README:

```matlab
exportReport = save_nxmpes('scan.nxs',data,'SignalUnits','counts');
[restored,loadReport] = load_arpes('scan.nxs');
assert(isequaln(restored.value,data.value));
disp(exportReport.entries.missing_required);
```

Choose intensity units appropriate to the actual data. Unknown units remain
omitted and are listed in the report. A scalar structure exports several
objects as named NXentry groups; import returns a structure keyed by entry:

```matlab
scans = struct('cut',cutData,'map',mapData,'kz',kzData);
exportReport = save_nxmpes('session.nxs',scans,'SignalUnits','counts');
[loaded,report] = load_arpes('session.nxs');
oneMap = load_arpes('session.nxs','Entry','map');
```

`Entry` and `DataGroup` also work in scripted `loader_UI` calls. For a
particular NXdata group, use an absolute path inside the selected entry:

```matlab
data = load_nxmpes('scan.nxs','Entry','/entry', ...
    'DataGroup','/entry/spectrum');
```

Selection prefers `NXentry@default`, then `data`, then the Python exporter's
`measurement` group. Ambiguous alternatives require explicit selection.
Schema detection recognizes `.nxs`, `.nx5`, `.nexus`, `.h5`, `.hdf5` and
`.hdf` before facility-specific probes. Explicit selection is available as
`load_arpes(file,'Format','load_nxmpes')`.

## Preservation and supported layouts

The writer accepts scalar OX 1D--4D objects and the installed OX subclasses.
An OX export preserves class, name, counts, coordinate values, labels, units,
signal numeric type, singleton dimensions and portable `info`. Nonuniform
and descending axes are preserved. Four-dimensional array order is always
**`value(x,y,k,z)`**; constructor arguments remain `(x,y,z,k,value)`.
There is no interpolation, calibration, energy shift or sign conversion.

Physical HDF5 dimensions follow `NXdata@axes`, with zero-based
`AXISNAME_indices`; MATLAB's dimension reversal is handled at the boundary.
Default axis names are:

| Object | File axis order |
|---|---|
| CUT | angular0, energy |
| MAP / MAP_ToF | angular1, angular0, energy |
| KZ | photon_energy, angular0, energy |
| RSImage | spatial0, spatial1, energy |
| 4D | spatial0, spatial1, angular0, energy (when angle units are identified) |
| Generic | x/y/z/k, refined by recognized energy or momentum labels |

OX map Y is the analyser's fast angular coordinate. Check axis roles and
scan speed against the measurement. `AxisNames` supplies one unique HDF5
name per dimension for a single exported object. The reader accepts one
numeric monotonic coordinate vector of matching length per dimension.
Missing axes, `.` coordinates, coordinate meshes, bin edges, contradictory
indices, complex signals and ranks above four are rejected.

Foreign kinetic-energy cuts/maps with degree/eV coordinates can become OX
ARPES subclasses with a recorded permutation. Other foreign layouts retain
file order in generic OX containers, including binding-energy data. Missing
calibration values are not filled from constructor defaults.

## Export options and metadata

`Compression` accepts 0--9, default 4; zero disables gzip. The entire signal
is held in memory. Streaming and SWMR writes are not implemented.
`Overwrite` defaults to false. Export first completes a temporary file beside
the destination, so a failed write does not replace an existing output.

`EnergyConvention` accepts `auto` (default), `kinetic`, `binding`, `relative`
or `unknown`. Automatic selection uses `info.energy_convention` or a
recognized axis label. Binding energy is marked `type=binding`. OX's
`E-E_F` convention is marked `type=kinetic` with a Fermi reference and
`ox_energy_convention=relative`, following the NXmpes definition of relative
kinetic energy. The existing values are preserved. Unknown type is omitted
and reported. These declarations do not establish physical calibration.

The following `info` fields populate standard paths relative to NXentry:

| OX field | NeXus path |
|---|---|
| start_time | start_time (ISO 8601 acquisition time) |
| sample_name | sample/name |
| photon_energy | instrument/beam_probe/incident_energy (eV) |
| collection_column_scheme | instrument/electronanalyzer/collection_column/scheme |
| energy_dispersion_scheme | instrument/electronanalyzer/energy_dispersion/scheme |
| workfunction | instrument/electronanalyzer/work_function (eV) |
| beamline | instrument/name |
| lens_mode | instrument/electronanalyzer/collection_column/lens_mode |
| pass_energy | instrument/electronanalyzer/energy_dispersion/pass_energy (eV) |
| detector_type | instrument/electronanalyzer/detector/detector_type |
| intensity_units / SignalUnits | data/data@units |

`Metadata` overrides mapped fields for export without modifying the object:

```matlab
meta = struct('sample_name','reference sample', ...
    'start_time','2026-01-02T12:30:00Z','photon_energy',50, ...
    'collection_column_scheme','angular dispersive', ...
    'energy_dispersion_scheme','hemispherical');
report = save_nxmpes('scan.nxs',data,'Metadata',meta, ...
    'SignalUnits','counts','EnergyConvention','kinetic');
```

Unspecified, empty, `unknown` and `None` mapped fields are omitted. Missing
required fields appear in `report.entries.missing_required` and the file's
`ox_arpes@missing_required_json`. No acquisition timestamps, sample identity
or instrument geometry are invented. This list is an adapter completeness
check; it does not validate timestamps, enumerations, units or inherited NXDL
requirements. Reports explicitly state **`validation='not_run'`**, even if
the missing list is empty. Use an external NXDL validator before claiming a
standard-compliant deposit. This is general NXmpes export; NXmpes_arpes
geometry-compliant export is not claimed. Rectilinear NXmpes_arpes input is
supported through its NXdata representation.

The dispatcher's `report.validated=true` refers to OX dimensions and
coordinates; it is distinct from `report.nexus.validation` for NXDL.

Original `info`, name and labels use a versioned `ox_arpes:NXcollection`.
Numeric, logical, char, string, cell and struct metadata round-trip with
types and shapes, including missing strings, NaN/Inf and large integers.
Convert complex/sparse metadata and MATLAB objects (handles, tables,
datetime) into these portable types before export. Unsupported metadata
raise a named error. Metadata overrides are retained separately under
`export_metadata`; OX imports restore the original `info` exactly. Stored
class names are allowlisted and no input code is evaluated.

## ARPES Explorer compatibility

The supplied Python exporter has NXdata groups and hard-linked coordinates,
but omits `definition`. This importer also recognizes its exporter marker,
maps supported Python classes and restores available original labels.
The Python map's original `angular0, angular1, energy` property order is
preserved. Foreign instrument/sample fields and Explorer properties live in
`info.nexus`; bulk arrays are read once from NXdata.

The supplied file contains five optional boolean flags per entry using a
newer HDF5 datatype version that MATLAB R2024a cannot decode. For that
specific error, the reader retains an explicit unsupported status and source
path, lists paths in `info.nexus.unreadable_metadata` and adds a report
warning. Keep the native file to preserve those values. Supported boolean
enums are read normally. Unsupported scientific signals/axes still fail;
other HDF5 errors propagate. OX exports use R2024a-compatible types.

The supplied Python importer accepts its own application-specific layout.
OX exports target general NeXus/NXdata readers and do not clone Python
application sessions. Existing portable processing provenance in `info` is
preserved; the adapter does not reconstruct missing history or raw detector
data. Foreign NXdata metadata groups retain source references rather than
duplicating bulk raw signals.

## Checks

Run `runtests(fullfile(root,'tests','TestNXmpes.m'))` for synthetic coverage
of dimensions, file-order counts, metadata, energy conventions, entry
selection, compression and safe publication. Measured fixture acceptance
is a separate local check; reusable tests contain no private scan IDs.

Acceptance run: **23 November 2026**, isolated MATLAB **R2024a,
24.1.0.2537033**. The NXmpes suite passed **12/12**, with no failed or
incomplete cases. The full OX suite passed **50/51**; the sole failed and
incomplete case is the already documented
`TestAnalysisAndLoading/singletonThreeDimensionalEidUsesEnergyAxis` EID
failure, outside this change.

All five entries in the supplied measured file matched independent direct
HDF5 reads exactly, including all counts and coordinates in its 4D entry.
The imported measured cut also survived OX export/import with identical
counts, coordinates and imported metadata. Five unsupported optional flags
per entry were reported as source references, as described above. These
checks establish software preservation, not experimental calibration or
full NXDL conformance.
