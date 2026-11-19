# OX_ARPES review report feedback

## Overall opinion

The technical review report is a strong starting point for consolidating OX_ARPES. It explains the intended workflow and the roles of the data types, loaders, analysis routines, and GUI; it also separates high-priority correctness concerns from later maintainability and distribution work. The issue table is concrete, with source locations, impact, and suggested remedies. The report is appropriately candid that it was a static review and that scientific constants still need experimental validation.

The working log is useful as a record of a separate repair pass. It describes API, loader, analysis, and test changes in detail. Its main limitation is verification: it says the MATLAB tests were added but could not be run. Those changes and tests should therefore be treated as an implementation proposal awaiting execution and scientific checks, rather than evidence that the repaired package is already validated.

## Feedback on the review report

- Keep the staged approach. Agree on data contracts and loader behavior first, then stabilize and test the existing operations before broader refactoring.
- Make the reviewed source snapshot easy to identify and reproduce. The report records a commit and date, but also says the tree was already dirty. A file list or source archive/hash would make it clearer which exact versions each finding describes.
- Separate confirmed source defects from behavior that depends on real beamline files, MATLAB release, or toolbox availability. The report mostly does this well; this distinction should remain visible when findings are carried into an issue list.
- Treat the proposed array order and metadata schema as decisions for maintainers to approve. The report correctly identifies inconsistent dimensions and metadata as risks, but choosing a canonical convention affects every loader and downstream app.
- Keep scientific validation distinct from software tests. Synthetic tests can establish dimensional behavior and deterministic transformations, but reference scans and beamline owners are needed to validate offsets, work functions, calibration constants, and physical conventions.
- Add the exact MATLAB release and toolbox requirements once they are established. The report identifies these as missing, but the worklog's claims should be checked against the package rather than assumed to fill the gap.
- The GUI exclusion is reasonable for the initial static review. It leaves an important part of the user workflow unassessed, so a later GUI review should be planned after the data and loader API is stable.

## Scope and snapshot caution

The canonical editable target for this consolidation is now `OX_ARPES_AI/OX_ARPES`, as requested. The other `OX_ARPES` checkout is a separate copy and is out of scope. Earlier repairs and review observations originated from different snapshots, so this feedback should be read alongside the consolidation worklog, which records what was inspected and changed in the canonical copy. Existing edits already present in the canonical copy were preserved.

## Findings recorded in the source review

These findings describe the source snapshot assessed by the original review and are static observations; MATLAB was not run and representative facility files were not checked. Their current status in the canonical editable copy is summarized in `Consolidation_Worklog.md`.

1. `DataType/OxA_MAP.m`: `kconvert` leaves the off-centre angular-range plus nonzero-azimuth branch as “omitted for brevity”. Its momentum-grid bounds and sizes are then unset, so that case cannot complete.
2. `DataType/OxArpes_4D_Data.m`: the properties and constructor suggest `value(x,y,z,k)`, but `block_reduce` indexes the value array as `(x,y,k,z)`. This can mix the energy and momentum/angle axes without an obvious error.
3. `DataType/OxArpes_3D_Data.m`: `Z_Gaussian_smoothen` loops over the third-dimension planes and applies a 2-D kernel within each plane; that does not smooth along `z`, despite the method name.
4. `DataType/OxA_RSImage.m`: `method1` refers to `obj.Property1`, which is not declared by the class. Calling this placeholder will fail.
5. `DataLoader/loader_UI.m`: the `.mat` path is assembled into an `evalin` string. A filename containing quote or MATLAB syntax characters can be interpreted as code. A direct `load` with a returned struct would avoid that evaluation path.
6. `DataLoader/loader_UI.m`: ambiguous `.zip`, `.h5`, `.nxs`, and `.krx` files are identified by trying loaders and catching every exception. This can hide corruption, missing dependencies, and real loader defects as if they were format mismatches.
7. `DataLoader/loader_UI.m`: it always creates a waitbar and assigns results into the base workspace, has no output argument, and silently returns for an invalid path. That makes it difficult to use from scripts, headless runs, or other applications.
8. Several format-specific loaders return `[]` for unsupported or unrecognized data shapes and then immediately access `DATA.info` or `DATA.value`. Those paths fail indirectly instead of reporting a clear unsupported-format/dimension error. This pattern appears in `load_ALS_h5.m`, `load_Elettra_Spectromicroscopy.m`, `load_PSI_ULTRA.m`, and `load_SSRL_BL52.m`.
9. `load_SSRL_BL52.m` assigns `DATA.info.beamline` from the file location and then overwrites that same field with the creation time. The second value appears to belong in a separate creation-time field.
10. `DataLoader/load_ALBA_krx.m` can read multiple images when `v_3Dflag` is set, but still wraps the resulting 3-D array in `OxA_CUT`. Confirm the intended multi-image class and axis meaning before relying on that option.
11. `DataLoader/load_DLS_io5_nano.m`, `load_PSI_ULTRA.m`, and `load_Elettra_Spectromicroscopy.m` have unsupported-data branches that leave `DATA` empty before later metadata assignments. Unsupported scan types therefore fail through a secondary field-access error.
12. `DataType/OxArpes_3D_Data.m`: `VolumeViewer` catches all errors without reporting them, so missing toolboxes, invalid data, or viewer failures are silently hidden.
13. `DataLoader/load_ALBA_LOREA.m` uses a catch-all around its first 3-D schema path and treats any error as evidence for a second schema. A malformed file or programming error can therefore be misclassified.

Several findings above have since been addressed in the canonical copy. KRX multi-image interpretation remains unchanged because the axis meaning requires representative beamline data for confirmation. Scientific calibration and behavior against real facility files remain to be validated.

## DataLoader review and improvement path

The existing `loader_UI.m` is a compatibility-oriented UI entry point; the separate `load_*` functions perform facility-specific parsing. I recommend a three-layer design for the next phase:

1. **Format-specific readers** accept a path and return a data object (or a clear, identified error). Keep file parsing and metadata extraction here.
2. **A programmatic dispatcher** accepts a path or list of paths and optional format hints, returns objects plus per-file diagnostics, and does not show UI or write to the base workspace. It can use lightweight metadata probes for ambiguous formats and preserve causes when a selected reader fails.
3. **A UI wrapper** chooses files, displays progress, and optionally assigns returned objects into the workspace for interactive compatibility. GUI progress and cancellation should be options so the same loader pipeline can run headlessly.

Additional improvements to consider after behavior is documented:

- Normalize extensions and input paths; validate scalar path, string, character-vector, and list inputs consistently.
- Return stable result shapes for one file and many files, and report partial success without discarding other successfully loaded files.
- Replace broad `catch` fallback with schema probes or narrowly recognized format-mismatch errors; retain the original exception chain in diagnostics.
- Replace `evalin` for MAT files with a normal load and explicit choice of which variable/data object to return.
- Define how the dispatcher handles unsupported extensions, malformed files, missing optional dependencies, and unsupported scan dimensionality.
- Standardize metadata names and units at the loader boundary while retaining original headers for provenance.
- Use `onCleanup` for file handles and temporary extraction directories; include the source path and loader name in returned provenance.
- Add small, redistributable fixtures or synthetic header-only fixtures per format before changing dispatch behavior.

## GUI and `.mlapp` recommendation

`.mlapp` files are App Designer packages, not plain `.m` source files. They can often be opened and edited in MATLAB's App Designer, and their packaged content can be inspected, but directly editing the internal archive/XML is brittle and can corrupt the app. Given that MATLAB startup is currently failing in this environment, I would not make binary edits to the `.mlapp` files here.

For partially complete apps, first inventory each app's purpose, launch path, callbacks, and dependencies. Then move reusable loading and processing behavior into ordinary MATLAB functions/classes, leaving the app callbacks thin: collect UI inputs, call the shared API, and render outputs. This lets command-line workflows and automated tests exercise the same behavior without needing to drive the GUI. Once the loader and data contracts settle, open each `.mlapp` in App Designer, make focused edits through the supported editor, and validate launch, callbacks, errors, and representative datasets in MATLAB. If source-controlled review is important, consider extracting app logic into `.m` files and keeping only the layout/callback shell in the `.mlapp`.

## Suggested consolidation order

1. Decide which package tree is the canonical source and capture both trees' current changes.
2. Approve the axis, value-array, and metadata conventions.
3. Compare the worklog's repaired copy against the editable checkout and merge changes selectively.
4. Add comments and stable help text without mixing in algorithm changes.
5. Separate programmatic loading from UI effects and agree on return/error contracts.
6. Run the synthetic test suite in MATLAB, then validate loaders and scientific conversions with trusted representative data.
7. Review and improve the `.mlapp` apps against the stabilized APIs.
