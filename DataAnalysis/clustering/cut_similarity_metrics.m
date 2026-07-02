function metrics = cut_similarity_metrics(A, B)
%ARRAY_SIMILARITY Compute similarity metrics between two arrays.
%
% Outputs:
%   cosine_similarity
%   pearson_correlation
%   spearman_correlation
%   euclidean_distance
%   euclidean_distance_norm
%   norm_a
%   norm_b
%   norm_ratio
%   mean_a
%   mean_b
%   mean_ratio

    % Check size
    if ~isequal(size(A.value), size(B.value))
        error('A and B must have the same size.');
    end

    % Flatten
    a = double(A.value(:));
    b = double(B.value(:));

    % Remove NaN pairs
    valid = ~isnan(a) & ~isnan(b);
    a = a(valid);
    b = b(valid);

    if isempty(a)
        error('No valid elements remain after removing NaNs.');
    end

    %% Norms
    norm_a = norm(a);
    norm_b = norm(b);

    %% Means
    mean_a = mean(a,"all");
    mean_b = mean(b,"all");

    %% Cosine similarity
    if norm_a == 0 || norm_b == 0
        cosine_similarity = NaN;
    else
        cosine_similarity = dot(a,b) / (norm_a * norm_b);
    end

    %% Euclidean distance
    euclidean_distance = norm(a - b);

    mean_norm = (norm_a + norm_b)/2;

    if mean_norm == 0
        euclidean_distance_norm = NaN;
    else
        euclidean_distance_norm = euclidean_distance / mean_norm;
    end

    %% Pearson correlation
    if numel(a) < 2
        pearson_correlation = NaN;
    else
        C = corrcoef(a,b);
        pearson_correlation = C(1,2);
    end

    %% Spearman correlation
    if numel(a) < 2
        spearman_correlation = NaN;
    else
        spearman_correlation = corr(a,b,'Type','Spearman');
    end

    %% Norm ratio
    if norm_b == 0
        norm_ratio = NaN;
    else
        norm_ratio = norm_a / norm_b;
    end

    %% Mean ratio
    if mean_b == 0
        mean_ratio = NaN;
    else
        mean_ratio = mean_a / mean_b;
    end

    %% Store outputs
    metrics = struct();

    metrics.cosine_similarity      = cosine_similarity;
    metrics.pearson_correlation    = pearson_correlation;
    metrics.spearman_correlation   = spearman_correlation;

    metrics.euclidean_distance     = euclidean_distance;
    metrics.euclidean_distance_norm = euclidean_distance_norm;

    metrics.norm_a                 = norm_a;
    metrics.norm_b                 = norm_b;
    metrics.norm_ratio             = norm_ratio;

    metrics.mean_a                 = mean_a;
    metrics.mean_b                 = mean_b;
    metrics.mean_ratio             = mean_ratio;

    %% Print summary
    fprintf('=========================================\n');
    fprintf(' Similarity Metrics     : %d elements\n', numel(a));
    fprintf('=========================================\n');
    fprintf(' Mean(A)                : %0.6g\n', mean_a);
    fprintf(' Mean(B)                : %0.6g\n', mean_b);
    fprintf(' Mean ratio A/B         : %0.6f\n', mean_ratio);
    fprintf('\n');
    fprintf(' Cosine similarity      : %+0.6f\n', cosine_similarity);
    fprintf(' Pearson correlation    : %+0.6f\n', pearson_correlation);
    fprintf(' Spearman correlation   : %+0.6f\n', spearman_correlation);
    fprintf('\n');
    fprintf(' Norm(A)                : %0.6g\n', norm_a);
    fprintf(' Norm(B)                : %0.6g\n', norm_b);
    fprintf(' Norm(A-B)              : %0.6g\n', euclidean_distance);
    fprintf(' Norm ratio A/B         : %0.6f\n', norm_ratio);
    fprintf(' Normalised distance    : %0.6f\n', euclidean_distance_norm);
    fprintf('=========================================\n\n');

end