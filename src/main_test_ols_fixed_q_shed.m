function main_test_ols_fixed_q_shed()
%MAIN_TEST_OLS_FIXED_Q_SHED Compare free-Q and fixed-zero-Q shed generators.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
index_path = fullfile(table_dir, 'ols_failure_case_index.csv');
if ~exist(index_path, 'file')
    error('Missing exported failure case index: %s', index_path);
end
case_index = readtable(index_path);
cfg0 = base_config();
require_matpower(cfg0);

q_modes = ["free_q", "fixed_zero_q"];
rows = {};
for i = 1:height(case_index)
    case_dir = string(case_index.case_dir(i));
    loaded = load(fullfile(case_dir, 'mpc_before_ols.mat'), 'mpc_before', 'cumulative_load_shed_mw');
    for q = 1:numel(q_modes)
        cfg = cfg0;
        cfg.paper_ols_formulation = 'positive_injection_generator';
        cfg.paper_ols_shed_gen_q_mode = char(q_modes(q));
        cfg.paper_ols_relax_voltage_limits = false;
        cfg.paper_ols_rate_limit_relax_factor = 1.0;
        cfg.paper_ols_apply_solution_mode = 'load_only';
        [~, ~, ~, detail] = solve_paper_ols_load_shedding( ...
            loaded.mpc_before, cfg, loaded.cumulative_load_shed_mw);
        rows{end + 1, 1} = table(string(case_index.case_export_id(i)), ...
            string(case_index.scenario_id(i)), case_index.initial_branch(i), ...
            case_index.trial_id(i), case_index.stage_id(i), ...
            string(cfg.paper_ols_formulation), q_modes(q), logical(detail.opf_success), ...
            logical(detail.pf_success_after_apply), detail.objective_load_shed_mw, ...
            detail.shed_gen_qg_sum, detail.max_abs_shed_gen_qg, ...
            detail.shed_q_applied_sum, detail.q_mismatch_between_opf_and_applied, ...
            detail.max_line_loading_after_apply, detail.min_voltage_after_apply, ...
            detail.max_voltage_after_apply, string(detail.diagnosis_failure_type), ...
            string(detail.message), ...
            'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
            'trial_id', 'stage_id', 'formulation', 'shed_gen_q_mode', ...
            'opf_success', 'pf_success_after_apply', 'objective_load_shed_mw', ...
            'shed_gen_qg_sum', 'max_abs_shed_gen_qg', 'shed_q_applied_sum', ...
            'q_mismatch_between_opf_and_applied', 'max_line_loading_after', ...
            'min_voltage_after', 'max_voltage_after', 'failure_type', 'message'}); %#ok<AGROW>
    end
end

test_table = vertcat(rows{:});
writetable(test_table, fullfile(table_dir, 'ols_fixed_q_shed_test.csv'));
summary = build_summary(test_table);
writetable(summary, fullfile(table_dir, 'ols_fixed_q_shed_summary.csv'));
plot_ols_benchmark_smoke_figures(root_dir);
fprintf('OLS fixed-Q shed test written: %s\n', fullfile(table_dir, 'ols_fixed_q_shed_test.csv'));
end

function summary = build_summary(test_table)
modes = unique(string(test_table.shed_gen_q_mode), 'stable');
rows = {};
for i = 1:numel(modes)
    sub = test_table(string(test_table.shed_gen_q_mode) == modes(i), :);
    test_case_count = height(sub);
    opf_success_count = sum(logical(sub.opf_success));
    pf_success_after_apply_count = sum(logical(sub.pf_success_after_apply));
    opf_success_but_pf_failed_count = sum(logical(sub.opf_success) & ~logical(sub.pf_success_after_apply));
    mean_q_mismatch = mean(sub.q_mismatch_between_opf_and_applied, 'omitnan');
    max_q_mismatch = max(sub.q_mismatch_between_opf_and_applied, [], 'omitnan');
    mean_objective_load_shed_mw = mean(sub.objective_load_shed_mw, 'omitnan');
    success_rate = pf_success_after_apply_count / max(test_case_count, 1);
    recommendation = recommend(modes(i), summary_metric(test_table, "free_q"), ...
        summary_metric(test_table, "fixed_zero_q"));
    rows{end + 1, 1} = table("positive_injection_generator", modes(i), ...
        test_case_count, opf_success_count, pf_success_after_apply_count, ...
        opf_success_but_pf_failed_count, mean_q_mismatch, max_q_mismatch, ...
        mean_objective_load_shed_mw, success_rate, recommendation, ...
        'VariableNames', {'formulation', 'shed_gen_q_mode', 'test_case_count', ...
        'opf_success_count', 'pf_success_after_apply_count', ...
        'opf_success_but_pf_failed_count', 'mean_q_mismatch', 'max_q_mismatch', ...
        'mean_objective_load_shed_mw', 'success_rate', 'recommendation'}); %#ok<AGROW>
end
summary = vertcat(rows{:});
end

function metric = summary_metric(tbl, mode)
sub = tbl(string(tbl.shed_gen_q_mode) == mode, :);
metric.success_rate = mean(logical(sub.pf_success_after_apply), 'omitnan');
metric.mean_q_mismatch = mean(sub.q_mismatch_between_opf_and_applied, 'omitnan');
end

function txt = recommend(mode, free_metric, fixed_metric)
if mode == "fixed_zero_q"
    if fixed_metric.mean_q_mismatch < free_metric.mean_q_mismatch && ...
            fixed_metric.success_rate <= free_metric.success_rate
        txt = "fixed_zero_q lowers Q mismatch but does not improve PF success in exported failures.";
    elseif fixed_metric.success_rate > free_metric.success_rate
        txt = "fixed_zero_q improves PF success in exported failures; consider a separate smoke rerun.";
    else
        txt = "fixed_zero_q does not improve this exported failure set.";
    end
else
    txt = "baseline free_q diagnostic.";
end
end
