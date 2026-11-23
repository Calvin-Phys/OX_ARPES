# OX_ARPES

OX_ARPES is a MATLAB toolkit for loading, representing, visualising, and
processing angle-resolved photoemission spectroscopy (ARPES) data from
multiple analysers and synchrotron beamlines. Its central design is a set of
class-based data containers with common operations such as truncation,
block averaging, filtering, momentum conversion, Fermi-level calibration,
symmetrisation, and spatial--spectral clustering.

## Getting started

Clone or copy the repository, then add the source folders to the MATLAB path:

```matlab
root = '/path/to/OX_ARPES';
addpath(fullfile(root,'DataType'));
addpath(genpath(fullfile(root,'DataLoader')));
addpath(genpath(fullfile(root,'DataAnalysis')));
```

For scripts and batch workflows, use the side-effect-free loader API:

```matlab
[data, report] = load_arpes('/path/to/scan.nxs');
data.validate();
data.show();
```

`report.loader` records the selected facility reader. Automatic HDF5/NeXus
detection uses dataset-path probes; PSI ADRESS Igor files are recognized by
the `/Matrix` dataset and its wave-scaling/note attributes. An explicit reader
can be selected when needed:

```matlab
data = load_arpes('/path/to/scan.ibw', ...
    'Format','load_scienta_IBW');
```

For interactive use, `loader_UI` opens a file picker and assigns validly named
variables to the base workspace. It also returns the loaded object (or a cell
array for multiple files):

```matlab
data = loader_UI();
```

## Data processing app

The maintained `OxArpes_DataProcess.m` app crops, smooths, differentiates, normalises,
median-filters, and block-averages scalar OX 2-D/3-D workspace objects:

```matlab
addpath(fullfile(root,'GUI'));
app = OxArpes_DataProcess;
```

Results receive new workspace names; existing outputs are retained. Use
`ox_data_process(data,action,options)` for processing without workspace effects,
or `ox_data_process_workspace(name,action,options)` for named workspace outputs.
`ox_data_process_agent` provides public open/read/list/select/refresh/resetcrop/
preview/process actions for the whole panel. Block reduction uses the existing
`block_reduce` class method with X/Y/Z sample factors and the `_rd` suffix.
See the [operation skill](AI_skills/ox-arpes-data-process/SKILL.md) for options,
axis conventions, and verification. The previous App Designer file is retained
as `GUI/OxArpes_DataProcess_legacy.mlapp`; its contents are unchanged. The
unsuffixed entry point resolves to the maintained `.m` implementation.

## Fermi-edge fitting app (FDD)

`FDD_fit_app` fits a gold/sample Fermi edge for E_F, Gaussian resolution (FWHM) and
temperature, then writes an E_F-shifted, Fermi-Dirac-divided or -multiplied *copy* of a cut
or map. It needs base MATLAB only and lives in `GUI/`:

```matlab
addpath(fullfile(root,'GUI'));
app = FDD_fit_app;                                    % Data -> Fit -> Apply
[E, I] = fdd_extract_edc(goldCut, 'XRange', [-10 10]);
R = fdd_fit_edc(E, I, 'Model', 'rcfd_lin_bg_T', 'Temperature', 10);  % hold T at the measured value
goldFD  = fdd_correct_data(goldCut, R.params, 'Renormalise', true);  % E-EF, divided by FD
shifted = fdd_correct_data(sampleCut, R.params);                    % same EF for a sample scan
```

Fits report 1-sigma errors, chi-squared, residuals and warnings; fitting temperature and
resolution together is flagged because one edge cannot separate them. See the
[user guide](doc/FDD_user_guide.md), the [review](doc/FDD_review.md) of the original
standalone `FDD_new` app, the [improvement log](doc/FDD_improvement_log.md) and the
[operation skill](AI_skills/ox-arpes-fdd-fit/SKILL.md).

## Data model

The base containers are:

- `OxArpes_1D_Data`: `value(x)`
- `OxArpes_2D_Data`: `value(x,y)`
- `OxArpes_3D_Data`: `value(x,y,z)`
- `OxArpes_4D_Data`: `value(x,y,k,z)`

The 4-D order is deliberately fixed as spatial `x`, spatial `y`, angular or
momentum `k`, then energy `z`. Constructors and `validate()` enforce agreement
between axis lengths and array dimensions and store coordinate vectors as
rows. Descending axes are permitted, but duplicate adjacent coordinates are
rejected, as are axes that change direction within one dataset.

ARPES-specific subclasses provide default labels and domain operations:

- `OxA_CUT`: analyser-angle/energy cuts and EDC extraction
- `OxA_MAP`: two-angle/energy maps
- `OxA_MAP_ToF`: time-of-flight maps
- `OxA_KZ`: photon-energy/angle/energy scans
- `OxA_RSImage`: real-space/energy scans
- `OxA_Core`: one-dimensional core-level or EDC data

Common metadata live in the `info` structure. Momentum conversions require
the relevant offsets plus calibrated `photon_energy`, `workfunction`, and, for
KZ conversion, `inner_energy`. Loaders preserve raw headers where available
and normalise legacy `lens_mod`/`len_mode` and `acquisition_mod` aliases at the
public `load_arpes` boundary.

## Analysis examples

```matlab
% Convert a cut to momentum and binding-energy coordinates.
data.info.thetay_offset = 0.4;
kcut = data.kconvert();

% Build a quantile background estimate and subtract it.
eid = ox_energy_intensity_distribution(data);
corrected = ox_remove_background(data,eid,0.15);

% Calibrate photon-energy-dependent Fermi drift.
cal = ox_calibrate_fermi_kz_scan(kzData, ...
    'Temperature',20,'Resolution',0.02);
if cal.isValid
    correctedKz = cal.data_corrected;
end
```

Clustering functions under `DataAnalysis/clustering` require Statistics and
Machine Learning Toolbox. `fit_fermi_edge_ox` requires Curve Fitting Toolbox (the FDD tools do not);
median filtering requires Signal Processing Toolbox. Some viewers and image
operations may require Image Processing Toolbox. Igor Binary Wave support is
provided by the bundled third-party `Igor2Matlab` code and its own licence.

The minimum supported MATLAB release has not yet been established against a
CI matrix. A recent MATLAB release is recommended.

## Supported input families

- Scienta SES/PEAK text, ZIP, and IBW data, including Solaris spin ZIP data
- Diamond Light Source i05 and i09 NeXus data
- PSI ULTRA and ADRESS HDF5 data
- Elettra Spectromicroscopy HDF5 data
- Soleil Cassiopee text exports (experimental readers under `DataLoader/test`)
- ALBA LOREA NeXus and KRX data
- ALS MAESTRO FITS and ALS H5 data
- SSRL BL5-2 HDF5 data
- Specs ITX data

Facility formats evolve. Validate the returned class, axes, metadata, and a
known reference scan before using a reader for quantitative analysis.

## Tests

Synthetic regression tests cover core dimensional contracts and the repaired
analysis APIs. The PSI ULTRA and ADRESS readers have also been exercised against
local beamtime examples; those raw files are not included. From the repository root:

```matlab
addpath('tests');
results = run_tests();
```

`tests/TestFDDCore.m` and `tests/TestFDDGui.m` cover the FDD Fermi-edge fitter and app.

Representative files are still needed to expand end-to-end coverage for the
remaining beamline loaders.

## Project status and licensing

This is research software under active development and is intended to become
a back-end component for earlier ARPES processing tools such as `yulinARPES`.
Project-owned code is licensed under the GNU General Public License version 3
(`GPL-3.0-only`). See [LICENSE](LICENSE). Bundled third-party components retain
their own licences and attribution files.

Contact: Cheng Peng <cheng.peng@physics.ox.ac.uk>

[Chen Group | ARPES at Oxford](http://www.arpes.org.uk)
