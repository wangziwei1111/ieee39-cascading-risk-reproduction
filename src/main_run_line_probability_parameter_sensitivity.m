function main_run_line_probability_parameter_sensitivity()
%MAIN_RUN_LINE_PROBABILITY_PARAMETER_SENSITIVITY Recompute P_L on fixed candidates.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'outage');
candidate_path = fullfile(out_root, 'line_probability_diagnostic_smoke', 'candidate_probability_comparison.csv');
if ~exist(candidate_path, 'file')
    error('Run main_run_line_probability_diagnostic_smoke first: %s', candidate_path);
end
candidates = readtable(candidate_path, 'TextType', 'string');
param_sets = readtable(fullfile(project_root, 'paper_inputs', 'filled', ...
    'paper_line_probability_parameter_sets.csv'), 'TextType', 'string');
cfg0 = base_config();
base_mpc = build_case39_base(cfg0);

detail_rows = {};
summary_rows = {};
for s = 1:height(param_sets)
    ps = param_sets.parameter_set_id(s);
    cfg = load_paper_line_probability_parameter_set(cfg0, ps);
    cfg.paper_line_missing_param_policy = 'fallback_to_engineering_with_warning';
    p = NaN(height(candidates), 1);
    status = strings(height(candidates), 1);
    cal = repmat(string(cfg.paper_line_parameter_calibration_status), height(candidates), 1);
    for i = 1:height(candidates)
        branch_idx = candidates.candidate_branch(i);
        branch_row = [base_mpc.branch(branch_idx, :), branch_idx];
        [p(i), d] = compute_paper_line_outage_probability(candidates.line_loading_pu(i), branch_row, cfg, ...
            'branch_index', branch_idx, 'fallback_probability', candidates.engineering_probability(i));
        status(i) = string(d.status);
        detail_rows{end+1,1} = table(ps, candidates.initial_branch(i), candidates.trial_id(i), ...
            candidates.stage_id(i), branch_idx, candidates.line_loading_pu(i), ...
            candidates.engineering_probability(i), p(i), abs(p(i) - candidates.engineering_probability(i)), ...
            status(i), cal(i), ...
            'VariableNames', {'parameter_set_id', 'initial_branch', 'trial_id', ...
            'stage_id', 'candidate_branch', 'line_loading_pu', ...
            'engineering_probability', 'paper_formula_probability', 'abs_diff', ...
            'status', 'calibration_status'}); %#ok<AGROW>
    end
    abs_diff = abs(p - candidates.engineering_probability);
    fallback_count = sum(contains(status, "missing_parameter"));
    note = "diagnostic parameter set; not calibrated paper value";
    summary_rows{end+1,1} = table(ps, height(candidates), sum(~isnan(p)), fallback_count, ...
        mean(p, 'omitnan'), prctile(p, 50), prctile(p, 95), max(p, [], 'omitnan'), ...
        mean(abs_diff, 'omitnan'), prctile(abs_diff, 95), ...
        string(cfg.paper_line_parameter_calibration_status), note, ...
        'VariableNames', {'parameter_set_id', 'candidate_count', ...
        'valid_probability_count', 'missing_or_fallback_count', ...
        'mean_probability', 'p50_probability', 'p95_probability', 'max_probability', ...
        'mean_abs_diff_vs_engineering', 'p95_abs_diff_vs_engineering', ...
        'calibration_status', 'note'}); %#ok<AGROW>
end

details = vertcat(detail_rows{:});
summary = vertcat(summary_rows{:});
writetable(details, fullfile(out_root, 'line_probability_candidate_sensitivity_details.csv'));
writetable(summary, fullfile(out_root, 'line_probability_parameter_sensitivity.csv'));
fprintf('line probability parameter sensitivity written: %s\n', out_root);
end
