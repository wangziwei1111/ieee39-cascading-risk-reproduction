function main_preview_full_event_chain_risk_from_trace()
%MAIN_PREVIEW_FULL_EVENT_CHAIN_RISK_FROM_TRACE Compare selected-only and full-event risk previews.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
chain_path = fullfile(root_dir, 'full_event_reconstruction_from_trace_chain.csv');
summary_path = fullfile(root_dir, 'trace_smoke', 'markov_chain_summary.csv');
out_path = fullfile(root_dir, 'full_event_chain_risk_trace_preview.csv');
if exist(chain_path, 'file') ~= 2 || exist(summary_path, 'file') ~= 2
    error('Missing full-event chain reconstruction or trace summary.');
end
cfg = base_config();
chain_tbl = readtable(chain_path, 'TextType', 'string');
summary = readtable(summary_path, 'TextType', 'string');
if ismember('initial_line_probability', summary.Properties.VariableNames)
    summary.initial_line_probability = [];
end
if ismember('chain_probability_status', summary.Properties.VariableNames)
    summary.chain_probability_status = [];
end
joined = innerjoin(summary, chain_tbl, 'Keys', {'initial_branch', 'trial_id'});

metrics = {'LLR', 'LFOR', 'NVOR', 'CRI'};
rows = {};
for m = 1:numel(metrics)
    metric = metrics{m};
    severity_col = ['basic_', metric];
    if ~ismember(severity_col, joined.Properties.VariableNames)
        continue;
    end
    severity = joined.(severity_col);
    selected_risk = joined.initial_line_probability .* joined.chain_transition_probability_selected_only .* severity ./ 1e-4;
    full_risk = joined.initial_line_probability .* joined.chain_transition_probability_full_event .* severity ./ 1e-4;
    valid = ~isnan(selected_risk) & ~isnan(full_risk);
    for s = 1:numel(cfg.var_confidence_levels)
        sigma = cfg.var_confidence_levels(s);
        selected_var = quantile_no_toolbox(selected_risk(valid), sigma);
        full_var = quantile_no_toolbox(full_risk(valid), sigma);
        rows{end + 1, 1} = table( ... %#ok<AGROW>
            string(metric), sigma, sum(valid), selected_var, full_var, ...
            full_var - selected_var, safe_ratio(full_var - selected_var, selected_var), ...
            mean(selected_risk(valid), 'omitnan'), mean(full_risk(valid), 'omitnan'), ...
            max(selected_risk(valid), [], 'omitnan'), max(full_risk(valid), [], 'omitnan'), ...
            "Small trace smoke only; not compared against paper benchmark and not written to final_summary.", ...
            'VariableNames', {'metric_name', 'sigma', 'valid_sample_count', ...
            'selected_only_var_display', 'full_event_var_display', 'delta', 'relative_delta', ...
            'mean_selected_only_risk_display', 'mean_full_event_risk_display', ...
            'max_selected_only_risk_display', 'max_full_event_risk_display', 'note'});
    end
end
preview = vertcat(rows{:});
writetable(preview, out_path);
fprintf('full-event chain risk preview written: %s\n', out_path);
end

function q = quantile_no_toolbox(x, p)
x = sort(x(:));
if isempty(x), q = NaN; return; end
if numel(x) == 1, q = x(1); return; end
idx = 1 + (numel(x) - 1) * p;
lo = floor(idx);
hi = ceil(idx);
if lo == hi
    q = x(lo);
else
    q = x(lo) + (x(hi) - x(lo)) * (idx - lo);
end
end

function r = safe_ratio(a, b)
if isnan(a) || isnan(b) || b == 0
    r = NaN;
else
    r = a / b;
end
end
