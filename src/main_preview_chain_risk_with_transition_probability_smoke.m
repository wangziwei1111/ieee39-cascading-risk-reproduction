function main_preview_chain_risk_with_transition_probability_smoke()
%MAIN_PREVIEW_CHAIN_RISK_WITH_TRANSITION_PROBABILITY_SMOKE Preview risk samples using traced transition probability.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

smoke_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability', 'trace_smoke');
summary_path = fullfile(smoke_dir, 'markov_chain_summary.csv');
out_path = fullfile(project_root, 'results', 'calibration', 'transition_probability', ...
    'chain_risk_with_transition_probability_smoke_preview.csv');
if exist(summary_path, 'file') ~= 2
    error('Missing trace smoke summary: %s', summary_path);
end

cfg = base_config();
summary = readtable(summary_path);
metrics = {'LLR', 'LFOR', 'NVOR', 'CRI'};
conf_levels = cfg.var_confidence_levels(:)';
rows = {};
for m = 1:numel(metrics)
    metric = metrics{m};
    severity_col = ['basic_', metric];
    if ~ismember(severity_col, summary.Properties.VariableNames)
        continue;
    end
    severity = summary.(severity_col);
    p_transition = summary.chain_transition_probability;
    p_initial = summary.initial_line_probability;
    p_total = p_initial .* p_transition;
    risk_samples = p_total .* severity;
    risk_display = risk_samples ./ 1e-4;
    valid = ~isnan(risk_display);
    for c = 1:numel(conf_levels)
        sigma = conf_levels(c);
        rows{end + 1, 1} = table( ... %#ok<AGROW>
            string(metric), sigma, sum(valid), ...
            quantile_no_toolbox(risk_display(valid), sigma), ...
            mean(risk_display(valid), 'omitnan'), ...
            max(risk_display(valid), [], 'omitnan'), ...
            "selected_only_transition_probability_smoke", ...
            "Diagnostic smoke only; validates probability fields and is not a formal paper benchmark.", ...
            'VariableNames', {'metric_name', 'var_confidence_level', 'valid_sample_count', ...
            'risk_var_display', 'mean_risk_display', 'max_risk_display', ...
            'probability_basis', 'note'});
    end
end

if isempty(rows)
    preview = table();
else
    preview = vertcat(rows{:});
end
writetable(preview, out_path);
fprintf('chain risk transition probability smoke preview written: %s\n', out_path);
end

function q = quantile_no_toolbox(x, p)
x = sort(x(:));
if isempty(x)
    q = NaN;
    return;
end
if numel(x) == 1
    q = x(1);
    return;
end
idx = 1 + (numel(x) - 1) * p;
lo = floor(idx);
hi = ceil(idx);
if lo == hi
    q = x(lo);
else
    q = x(lo) + (x(hi) - x(lo)) * (idx - lo);
end
end
