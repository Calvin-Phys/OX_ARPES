---
name: ox-arpes-fdd-fit
description: Fit a Fermi edge (EDC) for E_F, resolution and temperature, and shift or Fermi-Dirac-correct ARPES cuts/maps with the upgraded FDD tools. Use for Fermi-level calibration of measured or synthetic EDCs; not for k-space conversion or band fitting.
---

# Fermi-edge fitting with FDD

This repository skill is not globally installed. Set `root` to the OX_ARPES checkout
selected for the current project (runtime discovery or the supplied location, not a
personal directory layout), then:

```matlab
addpath(fullfile(root,'GUI','FDD'), fullfile(root,'DataType'));
```

Base MATLAB only (no toolboxes). `FDD_fit_app` / `fdd_*` live in
`GUI/FDD/`. Use the live MATLAB session that holds the user's data
and verify the expected workspace names first. Do not clear classes or the workspace
while another agent uses the shared session.

1. **Get an EDC.** `[E, I] = fdd_extract_edc(data, 'XRange', [a b])` for a cut
   (`value(x, y)`, energy along y) or add `'YRange'` for a map (`value(x, y, z)`,
   energy along z). Axes may be ascending or descending; NaN samples are ignored.
2. **Fit.** Prefer `R = fdd_fit_edc(E, I, 'Model', 'rcfd_lin_bg_T', 'Temperature', T_K)`
   with the measured sample temperature; `fdd_info_temperature(data)` returns
   `data.info.temperature` when it is finite and positive (otherwise `[]`, so ask). Use `'Window', [Emin Emax]` to restrict the
   range (same units as E; kinetic energy is fine). Read `R.params`, `R.stderr`,
   `R.chi2red`, `R.converged` and **always report `R.warnings`**.
   A free-T model (`rcfd_lin_bg`, legacy Mod 5) cannot separate T from resolution
   on a single noisy edge; if used, report its correlation warning.
3. **Apply.** `out = fdd_correct_data(data, R.params)` shifts to E−E_F;
   add `'Renormalise', true` to divide by the broadened FD (samples with occupation
   < `MinOccupation`, default 0.05, become NaN). Renormalise subtracts the fitted
   background B, which only belongs to the fitted scan; for another scan pass
   `'Background', value` explicitly. Inputs are never modified; give the result a new name.
4. **GUI.** `app = FDD_fit_app` drives the same functions; the public methods
   (`selectData`, `setWindows`, `extractEDC`, `setModel`, `setStart`, `fit`,
   `applyCorrection(mode, outName, 'Overwrite', false)`, `getState`) let an agent
   operate it without clicking. `applyCorrection` refuses to overwrite an existing
   variable unless `'Overwrite', true`. `selectData` copies a finite
   `info.temperature` into the Temperature start value (held by the default model);
   `getState()` reports it in `temperatureSource` and the fit state in `fitStatus`
   (`Idle`, `Fitting…`, `Done`, `Failed`).

Units: eV, K, Resolution = Gaussian FWHM in eV, Slope in intensity/eV.
Verification: compare `R.params.EF` with the edge midpoint on the plot, check
the residuals in `R.residual` are structureless, and quote `R.stderr.EF`.

Focused regressions: `runtests({fullfile(root,'tests','TestFDDCore.m'), fullfile(root,'tests','TestFDDGui.m')})`.
User guide: `doc/FDD_user_guide.md`. Evidence: `doc/FDD_review.md`,
`doc/FDD_improvement_log.md`, `doc/FDD_skill_session_summary.md`. Validated on synthetic
edges in MATLAB R2023a only; do not claim measured-data validation or other releases.
