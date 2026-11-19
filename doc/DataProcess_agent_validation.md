# Independent Data Process skill evaluation — 19 November 2026

> Historical implementation/validation record. Recorded tests describe the
> dated revision, not the current live session. The maintained app is now
> `GUI/OxArpes_DataProcess.m`; its predecessor is
> `GUI/OxArpes_DataProcess_legacy.mlapp`. Measurement and run identifiers
> have been replaced with role labels; example labels are not bundled data.

**Result: 97 checks passed, 0 failed in live MATLAB R2024a.** Every processing
operation in the repository skill, including block reduction, ran against bounded
crops of the user's measured CUT and MAP. No production code or skill was edited
by this evaluator. The user's existing panel and data were restored/preserved.

## Instructions and execution provenance

Read the repository skill
[`ox-arpes-data-process/SKILL.md`](../AI_skills/ox-arpes-data-process/SKILL.md),
[`references/api.md`](../AI_skills/ox-arpes-data-process/references/api.md), and
[`references/agent-workflows.md`](../AI_skills/ox-arpes-data-process/references/agent-workflows.md).
MATLAB guidance references read: `exploration.md`, `array-and-grid-data.md`, and
`smoothing-and-trends.md` from the installed `matlab-analyze-data` skill. The
repository numerical contracts take precedence over generic smoothing recipes.
No applicable `AGENTS.md` was found in this checkout.

The independent evaluator's MATLAB connector initially attached to a separate,
empty session with no figures. Queries for the expected measured CUT/MAP
and `ox_data_process_agent('list')` returned no data; `ox_data_process_agent('read')` returned `OxArpes:ProcessApp`. This was a
session mismatch, not a processing failure. The evaluator cleared its two
inspection variables from that session. A later isolated surface-coordinate
probe also deleted its figure and variables.

To test the actual loaded workspace, the evaluator independently authored the
self-contained function below, including its assertions and cleanup. The parent
agent executed the exact saved file unchanged through its live connector. The
evaluator then read the resulting JSON and inspected both PNGs independently.
No expected numerical answers were supplied by the parent.

The harness, its final/first-run JSON, and original preview artifacts were
generated in a task-specific directory outside the checkout. Those artifacts
are not distributed by this repository. If a copy of the harness is available,
set `artifactRoot` to its actual directory and use a portable invocation:

```matlab
previousPath = path;
restorePath = onCleanup(@() path(previousPath));
addpath(artifactRoot);
oxaAgentEval_DataProcess;
```

The final historical run completed in MATLAB R2024a on 19 November 2026.
Its generated unique workspace prefix and operating-system process IDs are
omitted because neither identifies a reusable input. The JSON recorded 97
passing checks; the first-run evidence recorded 96 passes and one evaluator
coordinate-extraction failure, corrected as explained below.

## Measured inputs and bounded requests

| Input | Live class | Original intensity shape | Crop indices, inclusive | Crop shape |
|---|---|---|---|---|
| `sample_cut` | `OxA_CUT` | 835 × 1034 | X 410:426; Y 507:527 | 17 × 21 |
| `sample_map` | `OxA_MAP` | 61 × 835 × 1034 | X 25:37; Y 410:426; Z 508:526 | 13 × 17 × 19 |

The table uses role aliases rather than original measurement names. Set
`sourceName` to an actual selected MAP name and `prefix` to an unused valid
workspace prefix before adapting this historical public-facade example:

```matlab
crop = ox_data_process_agent('process',struct( ...
    'App',app,'SourceName',sourceName,'Operation','truncate', ...
    'Parameters',struct('Scale','indices', ...
        'Bounds',{{25,37;410,426;508,526}}), ...
    'OutputNames',[prefix '_map']));
```

All further measured processing used those bounded workspace crops. The full
original volume was never processed into multiple full-size outputs. Full-object
source comparisons at cleanup used MATLAB value-object copies; the harness did
not mutate their arrays. A third preview fixture reused measured CUT intensities
with deliberately altered, nonuniform/descending coordinate vectors; it was not
presented as the original acquisition geometry.

## Feature coverage and observed results

| Feature | Actual actions and independent checks | Outcome |
|---|---|---|
| Workspace list/open/read/refresh/select | List included both measured inputs without creating figures. Explicit `App` reused the user's panel; open/refresh retained selection and parameters. Read exposed all operation settings. | Passed |
| Index and coordinate crop | Exact source-subarray/coordinate equality for both measured crops; reversed coordinate bounds selected the expected inclusive inner MAP region. | Passed |
| Full Range | Set nondefault crop entries and called `resetcrop` in both index and coordinate modes; all entries became Min/Max while retaining mode. | Passed |
| Plane Gaussian smooth | `Sigma=[0.8 1.1]`, both classes; independent separable weighted sums with symmetric sample extension across the entire output. 3-D filtering checked each Y/Z plane. | Passed |
| Both second derivatives | Both classes and outputs; negative repeated sample-unit gradients of independently smoothed data, excluding two boundary samples per filtered axis. `Details.Axes` was XY / YZ as documented. | Passed |
| Z Gaussian smooth | `SigmaZ=1` on MAP crop; explicit weighted Z-profile sums at every sample including truncated/renormalized edges. | Passed |
| Normalisation | X/Y in 2-D and X/Y/Z/XY/XZ/YZ in 3-D, each mean and peak mode (16 combinations). Axis references used indices 2:5; plane references used whole planes. Checked unit mean/maximum and metadata. Additional reversed coordinate reference and full-profile division check. | Passed |
| Median | Window 3 for every actual dimension: 2-D axes 1/2 and 3-D axes 1/2/3. Explicit padded three-sample medians checked edges as well as interiors. | Passed |
| Block reduction | MAP factors [2 3 4] and CUT factors [2 4 NaN], with inactive CUT Z ignored. Every output value compared with an independently indexed block mean; coordinate means, shapes, active factors, class/metadata, and dropped tails checked. | Passed |
| GUI controls versus defaults | Read current GUI reduction factors [2 3 4] and passed them to `process`; selected source used when SourceName omitted. A separate omitted-Parameters call returned the identity factors [1 1 1] despite those GUI settings. | Passed |
| Naming/assignment | Automatic `_rd` then `_rd_2` collision suffixes; explicit unique names; assigned objects compared with returned report objects. | Passed |
| Dimensional control state | Selecting CUT disabled Z-only smoothing and Z reduction controls; MAP enabled them. | Passed |
| Previews | Three owned figures: measured CUT, measured MAP central slices, and measured-intensity/nonuniform-axis CUT. Surface colors checked against the measured arrays; MAP central slices checked at ceil(N/2). Both unequal and descending sample edges checked exactly. | Passed |

The recorded facade sequence includes 41 `process` requests (successful and
expected failures), 19 `read`, 4 `select`, 3 `preview`, 2 `resetcrop`, 1 `open`, and
1 `refresh`, in addition to direct initial list/read and cleanup requests. The
97 figure is an assertion count, including workspace-assignment assertions, not
97 distinct panel features.

Maximum absolute numerical discrepancies from independent expectations:

| Calculation | Maximum absolute error |
|---|---:|
| CUT block means | 0 |
| MAP block means | 1.14 × 10^-13 |
| CUT Gaussian smooth | 2.18 × 10^-11 |
| MAP Gaussian smooth | 1.36 × 10^-12 |
| CUT derivative interiors | 1.18 × 10^-11 |
| MAP derivative interiors | 5.68 × 10^-13 |
| MAP Z smoothing | 6.82 × 10^-13 |
| Nonuniform/descending preview X/Y edges | 0 / 0 |

Filter/derivative tolerances were intensity-scaled (`2e-11 * max(1,max(abs(expected)))`);
normalisation unit-reference tolerance was `2e-12`. Reduction used
`2e-12 * max(1,max(abs(expected)))`. These are numerical implementation checks,
not an assessment of the scientific suitability of a particular filter width.

## Expected errors, warnings, and harness correction

The following requests raised the documented errors, created no variables, and
retained selection:

- Unknown request field `Typo` and unknown processing field `Factros`:
  `OxArpes:ProcessOptions`.
- Zero block factor: `OxArpes:ProcessFactors`.
- Z-only smoothing on CUT: `OxArpes:ProcessDimension`.
- Crop expression `1+2`: `OxArpes:ProcessBounds`.
- Request to use the source itself as output: `OxArpes:ProcessOutput`.
- Two derivative names with an existing second target: `OxArpes:ProcessOutput`;
  the first target remained absent and the existing guard value remained pi.
- All-zero derived CUT normalisation: `OxArpes:ProcessDivisor` before assignment.

The first live run passed 96 checks and failed only the evaluator's
`preview descending/nonuniform cell edges` assertion. The assertion incorrectly
assumed surface `YData` was a column and extracted `YData(:,1)`. A separate live
R2024a probe showed that `surface(xVector,yVector,...)` stores **both** coordinate
vectors as rows. The harness was corrected to handle coordinate vectors or mesh
arrays. No implementation or skill change was made. The identical measured
workflow then passed all 97 checks; the final preview stored XData as 1 × 18,
YData as 1 × 22, with both edge errors zero.

The final MATLAB connector response contained only the result JSON, no warning
or unexpected-error transcript, and `isError=false`. The harness did not assert
or capture `lastwarn`; this is not a separate warning-state certification.
Code Analyzer found no errors or warnings in the pre-execution harness, only
three informational style suggestions. Expected exception messages remain in
the result JSON as evidence.

## Preservation, cleanup, and limits

- The original selection and every value in the original
  `state.Parameters` were restored and compared for equality.
- Full `isequaln` object comparisons passed for both measured source variables,
  including class, axes, intensities, and metadata.
- The complete original base-workspace name set was retained, with no test
  variables remaining. Unrelated large datasets were never assigned by the
  harness; they were not each copied/hashed for content comparison.
- Both original figure handles remained and no extra figures remained. Root
  graphics defaults were equal before/after. The harness only deleted its owned
  previews, and did not clear classes, clear the workspace, or close all figures.
  It did not independently snapshot every property of unrelated graphics.
- Path was restored inside the function; the parent removed the temporary
  harness path after invocation. Captured-input `onCleanup` provides teardown
  if an operation raises an unexpected exception.
- Final JSON reports `CleanupFinished=true`. The parent confirmed no MATLAB
  execution was still running after the final run; the evaluator's separate
  child connector also had no outstanding execution.

The skill was sufficient for the measured workflow. Useful limits/gaps remain:
the facade has no control-setting/restoration action, so testing Full Range and
restoring exact prior settings required the app's public component properties;
agents should understand that passing Parameters processes data without setting
the GUI. The skill correctly distinguishes those backend defaults. It also
does not explain connector session isolation; agents must first verify that the
expected measured names actually exist. Derivative boundary formulas were not
independently validated here; interior signs/axes/scaling and full smoothing
were. This run did not validate every bad-factor variant, explicit overwrite of
an existing nonsource output, multiple simultaneous panels, singleton previews,
every display scaling, or other MATLAB releases. Button pixel interactions and
private callbacks were intentionally unnecessary for this public-facade skill.

No production failure was found in this independent measured-data evaluation.

### Primary-agent follow-up after evaluation

The operation skill now explicitly explains connector session isolation and the
independent-script/coordinator-execution approach used here. That documentation
addition addresses the isolation gap observed above; no processing code changed.
The facade still processes explicit Parameters without setting GUI controls;
public app component properties remain available when an agent needs to restore
visual control state rather than run a processing operation.
