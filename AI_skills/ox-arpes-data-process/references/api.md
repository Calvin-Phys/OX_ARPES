# Processing actions and scientific conventions

All inputs must be scalar `OxArpes_2D_Data` / `OxArpes_3D_Data` value objects or
their subclasses, with valid axes, shape, and finite real intensities. Class
identity defines dimensionality, including singleton Z axes. 1-D and 4-D data
are outside this app's scope. Unknown option fields are rejected.

| Action | Options and defaults | Output suffix / axes |
|---|---|---|
| `truncate` | `Bounds = {'Min','Max';'Min','Max';'Min','Max'}`, `Scale = 'coordinates'` | `_tk`; X/Y/(Z) |
| `smooth` | `Sigma = [3 3]` samples | `_sm`; X/Y in 2-D, Y/Z at each X in 3-D |
| `derivative` | `Sigma = [3 3]` samples | `_d2x`, `_d2y`; X/Y in 2-D, **Y/Z in 3-D** |
| `zsmooth` | `SigmaZ = 5` samples | `_zsm`; dimension 3 only; 3-D required |
| `normalise` | `Direction = 'X'`, `Peak = false`, `Bounds = {'Min','Max'}`, `Scale = 'coordinates'` | `_<direction>_snor` |
| `reduce` | `Factors = [1 1 1]` samples per X/Y/Z block; 2-D ignores Z | `_rd`; actual X/Y/(Z) dimensions |
| `median` | `Window = 5`, `Axis = 1` for 2-D / `2` for 3-D | `_rmspk`; selected array dimension |

`Sigma` must contain two positive finite standard deviations. The existing
Gaussian implementations use reflected padding and a radius `ceil(3.5*sigma)`;
each filtered axis must contain at least two samples and at least that radius.
The plane kernel is limited to two million elements to prevent accidental huge
allocations. Z-only smoothing retains the existing normalised 1-D convolution
with edge-weight correction; its kernel has the same element limit.

Second derivatives retain the existing **negative second differences** following
Gaussian smoothing, in **sample units**, without physical axis-spacing scaling.
The legacy suffix names remain for compatibility. In 3-D the first is along Y
and the second along Z; inspect `Details.Axes = 'YZ'`. No derivative sign,
energy convention, momentum coordinate, or metadata conversion is introduced.

## Ranges and normalisation

Bounds are cell arrays of finite scalar numbers or numeric strings, or the
case-insensitive tokens `Min` / `Max`. Expressions such as `1+2` are rejected.
`Scale` can be `coordinates` or `indices`. Coordinate entries use the data's
existing units and snap to the nearest sample, clamping outside the available
axis. Min/Max select coordinate extrema. Index entries must be integers from
1 to the axis length; Min/Max mean first/last indices. Paired indices are sorted,
so reversed bounds and descending coordinates produce a nonempty inclusive
region. A singleton region is permitted.

Crop Bounds have one row per active X/Y/Z axis. A third row is deliberately
ignored for 2-D inputs. Normalisation Bounds have one pair for X, Y, or Z.
2-D normalisation supports X or Y; 3-D also supports XY, XZ, and YZ. Plane
directions reduce over the **whole plane** and deliberately ignore Bounds/Scale.
The app disables those region controls in plane mode. Values remain in the
controls for return to axis mode and are validated on use.

Normalisation divides the **whole** profile by its mean (`Peak = false`) or
maximum (`Peak = true`) within the reference region. Negative nonzero divisors
retain their mathematical sign. Zero/nonfinite divisors and overflow fail before
any workspace assignment. Integer/logical intensities are converted to double.

Median windows are positive integers no larger than the selected axis, with
the original `medfilt1` zero-padding and even-window behaviour. Signal Processing
Toolbox is required. GUI axis choices preserve the original mapping: 2-D X/Y,
3-D Y/Z. The API accepts any actual dimension, including X for 3-D.

## Ownership and lifecycle

The numerical function never assigns variables or plots. The workspace adapter
creates collision-safe outputs by default; explicit overwrite is opt-in and
cannot replace the source. Refresh and processing retain the input selection
and control settings. Switching from a 3-D-only normalisation choice to 2-D
selects X; returning to 3-D retains X until explicitly changed.

Every preview call creates a new figure tagged `OxArpes_DataProcess_Preview`.
It does not clear, reuse, or restyle user figures or root defaults. Surface cells
follow coordinate midpoints; singleton cells use a display width of one existing
coordinate unit. 3-D previews take `ceil(N/2)` in each axis. Figure titles record
the slice coordinate/index. No graphical export API is introduced.


## Block reduction

The class method is **`block_reduce`** (not `block_reduction`). The backend
`reduce` action calls it directly with the active factors, without duplicating
its averaging formula. Factors must be positive finite integers no larger than
the corresponding axis. For 2-D, supply two or three entries; the inactive third
entry is ignored. For 3-D, supply three entries, including 1 for singleton axes.
Defaults are all ones. Output lengths are `floor(axisLength/factor)`. Values
and coordinates are means of contiguous non-overlapping blocks, not sums.
Incomplete trailing blocks are discarded, preserving axis direction and
metadata/class. `Details.Options.Factors` contains the active factors and
`Details.DroppedSamples` gives discarded counts in X/Y/Z order. The new workspace
name uses `_rd`, with numeric suffixes on collision.

## Agent facade requests

All requests are scalar structs; field names are case sensitive. `App` is an
optional explicit live `OxArpes_DataProcess` handle. If omitted, a
single existing panel is reused; multiple panels require explicit selection.

| Action | Request fields | Return / effects |
|---|---|---|
| `list` | None | Table Name/Class/Size; compatible scalar 2-D/3-D workspace objects, no panel |
| `open` | App | State; raise existing panel preserving values or create when none exists |
| `read` | App | State; no creation, refresh or reset |
| `refresh` | App | State; list refreshed, existing selection/settings retained |
| `select` | SourceName, App | State; validate one existing compatible name before changing selection |
| `resetcrop` | App | State; crop bounds become Min/Max; mode and all other settings retained |
| `preview` | SourceName (optional), App | New figure; explicit source selects it first |
| `process` | Operation; Parameters, SourceName, OutputNames, Overwrite, App (optional) | Workspace adapter report; refresh existing panel, retain selection |

All GUI actions except `open` require a live panel. `process` with an explicit
source can run without a panel. Omitted processing Parameters uses defaults from
the action table above, never implicitly the GUI controls. To process with those
controls, pass `read.Parameters.(operation)`. An explicit processing source does
not change the selection. State also returns App/Figure handles, Selected,
Available, Parameters per operation, Status and measured ColumnWidths. No
configure/update defaults are hidden in read/open.
