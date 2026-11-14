function [idxMap, U, C, objHist, info] = fcm_cluster_4d(value, k, distMethod, m, maxIter, tol)
%FCM_CLUSTER_4D Compatibility entry point for fuzzy clustering of 4-D data.
%   This wrapper preserves the name used in earlier examples while the
%   implementation lives in the callable, same-named custom_fcm.m API.

    if nargin < 3, distMethod = []; end
    if nargin < 4, m = []; end
    if nargin < 5, maxIter = []; end
    if nargin < 6, tol = []; end
    [idxMap, U, C, objHist, info] = custom_fcm( ...
        value, k, distMethod, m, maxIter, tol);
end
