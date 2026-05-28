function main_test_ols_dispatchable_load_cases()
%MAIN_TEST_OLS_DISPATCHABLE_LOAD_CASES Compare OLS formulations on exported failures.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
sign_path = fullfile(table_dir, 'dispatchable_load_sign_convention_test.csv');
must_exist(sign_path);
sign_tbl = readtable(sign_path);
if any(string(sign_tbl.status) == "fail")
    error('Dispatchable-load sign convention failed; stop before case tests.');
end

case_index = readtable(fullfile(table_dir, 'ols_failure_case_index.csv'));
cfg0 = base_config();
require_matpower(cfg0);

variants = { ...
    struct('formulation', "positive_injection_generator", 'q_mode', "free_q"), ...
    struct('formulation', "positive_injection_generator", 'q_mode', "fixed_zero_q"), ...
    struct('formulation', "dispatchable_load", 'q_mode', "variable_absorption"), ...
    struct('formulation', "dispatchable_load", 'q_mode', "constant_pf_after_apply")};

rows = {};
for i = 1:height(case_index)
    case_dir = char(string(case_index.case_dir(i)));
    data = load(fullfile(case_dir, 'mpc_before_ols.mat'), 'mpc_before', 'cumulative_load_shed_mw');
    for v = 1:numel(variants)
        cfg = configure_variant(cfg0, variants{v});
        [~, ~, ~, detail] = solve_paper_ols_load_shedding(data.mpc_before, cfg, data.cumulative_load_shed_mw);
        rows{end + 1, 1} = table(string(case_index.case_export_id(i)), string(case_index.scenario_id(i)), ...
            case_index.initial_branch(i), case_index.trial_id(i), case_index.stage_id(i), ...
            variants{v}.formulation, variants{v}.q_mode, logical(detail.opf_success), ...
            logical(detail.pf_success_after_apply), detail.objective_load_shed_mw, ...
            detail.served_load_mw, detail.shed_load_mw, detail.max_positive_q_injection, ...
            detail.q_mismatch_between_opf_and_applied, detail.max_line_loading_after_apply, ...
            detail.min_voltage_after_apply, detail.max_voltage_after_apply, ...
            string(detail.diagnosis_failure_type), string(detail.message), ...
            'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
            'trial_id', 'stage_id', 'formulation', 'q_mode', 'opf_success', ...
            'pf_success_after_apply', 'objective_load_shed_mw', 'served_load_mw', ...
            'shed_load_mw', 'max_positive_q_injection', ...
            'q_mismatch_between_opf_and_applied', 'max_line_loading_after', ...
            'min_voltage_after', 'max_voltage_after', 'failure_type', 'message'}); %#ok<AGROW>
    end
end

case_test = vertcat(rows{:});
summary = summarize_case_test(case_test);
save_result_table(case_test, fullfile(table_dir, 'ols_dispatchable_load_case_test.csv'), true);
save_result_table(summary, fullfile(table_dir, 'ols_dispatchable_load_case_summary.csv'), true);
fprintf('dispatchable-load case test written: %s\n', fullfile(table_dir, 'ols_dispatchable_load_case_test.csv'));
end

function cfg = configure_variant(cfg0, variant)
cfg = cfg0;
cfg.paper_ols_formulation = char(variant.formulation);
if variant.formulation == "dispatchable_load"
    cfg.paper_ols_dispatchable_load_q_mode = char(variant.q_mode);
else
    cfg.paper_ols_shed_gen_q_mode = char(variant.q_mode);
end
cfg.paper_ols_relax_voltage_limits = false;
cfg.paper_ols_rate_limit_relax_factor = 1.0;
cfg.paper_ols_apply_solution_mode = 'load_only';
cfg.paper_ols_enable = true;
end

function summary = summarize_case_test(case_test)
groups = unique(strcat(string(case_test.formulation), "|", string(case_test.q_mode)), 'stable');
rows = {};
for i = 1:numel(groups)
    parts = split(groups(i), "|");
    rows_i = case_test(string(case_test.formulation) == parts(1) & string(case_test.q_mode) == parts(2), :);
    test_case_count = height(rows_i);
    opf_success_count = sum(rows_i.opf_success);
    pf_success_after_apply_count = sum(rows_i.pf_success_after_apply);
    opf_success_but_pf_failed_count = sum(rows_i.opf_success & ~rows_i.pf_success_after_apply);
    success_rate = pf_success_after_apply_count / max(test_case_count, 1);
    recommendation = "diagnostic_only";
    if parts(1) == "dispatchable_load" && success_rate > 0.5
        recommendation = "candidate_for_next_diagnostic_smoke";
    elseif parts(1) == "dispatchable_load"
        recommendation = "not_ready_for_formal_benchmark";
    end
    rows{end + 1, 1} = table(parts(1), parts(2), test_case_count, opf_success_count, ...
        pf_success_after_apply_count, opf_success_but_pf_failed_count, ...
        mean(rows_i.objective_load_shed_mw, 'omitnan'), ...
        mean(rows_i.q_mismatch_between_opf_and_applied, 'omitnan'), ...
        max(rows_i.max_positive_q_injection, [], 'omitnan'), success_rate, recommendation, ...
        'VariableNames', {'formulation', 'q_mode', 'test_case_count', ...
        'opf_success_count', 'pf_success_after_apply_count', ...
        'opf_success_but_pf_failed_count', 'mean_objective_load_shed_mw', ...
        'mean_q_mismatch', 'max_positive_q_injection', 'success_rate', 'recommendation'}); %#ok<AGROW>
end
summary = vertcat(rows{:});
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end
