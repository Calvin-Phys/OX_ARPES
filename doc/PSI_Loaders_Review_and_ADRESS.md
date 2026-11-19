# PSI Loader Review and ADRESS Implementation

**Date:** 2026-11-16

**Scope:** Review `load_PSI_ULTRA`, implement and test PSI ADRESS loading, and connect ADRESS files to the standard loader pipeline.

## ADRESS orientation issue: resolution summary

**Resolved on 2026-11-16.** Loaded cuts and maps initially displayed energy and emission angle in exchanged directions. Comparing the complete reference chain (`ReaderHDF5` → `ReadARPES` → `load_ADRESS`) established that the Igor scale columns were correct, but their channel counts were associated with the wrong dimensions of MATLAB's `h5read` result. Scaling column 2 describes emission angle, column 3 describes energy, and column 4 describes the map scan. Each axis is reconstructed as `origin + (0:count-1)*step`, using scaling row 2 for the origin and row 1 for the step.

The final loader handles the two cases as follows:

| Data | Raw `h5read` order | Final OX order | Correction |
| --- | --- | --- | --- |
| Cut | `[energy, angle]` | `value(angle, energy)` | Construct `x` from raw column count and `y` from raw row count, then transpose counts with `value.'`. |
| Map | `[scan, energy, angle]` | `value(scan, angle, energy)` | Apply `permute(value,[1 3 2])`; reconstruct scan, angle, and energy axes from their corresponding scales. |

For cuts, the final construction explicitly ties each coordinate to its raw channel count:

```matlab
angleCount = size(value, 2);
energyCount = size(value, 1);
angleAxis = make_axis(scaling, 2, angleCount);
energyAxis = make_axis(scaling, 3, energyCount) + energyOffset;
value = value.';
DATA = OxA_CUT(angleAxis, energyAxis, value);
```

Thus `numel(DATA.x) == size(DATA.value,1)` and `numel(DATA.y) == size(DATA.value,2)`, with emission angle along `x` and kinetic energy along `y`. The follow-up check confirmed these lengths and made their construction explicit; it did not introduce another transpose. For maps, the confirmed `[1 3 2]` permutation was retained and only the scan-axis label was changed from `Tilt` to **`Polar`** (`DATA.x_name`). Its coordinate values still come from the Igor scan scale.

Verification used representative measured ADRESS cut and map files. The corrected cut has 391 angle points from −8.5° to 9°, 688 kinetic-energy points from 485.9 to 499.1 eV, and value size `[391 688]`. The corrected map has value size `[61 391 688]`, with 61 Polar positions from −15° to 15° and the same angle/energy axes. Every count agrees exactly with the reference reader's final ordering; energy coordinates agree within 1e-12 eV after the existing kinetic-energy shift.

The synthetic fixtures were corrected to reproduce Igor storage order, because the original fixtures repeated the loader's incorrect dimension assumption. All **5 ADRESS regression tests passed**, covering cut/map counts and coordinates, axis lengths, descending scales, a singleton scan, loader dispatch, and the `Polar` label. Existing loaded objects must be recreated from the raw files to receive the correction. If MATLAB retains a cached loader, run `clear load_PSI_ADRESS` and `rehash` before reloading.

## ULTRA loader review

Reviewed `DataLoader/load_PSI_ULTRA.m` and exercised it with a representative measured PSI example. The loader correctly returned an `OxA_KZ` object for that file, but several implementation details make it sensitive to HDF5 layout changes:

| Location | Finding | Effect |
| --- | --- | --- |
| Lines 15–23, 34–39 | Axis scales are searched only among `data_info.Groups(1).Datasets.Attributes`, using partial-name matching. The code does not check that each search returns exactly one attribute. | Reordered groups, attributes on a different dataset, missing attributes, or overlapping names can cause a failed or ambiguous lookup. |
| Lines 64–74 | Polarization is read from `Groups(2).Datasets(21).Attributes(3)` by position. | This assumes a fixed instrument-group layout and attribute order. It worked for the tested scan, but is not a schema-level lookup. |
| Lines 25–29, 41–53, 65 | Axis and work-function corrections use fixed offsets (`0.1298` and `0.0258`) without explaining their calibration source. | The loader produces axes, but the example test cannot establish that these offsets are scientifically correct for all ULTRA runs. |
| Lines 13–60 | Array dimensionality selects KZ or CUT, and unsupported dimensions return `[]` with a warning. | The supported-shape behavior is clear; the axis order and physical offsets still need a trusted reference scan for scientific validation. |

The MATLAB Code Analyzer reported one informational style suggestion at line 33 (`ismatrix` in place of a dimension comparison); it reported no execution errors for the loader.

## ADRESS format investigation

The representative ADRESS files are Igor HDF5 waves. The representative files use a root `/Matrix` dataset with `IGORWaveScaling`, `IGORWaveUnits`, and `IGORWaveNote` attributes. The note includes photon energy (`hv`), polarization, pass energy, energy mode (`Ek/Eb`), and scan settings.

**Orientation correction (2026-11-16):** The original review misidentified the physical dimensions returned by `h5read`. Igor scale columns 2, 3, and 4 describe angle, energy, and tilt, respectively. MATLAB `h5read` returns the cut as `[energy, angle]` and the map as `[tilt, energy, angle]`. The loader must transpose cut counts with `permute(value,[2 1])` and swap the map's second and third dimensions with `permute(value,[1 3 2])` before constructing OX axes.

The class order remains `OxA_CUT.value(angle, energy)` and `OxA_MAP.value(tilt, angle, energy)`. Axes must be reconstructed using the reordered dimensions: 391 angle channels and 688 energy channels for both representative scans. Previously, the correct angle and energy scale columns were applied to the wrong channel counts. Class dimension checks passed because the axes were generated to fit those wrong dimensions. Transposing counts without also reconstructing the axes cannot fix this issue.

Follow-up check: cut coordinates are now explicitly constructed from the raw array before transposing: `x` uses scaling column 2 and `size(rawValue,2)` angle channels; `y` uses scaling column 3 and `size(rawValue,1)` energy channels. `value = rawValue.'` then gives `[numel(x), numel(y)]`. This preserves the corrected numerical result while making the channel association explicit. The map's existing `[1 3 2]` permutation is preserved, and its `x_name` is now `Polar` as requested; the coordinate still comes from the Igor scan scale (wave-note `Tilt`).

The reference chain is `ReaderHDF5` → `ReadARPES` → `load_ADRESS` at `yulinARPES/Loader_kconvert/+LoadDataARPES/private/`. `ReaderHDF5` reverses the dimensions from `h5read` before associating them with the Igor scales. The later permutations combine to the cut transpose and map `[1 3 2]` permutation above. Its final 3D ordering does match OX. The reference wrapper's base-workspace assignment, input-directory handling, and catch-all PEARL fallback are not carried into the new reader.

## Implementation and integration

- Added `DataLoader/load_PSI_ADRESS.m`. It validates the HDF5 attributes and supported axis units, reconstructs axes from Igor origins and steps, parses selected note metadata, and returns an `OxA_CUT` for 2D cuts or an `OxA_MAP` for 3D angle-scan maps.
- Added automatic recognition in `load_arpes` using the `/Matrix` dataset and its Igor wave attributes. Added the reader to the explicit-format allowlist.
- Updated the `.h5` file-picker description in `loader_UI.m` and the supported-format list in `README.md`.
- Added `tests/TestPSI_ADRESS.m` with synthetic 2D, 3D, and dispatcher/UI checks. The raw beamtime examples remain outside the repository.

For the supplied ADRESS examples, `Ek/Eb` is `Eb`. OX cut/map objects use kinetic energy on their energy axis, so the reader adds `photon_energy - workfunction` to that axis. These files do not contain a work function; the loader uses the package's 4.5 eV default and records that source in `info.workfunction_source`. Set `data.info.workfunction` to a calibrated value before quantitative momentum conversion when 4.5 eV is not appropriate. The tested scans do not establish that the default is a valid ADRESS calibration.

Wave-note `Theta` and `Azimuth` are retained as metadata; the loader does not reinterpret them as OX angular offsets because their calibration meaning was not established. Set the OX offset fields from a calibrated reference before quantitative momentum conversion. Three-dimensional ADRESS support is currently for degree-valued tilt/angle scans over energy. Other 3D scan-axis types are rejected with a named error rather than being assigned to an incompatible class.

## Verification

### PSI example files

All source data were read directly from the local beamtime folders. No raw data were copied, uploaded, or added to the repository.

| Reader/path | Returned result | Status |
| --- | --- | --- |
| ULTRA: representative measured photon-energy scan | `OxA_KZ`, value size `[5 614 847]`, photon energy 119.001 eV | Loaded and validated |
| ADRESS: representative measured cut | `OxA_CUT`, value size `[391 688]`, angle −8.5° to 9°, kinetic energy 485.9 to 499.1 eV, photon energy 500 eV, polarization LV | Corrected orientation; loaded and validated |
| ADRESS: representative measured map | `OxA_MAP`, value size `[61 391 688]`, tilt −15° to 15°, angle −8.5° to 9°, kinetic energy 485.9 to 499.1 eV | Corrected orientation; loaded and validated |

The three real files were also passed together through `loader_UI(paths,'Progress','text','AssignToBase',false)`. Automatic dispatch selected `load_PSI_ULTRA` for the ULTRA file and `load_PSI_ADRESS` for both ADRESS files; all three reports had `validated = true`.

After the orientation correction, both ADRESS files were passed through `load_arpes` and independently through the original `ReadARPES`/`ReaderHDF5` functions. Every count matches the original wrapper's final permutation exactly. Angle and tilt coordinates match exactly, and energy coordinates match within 1e-12 eV after the existing OX kinetic-energy shift.

### MATLAB tests

- `TestPSI_ADRESS.m`: **5 passed, 0 failed** after the orientation correction. Fixtures now write Igor `[angle, energy, tilt]` storage order, including the reversal required by MATLAB's `h5write`. Tests compare every count and the axis origins, steps, and lengths for cuts and maps, plus descending kinetic-energy/angle scales, a singleton tilt scan, automatic and explicit `load_arpes` selection, and dispatch through `loader_UI`. The original fixtures incorrectly wrote OX dimension order and therefore concealed the bug.
- `TestAnalysisAndLoading.m`: **7 passed, 1 failed**. The existing `singletonThreeDimensionalEidUsesEnergyAxis` test errors with `OxArpes:UnsupportedDimension` in `ox_energy_intensity_distribution`. This failure is outside the PSI loader changes; the other tests in that class passed.
- MATLAB Code Analyzer: no findings for the new ADRESS loader. The existing ULTRA reader has the informational style suggestion noted above.

## Remaining scientific checks

The file-format and class-shape checks pass on the supplied examples. The ADRESS work-function/angle-offset choices and the ULTRA axis corrections still require comparison with calibrated/reference data or beamline guidance before treating converted momentum or energy coordinates as quantitatively confirmed.
