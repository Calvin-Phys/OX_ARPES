# Data Process improvement record

> Historical implementation/validation record. Recorded tests describe the
> dated revision, not the current live session. The maintained app is now
> `GUI/OxArpes_DataProcess.m`; its predecessor is
> `GUI/OxArpes_DataProcess_legacy.mlapp`. Measurement and run identifiers
> have been replaced with role labels; example labels are not bundled data.

Date: 19 November 2026. Runtime: MATLAB R2024a (24.1.0.2537033).

## Request and plan

Apply `improve-scientific-guis` to `GUI/OxArpes_DataProcess.m`.
Read the `improve-scientific-guis` skill from the selected yulinARPES
checkout, together with its experience record and work templates. Discover that
checkout through the active project or available skill catalog.
Read the consolidation worklog, historical review/working log, current data classes, and callbacks. The outer directory is not a Git repository; `OX_ARPES` is the checkout. The exported app was already untracked, alongside three unrelated exported apps and a staged move of DataList into legacy. Preserve those changes. No applicable AGENTS.md found in the workspace.

| Observable outcome | Contract | Owner | Acceptance evidence |
|---|---|---|---|
| Readable, resizable processing app | Existing exported class and public component names retained | Primary agent | Fresh app screenshots, selection and resize checks |
| Validated processing and useful errors | Value objects, metadata, axis order, nearest-sample cropping, existing filter algorithms | Primary agent | Synthetic independent examples, invalid-input and callback checks |
| Scriptable processing | One backend shared by GUI/API; explicit output assignment and collision handling | Primary agent | Public backend/workspace API exercised in MATLAB |
| Maintainable operation instructions | Repository skill with setup, conventions, examples | Primary agent | Examples exercised; final evidence recorded here |

## Design choices

The user requested improvements through the skill without specifying a palette or layout. Use a workspace column and four processing panels in two columns, readable headings, axis/sample units, metadata, disabled incompatible controls, and a status message. Keep `.m` as the requested entry point; the separate legacy `.mlapp` is not regenerated or represented as updated.

Preserve descending coordinate axes and sort paired bounds as the existing crop methods do. Bounds accept scalar numbers and Min/Max (case insensitive), never evaluated expressions. Coordinate bounds snap to the nearest sample, including out-of-range values. Indices are inclusive, integral, and in range. Ignore Z controls for 2-D data and the region for plane normalisation.

For 2-D, smoothing/derivatives act on X/Y. For 3-D, use the existing YZ smoothing and derivative methods at each X; explicitly label this legacy convention. Preserve legacy derivative suffixes and document their 3-D meaning. Median filtering preserves the original mapping (2-D vertical X/horizontal Y; 3-D vertical Y/horizontal Z) with actual axis labels instead of ambiguous screen directions. Normalisation divides each profile by its mean or peak over the selected axis/plane. Reject nonfinite/zero divisors before assigning results.

Status: complete. The exported app, shared numerical backend, workspace adapter,
focused regression suite, operation skill, and visual evidence are saved in this
checkout. No numerical data-class files or unrelated exported apps were edited.

## Implemented behaviour

- Replaced the fixed 795 x 486 layout with an 1120 x 740 grid, aligned fields,
  clear headings, sample/coordinate units, dataset metadata, contextual axis
  labels, and status feedback. Smaller windows scroll the processing area while
  the heading and status stay visible. Existing public component names/types
  are retained and exposed as tags.
- Workspace refresh lists scalar OX 2-D/3-D objects and subclasses, retains the
  selected source, and disables unavailable operations. Class identity rather
  than `ndims` handles singleton 3-D datasets. Plane normalisation disables its
  unused reference region; a return to an axis validates the retained values.
- Fixed mean/peak normalisation by reading the checkbox Value, sharing the
  implementation with the API, and rejecting zero/nonfinite divisors and
  overflow. Fixed 3-D smoothing dispatch to `Gaussian_smoothen_YZ`.
- Centralised finite scalar/range/index/filter validation in `ox_data_process`.
  Reversed and descending-coordinate crops retain the existing nearest-sample
  policy. Expressions are not evaluated. Plane filters require at least two
  samples on each active axis and sufficient samples for the existing reflected
  padding. These restrictions avoid the legacy singleton `squeeze` ambiguity.
- Added `ox_data_process_workspace`: old suffixes are retained; existing default
  names get numeric suffixes. Explicit overwrite is opt-in; the source cannot
  be an output. Validate all names/conflicts before assigning results. The GUI
  and `app.process` use this adapter. Workspace `evalin` calls remain intentional
  compatibility boundaries restricted to valid identifiers or constant queries;
  no user-entered range text reaches an evaluator.
- Preview opens owned figures without an external plotting dependency.
  `PlotSlices` was present in the live session under the separate `yulinARPES`
  repository, but is absent from this checkout. The local preview shows a 2-D
  map or three central 3-D slices, with coordinate midpoints as sample-cell edges
  for nonuniform/descending axes. Existing figures/root defaults are not cleared
  or restyled. The preview is deliberately a quick view rather than a full slice
  browser. `.mlapp` is a separate legacy entry point and remains unchanged.
- Added the repository operation skill under `AI_skills/ox-arpes-data-process`.
  Added narrow Git ignore exceptions for this log, session summary, screenshots,
  and focused test file; other existing local docs/tests retain their ignore state.

## Final acceptance evidence — 19 November 2026

Runtime: MATLAB R2024a, 24.1.0.2537033, live MCP session. Signal Processing
Toolbox (`medfilt1`) was available. Final checks used reloaded saved source,
after deleting only the implementation session's earlier app instance.

| Layer | Evidence / result |
|---|---|
| Static | `check_matlab_code` on the app, both processing functions, and `tests/TestDataProcess.m`: zero notices on all four files. App checked again after the final layout/status edits. |
| Numerical/API | 11 tests passed, zero failed/incomplete; final `lastwarn` was empty. Analytical mean/peak and quadratic negative second derivatives; constant Gaussian/Z invariants and X-slice isolation; reversed/descending crops; singleton 3-D normalisation; median impulse removal; invalid bounds/indices and zero divisors; output collision and pre-assignment conflict validation. |
| Actual saved callbacks | Buttons for crop/reset, smoothing, derivatives, Z smoothing, mean/peak normalisation, median, refresh and direction changes invoked with real callback arguments. Invalid axis-region text raises status/alert with no workspace assignment. Source selection/settings persist across refresh. Close/reopen verified. |
| Ownership/coordinates | Preview preserves an unrelated measured line and its axes limits/modes/NextPlot. Nonuniform X/descending Y edges and color range verified; manual 3-D preview had three surfaces. |
| Operation instructions | Ran crop, peak-normalisation, and workspace Z-smoothing examples against isolated synthetic OX fixtures: passed. Skill is repository-local, not installed globally. |
| Visual | Inspected fresh 2-D/3-D apps at 1120 x 740, smaller 930 x 640 scrollable layout, and three-panel 3-D preview. No overlapping controls or clipped text within the normal-size content; smaller viewport intentionally scrolls. Current platform/DPI only. |

An initial callback argument mismatch was fixed during execution. A subsequent
check initially reused an already-loaded class; closing the old instance and
clearing only this class loaded the saved changes. A preview test was corrected
to account for MATLAB retaining surface coordinates as vectors. Those interim
failures are resolved in the final results above. No further broad suite was
run because no data-class or unrelated analysis code changed.

### Visual artifacts

- [Original interface](data_process_before.png)
- [Improved 2-D interface](data_process_2d.png)
- [Improved 3-D interface, plane normalisation](data_process_3d.png)
- [Small window with processing-area scrollbars](data_process_small.png)
- [Synthetic 3-D central-slice preview](data_process_preview.png)

## Initial implementation limits and state

Validation used synthetic data, not beamline measurements; only the installed
MATLAB R2024a and current Windows display scaling were checked. The tests do
not establish all-release/toolbox compatibility or quantitative beamline-data
agreement. The data classes' existing filter edge conventions, derivative sign
and sample-unit scaling remain in effect. No export-format guarantee or full
viewer is introduced. No independent subagent evaluation was performed.

Temporary synthetic workspace variables and test-owned figures are cleaned up.
The improved app is left open at its normal size. Launch again with
`OxArpes_DataProcess` after adding `GUI` and `DataType` to the path.
Use `ox_data_process` for no-side-effect numerical processing and
`ox_data_process_workspace` for explicit workspace outputs. See the linked
operation skill and `DataProcess_skill_session_summary.md` for maintained API
semantics. No automatic skill installation or legacy `.mlapp` update is claimed.


## Compact columns, block reduction, and agent coverage — 19 November 2026

User follow-up: compact the two processing columns to two thirds of their
current widths while keeping Workspace data unchanged; add a block-reduction
column with `_rd` outputs; cover the entire panel with callable AI skills;
have a subagent use selected live workspace measurements to test those skills.

Plan and ownership: primary agent owns app/backend/facade/skill changes and
integration; an independent subagent will own only the validation report and
its isolated test artifacts after the interface is stable. Serialize shared
MATLAB access during that evaluation. Preserve all 45 loaded file variables,
the current selection, unrelated working-tree changes and figures.

Measured baseline at 1120 x 740: Workspace 250 pixels, each processing column
407 pixels. Target: Workspace 250, each processing column 271 1/3 pixels; a
third equal processing column gives a 1132-pixel default window including gaps
and padding. Compact controls within the panels, not just parent bounds.

The actual OX class method is `block_reduce`, rather than `block_reduction`.
Call it directly: integer factors on actual X/Y/Z dimensions, block means of
values and coordinates, discard incomplete trailing blocks, retain input/class/
metadata, and use `_rd` with the existing collision-safe naming policy.

Apply skill-creator guidance and the existing yulinARPES data-browser / BZ skill
patterns: public open/read/list/select/refresh/reset/preview/process actions,
read without resets, explicit selection and defaults, one numerical backend,
reference tables for details and an independent realistic operation task.
Status: complete. Final evidence follows; this section supersedes the initial 11-test/no-independent-evaluation status above.


### Follow-up implementation and final acceptance

- Existing processing columns are exactly two thirds of their measured baseline:
  407 -> 271 1/3 pixels. Workspace remains 250 pixels. The new Block reduction
  column is also 271 1/3 pixels and spans both rows. Default window is 1132 x
  740; narrower windows scroll the processing area. Radio positions, bound
  fields, smoothing fields/buttons and explanatory text were compacted to fit.
- `reduce` is implemented by `ox_data_process`, calling the existing 2-D/3-D
  `block_reduce` method. Active factors are validated before calculation;
  2-D ignores its inactive Z entry. Output retains class/metadata; Details reports
  active factors and omitted tail counts. The GUI shows predicted output/tail
  sizes and creates collision-safe `_rd` outputs using the shared adapter.
- `ox_data_process_agent` covers open/read/list/select/refresh/resetcrop/preview/
  process. The seven numerical operations share the GUI backend. Read/open do
  not reset parameters; omitted processing parameters use explicit backend
  defaults. Optional App disambiguates multiple panels. Agent processing with
  explicit SourceName leaves the GUI selection alone. Public app methods now
  include selectData/readState/resetCrop alongside existing methods.
- The operation skill has an explicit whole-panel coverage table, exact facade
  request contracts, all-operation recipes, ownership/default semantics and the
  observed session-isolation lesson. It remains at the existing repository
  location and is not represented as a global skill installation.

| Check | Final evidence |
|---|---|
| Focused regressions | 14 passed, 0 failed/incomplete in MATLAB R2024a; no warning text and empty lastwarn. Added independent 2-D/3-D block means/coordinate/tail tests, singleton/invalid factors, actual reduction button, `_rd` collision and facade lifecycle/settings checks. |
| Static analysis | Changed app, backend, agent facade and TestDataProcess.m: zero Code Analyzer notices on all four. Workspace adapter was not changed in this follow-up. |
| Independent agent workflow | **97 checks passed, zero failed**, on center crops of live `sample_cut` (OxA_CUT, source 835 x 1034, crop 17 x 21) and `sample_map` (OxA_MAP, source 61 x 835 x 1034, crop 13 x 17 x 19). Independent loop-based block means, separable Gaussian weights, derivative interior values, Z-weight edge correction, all supported normalisation axes/planes and mean/peak modes, all median dimensions, actual preview cells/edges, naming/validation/atomicity and all facade actions. Check count includes output-assignment checks and is not a count of distinct features. |
| Preservation | Independent harness verified full equality of both original sample objects; all original base variable names retained; no evaluation variables left; original figure handles and root defaults unchanged; original app selection and every reported parameter restored. |
| Visual | Fresh measured CUT/MAP panel screenshots at 1132 x 740 and 930 x 640 inspected. Default layout has no text/control overlap; smaller layout has working horizontal/vertical processing-area scrollbars and pinned status. A brief pause was needed after drawnow for asynchronous UI reflow before exporting the small-window screenshot. |
| Skill checks | Frontmatter, naming, local links, balanced code fences and no scaffolding: passed. Official quick_validate.py was **blocked** by missing PyYAML (ModuleNotFoundError: yaml); structural checks and actual independent operation testing are the separately identified alternatives, not a claimed official-validator pass. |

Independent evaluation provenance: the subagent's connector opened an empty
MATLAB process distinct from the data-owning live process.
To test the actual loaded workspace, the subagent independently authored
`oxaAgentEval_DataProcess.m`; the coordinator executed its exact saved invocation
unchanged in the data-owning session and returned durable JSON/preview results for the subagent
to assess and report. The first run had 96 passes and one harness coordinate
extraction failure. The subagent separately confirmed MATLAB stores surface
XData and YData as row vectors; correcting only its test extraction produced
97/97 passes, with both nonuniform preview edge errors exactly zero. No production
change was required for this test correction. The final tool transcript contained
only result JSON, with no warning/error text outside the expected-error checks;
the independent harness did not separately assert lastwarn.

Representative measured numerical errors: 2-D block reduction zero; 3-D block
reduction 1.14e-13; 2-D Gaussian 2.18e-11; 3-D Gaussian 1.36e-12; derivative interior
errors 1.18e-11 (2-D), 5.68e-13 (3-D); Z smoothing 6.82e-13. Each was evaluated
against the harness's stated intensity-scaled tolerance. This is measured-sample
algorithm/contract validation, not a calibration or physics-reference comparison.

Artifacts:
- [Compact 2-D panel](data_process_compact_2d.png)
- [Compact 3-D panel](data_process_compact_3d.png)
- [Small scrollable panel](data_process_compact_small.png)
- [Synthetic 3-D preview](data_process_agent_3d.png) (regenerated illustration)
- [Synthetic nonuniform preview](data_process_agent_nonuniform.png) (regenerated illustration)
- [Independent agent report](DataProcess_agent_validation.md)

The original harness/JSON/preview artifacts were generated outside the
checkout and are not distributed here. Regenerated synthetic screenshots
replace the images that exposed measurement names or unique run IDs; they
illustrate the current interface and are not the original measured-run evidence.
The independent report gives invocation and coverage details. The loaded sources,
raw inconsistent-axis scan, 4-D data and import report remain in the workspace.
Only 2-D/3-D data appear in this processing panel (42 loaded datasets). The app
is left open at normal size, with the user's selection and settings retained.
Legacy `.mlapp` and unrelated exported apps/staged changes remain untouched.
