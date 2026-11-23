# FDD skill session — 23 November 2026

> Historical implementation/validation record. Recorded tests describe the dated revision,
> not the current live session. Measured-data identifiers are not used; all validation
> data are synthetic.

## Purpose and paths

Applied the external yulinARPES `improve-scientific-guis` workflow (yulinARPES `56f394e`) to
the standalone Fermi-edge fitting program `FDD_new.mlapp` (not part of this repository), then
added the upgrade to OX_ARPES (now `GUI/FDD/`). Review:
[FDD_review.md](FDD_review.md). Implementation and evidence:
[FDD_improvement_log.md](FDD_improvement_log.md). User guide:
[FDD_user_guide.md](FDD_user_guide.md).

Created the repository operation skill
[`ox-arpes-fdd-fit`](../AI_skills/ox-arpes-fdd-fit/SKILL.md). It is saved locally, not
installed for automatic discovery. The external reusable skill's files were not modified.

## API

`fdd_fit_edc(E, I, ...)` fits one EDC (default model `rcfd_lin_bg_T`, T held at the
measured temperature, when `Temperature` is given) and returns parameters, 1σ errors,
correlations, χ², residuals and warnings. `fdd_extract_edc` reads a cut (energy along y) or
map (energy along z); `fdd_correct_data` and `fdd_multiply_fd` return copies (samples with
occupation below `MinOccupation`, default 0.05, become NaN). `FDD_fit_app` uses the same
backend; its public methods (`selectData`, `setWindows`, `extractEDC`, `setModel`, `setStart`,
`setFixed`, `fit`, `applyCorrection`, `multiplyFD`, `getState`, `exportFigure`) allow scripted
control. Existing workspace variables are not overwritten without `'Overwrite', true`.
Legacy "Mod 1–6" names are accepted.

## Runtime and validation

MATLAB R2023a Update 8 (Linux), base MATLAB only, `matlab -batch`. From the repository
location: `TestFDDCore` (16) and `TestFDDGui` (6), **22 of 22 passed** after the second review; 0 Code Analyzer
notices in the 15 added files. Synthetic recovery (truth E_F 12.30 meV, T 30 K, FWHM 15 meV):
exact on noiseless data for all six models; with noise and T held, E_F 12.251 ± 0.236 meV and
FWHM 14.19 ± 0.93 meV. A free-T fit (legacy Mod 5) is degenerate in T and resolution on a
single noisy edge and is flagged.

Independent evaluation: none. No agent other than the implementer has run the skill.

## Second review before commit

The code was moved from `DataAnalysis/fermi_level/FDD/` to `GUI/` and reviewed again. Nine
issues (strict `Fixed`/`Free` names, held values no longer clamped, repeated energies, 4-D
rejection, no division by zero occupation, stale fit cleared in the GUI, validated variable
names, background note in the docs) were fixed; see
[FDD_improvement_log.md](FDD_improvement_log.md#second-review-before-commit--23-november-2026).
Full suite: 58 of 61 pass; the 3 others fail or are filtered identically on the previous commit.

## GUI feedback — 23 November 2026

Calvin's feedback: window compacted to 1088 × 624 (80 % of 1360 × 780); a finite
`data.info.temperature` becomes the held fit temperature; a fit-status lamp
(Idle / Fitting… / Done / Failed) with the Fit button disabled while fitting; the app and
all `fdd_*` code moved to `GUI/FDD/`. FDD suites: 25 of 25 pass. See
[FDD_improvement_log.md](FDD_improvement_log.md#gui-feedback--23-november-2026).

## Browser menus and publication — 23 November 2026

yulinARPES `925a1a0` adds **Fit Fermi-level (new)** (tag `FitFermiLevelNew`, calls
`FDD_fit_app` with no arguments) below the original Fermi-level entry in browser v5
(Analyze → Fit spectra) and legacy v32 (Tools). yulinARPES `Manual/Manual_for_AI.md` and
`AI_skills/SKILLS_MAP.md` route Fermi-edge fitting to this repository's
[`ox-arpes-fdd-fit`](../AI_skills/ox-arpes-fdd-fit/SKILL.md) skill. The two repositories
were committed to be published together, because the menu item needs `GUI/FDD`.

## Limitations

No measured gold edge has been fitted. The preview drag-rectangle, the overwrite
confirmation dialog and "Open in PlotSlices" (needs yulinARPES and GUI Layout Toolbox) were
not exercised interactively. One E_F per dataset; angle-dependent E_F is not implemented.
Only R2023a on Linux was tested.
