%TEST_I05_178742 Run PCA clustering for the i05 178742 data set.
%   Requires i05_178742 to be present in the MATLAB workspace. The resulting
%   PCA and clustering structure can then be used by test2.m to render the
%   corresponding multi-panel figure.

i05_178742_RD = i05_178742.block_reduce(1, 1, 4, 4);
result = PCA_cluster(i05_178742_RD, 'TargetVariance', 95, 'KList', 2:15);
visualize_PCA_cluster(i05_178742_RD, result, 5);
