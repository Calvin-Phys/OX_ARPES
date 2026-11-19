# Data Process entry point and documentation portability

Date: 19 November 2026.

## Maintained entry point

`GUI/OxArpes_DataProcess.m` is now the maintained app. The class declaration,
constructor, static method references, `ox_data_process_agent` type checks,
focused tests, README, and operation skill use `OxArpes_DataProcess`.
The old `_exported` entry point was removed rather than retained as an alias.

The App Designer file was renamed to
`GUI/OxArpes_DataProcess_legacy.mlapp`. Its binary contents were verified
unchanged during the rename; no packaged app internals were edited. With the
GUI directory on the path, the unsuffixed name resolves to the maintained
`.m` implementation in a clean MATLAB process.

Already-open app instances retain loaded code. Preserve the user's data and
figures; do not clear all classes or close unrelated windows. If MATLAB has a
cached legacy definition, close the relevant app instances, selectively clear
`OxArpes_DataProcess`, run `rehash`, and relaunch when safe for the active task.

## Portable documentation and tests

Removed personal absolute paths, recorded process IDs, measurement filenames,
workspace acquisition IDs, and unique run prefixes from the documentation and
operation examples. Historical measured-data results retain their numerical
values, test dates, and limitations, with role aliases clearly identified.
The external historical harness/artifact directory is no longer represented
as a location available to other users.

The checked-in test sources were already synthetic and resolved paths from
their location or `tempname`. Their app references now use the maintained
class; [tests/README.md](../tests/README.md) explains fixture scope and execution.
Numerical fixtures and class/error identifiers remain unchanged.

Five illustrations were regenerated from synthetic data: the compact 2-D and
3-D panels, small scrollable panel, central-slice preview, and nonuniform-axis
preview. The measured preview with a unique run title was removed; its new
counterpart is [data_process_agent_3d.png](data_process_agent_3d.png).
These are current synthetic illustrations, not replacement evidence for the
historical 97-check measured-data evaluation.

## Verification

An isolated MATLAB R2024a process verified `.m` path resolution, constructor and
agent-facade operation, and absence of the old `_exported` entry point.
`TestDataProcess` passed **14 tests, 0 failed, 0 incomplete**. The focused run
left `lastwarn` empty. Code Analyzer reported zero notices on the maintained
app, agent facade, and focused test class. Regenerated screenshots were visually
inspected and contain only synthetic role names.

Documentation links, skill metadata, remaining class-name references, and
path/measurement-identifier scans were checked separately. Unrelated suites and
measured-data validation were not rerun; the test counts in older records are
historical. The user's live MATLAB workspace and app windows were not changed
by this verification.
