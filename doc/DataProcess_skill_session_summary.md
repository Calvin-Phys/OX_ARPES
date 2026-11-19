# Data Process skill session — 19 November 2026

> Historical implementation/validation record. Recorded tests describe the
> dated revision, not the current live session. The maintained app is now
> `GUI/OxArpes_DataProcess.m`; its predecessor is
> `GUI/OxArpes_DataProcess_legacy.mlapp`. Measurement and run identifiers
> have been replaced with role labels; example labels are not bundled data.

Current validation: 14 focused regressions and 97 independent agent-authored
measured-data checks pass. See the follow-up section below for current API and
evaluation provenance; the initial implementation record is historical.

## Initial implementation record

Applied the external `improve-scientific-guis` workflow to
`GUI/OxArpes_DataProcess.m`. Detailed implementation and evidence:
[DataProcess_improvement_log.md](DataProcess_improvement_log.md).

Created the repository operation skill
[`ox-arpes-data-process`](../AI_skills/ox-arpes-data-process/SKILL.md), with linked
action/axis/default reference. It is saved locally, not installed for automatic
discovery. This is the checkout-local session summary; the external reusable
skill's files were not modified.

New shared API: `ox_data_process(data,action,options)` returns output cells and
effective details without workspace/figure effects. `ox_data_process_workspace`
adds validated identifier selection, collision-safe default names, opt-in explicit
overwrite, and a prohibition on overwriting the source. Neither API opens or
resets the app. GUI buttons use the same backend. `app.process` uses API defaults
for omitted options; `app.refreshData` retains the current input.

Preserved the legacy numerical conventions and suffixes, including Y/Z
smoothing/derivative axes in 3-D and negative second differences in sample units.
Ranges use scalar numbers or Min/Max, nearest-sample coordinate selection and
inclusive sorted indices. Plane normalisation ignores its inactive region.
Previews accumulate independent owned figures without clearing user graphics.

Validation: MATLAB R2024a; 11 focused tests passed without warnings; four changed
MATLAB files had zero Code Analyzer notices. Operation examples for cropping,
peak normalisation and workspace Z smoothing passed. Fresh 2-D/3-D, smaller
scrollable UI, and central-slice preview screenshots were visually inspected.
Tests used synthetic fixtures and preserved unrelated graphics. No independent
agent evaluation or beamline-data comparison was performed. There was no blocked
validator; only the installed release/current Windows display scaling was tested.


## Follow-up: compact panel, block reduction and whole-panel agent facade

User requested two-thirds processing columns, an added block-reduction column
with `_rd`, full agent-skill coverage, and independent subagent testing against
loaded measured data. Workspace column remains 250 pixels; processing columns
are 271 1/3 pixels each. New `reduce` action delegates to `block_reduce`, returning
active factors/tail counts and preserving class/metadata and collision semantics.

Added `ox_data_process_agent` with open/read/list/select/refresh/resetcrop/preview/
process. Unknown fields and ambiguous panels fail explicitly. Read/open retain
state, explicit processing sources leave selection alone, and omitted Parameters
use backend defaults. The revised skill links a facade contract reference and
all-operation recipes; it remains repository-local, not automatically installed.

Latest validation supersedes the initial 11-test evidence: 14 focused regressions
pass without warnings; the four changed MATLAB files have zero analyzer notices.
Independent subagent-authored measured CUT/MAP evaluation passes 97 checks,
including all seven operations, all mean/peak axis/plane normalisation choices,
median dimensions, previews, actual workspace assignment, source/figure/default
preservation, and restoration of the user's panel state. The child MATLAB
connector was isolated; the coordinator executed the agent's saved test unchanged
through the actual data-owning connector and the agent reviewed its evidence.
One test-only surface-vector extraction assumption was corrected between runs;
no production correction was needed. See DataProcess_agent_validation.md and the
latest implementation log for exact provenance, numerical errors and artifacts.

Official quick_validate.py is blocked by missing PyYAML. Manual structural/link
checks pass, and behavioral evaluation is recorded separately. This is not a
claimed official skill-validator pass. Fresh normal/smaller screenshots were
inspected; measured sources and original app settings remain intact.
