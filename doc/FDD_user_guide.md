# FDD: Fermi-edge fitting and Fermi-Dirac correction

Code: `GUI/FDD/` (`FDD_fit_app.m` and the `fdd_*.m` fitting functions). Upgrade of the
standalone `FDD_new.mlapp` / `FDD_new_exported.m` (Cheng Peng, 2023), made on 23 November
2026 following the yulinARPES `AI_skills/improve-scientific-guis` workflow; the original
program is not part of this repository. Review: [FDD_review.md](FDD_review.md); change record:
[FDD_improvement_log.md](FDD_improvement_log.md); agent skill:
[`ox-arpes-fdd-fit`](../AI_skills/ox-arpes-fdd-fit/SKILL.md).

`fit_fermi_edge_ox` in `DataAnalysis/fermi_level/` is the older Curve-Fitting-Toolbox
fitter for OX objects; FDD is independent of it and needs no toolbox.

**Requires base MATLAB only** (tested on R2023a Update 8, Linux). No Curve Fitting,
Optimization or Image Processing Toolbox. `PlotSlices` (yulinARPES) is optional.

## Launch

```matlab
addpath(fullfile(root,'GUI','FDD'))
app = FDD_fit_app;            % lists cut/map variables from the base workspace (1088 x 624 window)
```

From the yulinARPES browsers: **Analyze → Fit spectra → Fit Fermi-level (new)** (v5) or
**Tools → Fit Fermi-level (new)** (legacy v32), below the original Fit Fermi level entry.

1. **Data**: choose a cut or map; set the angle window (`x range`), for maps also
   `y`, and the energy range, or drag a rectangle on the preview. Press **Extract EDC**.
   If the selected variable has a finite, positive `info.temperature` (K; set by the DLS
   i05, ALBA LOREA and DLS i09 kPEEM loaders, or by hand), it is copied into the
   `Temperature` Start value and the **Multiply by FD** temperature, and the message bar
   names the source. A logged vector of readings gives their mean. Data without it leave
   the current values unchanged. The copy happens only when a variable is selected, so a
   value you type afterwards is kept for every refit until you select data again.
2. **Fit**: choose a model, check or enter the measured sample temperature in the
   `Temperature` row (Start column) and press **Fit**. The default model (Mod 6) holds T
   at that value; free-T models use it only as a start value unless **Fix** is ticked.
   While the fit runs, the lamp at the bottom left turns amber and reads **Fitting…**,
   the **Fit** button is disabled and the pointer is busy; afterwards it reads **Done**
   (green) or **Failed** (red, with the error in the message bar). It returns to
   **Idle** when new data or a new EDC invalidate the fit. Start values can be estimated with
   **Auto start values**; the **Fix** box holds a single parameter at its Start value.
   The table shows the fitted values and 1σ errors; the summary shows χ²/dof, R²,
   convergence and warnings; the lower plot shows residuals.
3. **Apply**: write a *new* base-workspace variable: **Shift to E−E_F** (`<name>_EF`),
   **Shift + divide by FD** (`<name><suffix>`, default `_FDD`) or
   **Multiply by FD** (`<name>_xFDD`, energy axis must already be E−E_F). Existing
   variables are only replaced after confirmation; the source is never changed.

## Models (legacy names kept)

| Key | Legacy | Free parameters | Use |
|---|---|---|---|
| `fd` | Mod 1 | A, E_F, T | quick look, negligible resolution |
| `fd_bg` | Mod 2 | + background | |
| `fd_lin_bg` | Mod 3 | + linear DOS | |
| `rcfd` | Mod 4 | A, E_F, T, FWHM | |
| `rcfd_lin_bg` | Mod 5 | all six | T and FWHM are strongly correlated; a warning is shown |
| `rcfd_lin_bg_T` | Mod 6 | all but T (held) | **recommended default**: hold T at the measured value |

Model: `I(E) = [(A + S·(E−E_F))·f_FD(E; E_F, T)] ⊗ G(FWHM) + B`, with
`f_FD = 1/(exp((E−E_F)/k_B T)+1)`, `k_B = 8.617333262e-5 eV/K`, Gaussian resolution
given as FWHM (σ = FWHM / 2√(2 ln 2)). Energies in eV, T in K. E − E_F < 0 is occupied.

## Scriptable functions (same backend as the GUI)

| Function | Purpose |
|---|---|
| `R = fdd_fit_edc(E, I, 'Model', key, 'Temperature', T, 'Window', [e1 e2], 'Initial', s, 'Fixed', s, 'Free', s, 'Weights', 'none'/'poisson')` | Levenberg–Marquardt fit; returns params, 1σ errors, correlation, χ², residuals, warnings |
| `[E, I] = fdd_extract_edc(data, 'XRange', .., 'YRange', .., 'ERange', ..)` | mean EDC from a cut (energy along y) or map (energy along z) |
| `out = fdd_correct_data(data, R.params, 'Renormalise', tf, 'MinOccupation', 0.05)` | shifted copy; optional background subtraction and division by the (broadened) FD; samples with occupation < MinOccupation → NaN |
| `out = fdd_multiply_fd(data, T, 'Resolution', fwhm)` | multiply a copy by FD |
| `I = fdd_model(E, p)`, `f = fdd_fermi(E, EF, T)` | model functions |
| `fdd_models()` | model presets and legacy aliases |
| `fdd_info_temperature` | `T = fdd_info_temperature(data)`: finite positive `data.info.temperature` (K) or `[]` |
| `FDD_fit_app` methods | `selectData`, `setWindows`, `extractEDC`, `setModel`, `setFitWindow`, `setStart`, `setFixed`, `fit`, `applyCorrection`, `multiplyFD`, `getState`, `exportFigure` (see `help FDD_fit_app`) |

Example:

```matlab
[E, I] = fdd_extract_edc(gold_cut, 'XRange', [-10 10]);
R = fdd_fit_edc(E, I, 'Model', 'rcfd_lin_bg_T', 'Temperature', 10.5, 'Window', [16.70 16.90]);
fprintf('E_F = %.4f ± %.4f eV, FWHM = %.1f meV\n', R.params.EF, R.stderr.EF, 1e3*R.params.Resolution);
gold_corr = fdd_correct_data(gold_cut, R.params, 'Renormalise', true);   % E-EF, divided by FD
% For another scan, the gold background B does not apply: shift only, or pass your own
% 'Background' (e.g. 0) when dividing by the FD edge.
cut_corr = fdd_correct_data(sample_cut, R.params, 'Renormalise', true, 'Background', 0);
```

## Tests

```matlab
results = runtests({fullfile(root,'tests','TestFDDCore.m'), ...   % 16 numerical/correction tests
                    fullfile(root,'tests','TestFDDGui.m')});      % 9 GUI/API tests (hidden app)
assertSuccess(results);
addpath(fullfile(root,'tests')); fdd_recovery_table   % fitted-vs-true table for all six models
```

Both files are also picked up by `tests/run_tests`.

## Known limits

* One E_F for the whole cut/map. A curved (angle-dependent) gold edge needs a per-angle fit.
* Tested with synthetic edges only; no measured gold reference was available.
* The preview drag-rectangle, the overwrite confirmation dialog and **Open in PlotSlices**
  (needs yulinARPES and GUI Layout Toolbox) were not exercised interactively.
