function main_test_ols_solver_robustness()
%MAIN_TEST_OLS_SOLVER_ROBUSTNESS Run diagnostic-only OLS robustness tests.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
if ~exist(table_dir, 'dir'), mkdir(table_dir); end

diagnosis_path = fullfile(table_dir, 'ols_failure_diagnosis.csv');
if ~exist(diagnosis_path, 'file')
    error('Run main_diagnose_ols_failures before robustness test.');
end
diagnosis = readtable(diagnosis_path);
if isempty(diagnosis)
    robustness = empty_robustness_table();
    writetable(robustness, fullfile(table_dir, 'ols_solver_robustness_test.csv'));
    return;
end

failed_cases = diagnosis(1:min(5, height(diagnosis)), :);
settings = build_settings();
cfg0 = base_config();
require_matpower(cfg0);

rows = {};
for c = 1:height(failed_cases)
    case_row = failed_cases(c, :);
    [mpc_before, cumulative_load_shed_mw] = reconstruct_stage_case(project_root, root_dir, cfg0, case_row);
    for k = 1:numel(settings)
        cfg = cfg0;
        cfg.paper_ols_enable = true;
        cfg.load_shedding_mode = 'paper_ols';
        cfg.paper_ols_fail_policy = 'strict_error';
        cfg.paper_ols_relax_voltage_limits = settings(k).relax_voltage;
        cfg.paper_ols_rate_limit_relax_factor = settings(k).rate_factor;
        [~, pf_result, ~, detail] = solve_paper_ols_load_shedding(mpc_before, cfg, cumulative_load_shed_mw);
        if isstruct(pf_result) && isfield(pf_result, 'success') && pf_result.success
            violations = check_violations(pf_result, cfg);
            max_line_loading_after = violations.max_line_loading_pu;
            min_voltage_after = min(pf_result.bus(:, 8));
            max_voltage_after = max(pf_result.bus(:, 8));
        else
            max_line_loading_after = NaN;
            min_voltage_after = NaN;
            max_voltage_after = NaN;
        end
        rows{end + 1, 1} = table(c, string(case_row.scenario_id), case_row.initial_branch, ...
            case_row.trial_id, case_row.stage_id, string(settings(k).name), ...
            logical(detail.opf_success), logical(detail.pf_success_after_apply), ...
            detail.objective_load_shed_mw, max_line_loading_after, min_voltage_after, ...
            max_voltage_after, string(detail.diagnosis_failure_type), string(detail.message), ...
            'VariableNames', {'test_case_id', 'scenario_id', 'initial_branch', ...
            'trial_id', 'stage_id', 'setting_name', 'opf_success', ...
            'pf_success_after_apply', 'objective_load_shed_mw', ...
            'max_line_loading_after', 'min_voltage_after', 'max_voltage_after', ...
            'failure_type', 'message'}); %#ok<AGROW>
    end
end

robustness = vertcat(rows{:});
writetable(robustness, fullfile(table_dir, 'ols_solver_robustness_test.csv'));
plot_ols_benchmark_smoke_figures(root_dir);
fprintf('OLS solver robustness test written: %s\n', fullfile(table_dir, 'ols_solver_robustness_test.csv'));
end

function settings = build_settings()
settings = struct([]);
settings(1).name = "baseline";
settings(1).relax_voltage = false;
settings(1).rate_factor = 1.0;
settings(2).name = "relaxed_voltage";
settings(2).relax_voltage = true;
settings(2).rate_factor = 1.0;
settings(3).name = "relaxed_rate_1p05";
settings(3).relax_voltage = false;
settings(3).rate_factor = 1.05;
settings(4).name = "relaxed_voltage_and_rate";
settings(4).relax_voltage = true;
settings(4).rate_factor = 1.05;
end

function [mpc_before, cumulative_load_shed_mw] = reconstruct_stage_case(project_root, root_dir, cfg, case_row)
scenario_id = string(case_row.scenario_id);
base_mpc0 = build_case39_base(cfg);
scenario = get_scenario_by_id(char(scenario_id), cfg, sum(base_mpc0.bus(:, 3)));
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);

mat_path = fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'chains', 'markov_chain_records.mat');
loaded = load(mat_path, 'chain_records');
chain_records = loaded.chain_records;
match_idx = find([chain_records.initial_branch]' == case_row.initial_branch & ...
    [chain_records.trial_id]' == case_row.trial_id, 1);
if isempty(match_idx)
    error('Unable to locate chain record for %s branch=%d trial=%d.', ...
        scenario_id, case_row.initial_branch, case_row.trial_id);
end
stage_record = chain_records(match_idx).stage_records(case_row.stage_id);
outages = stage_record.all_outaged_branches;
[mpc_fault, ~] = apply_line_outages(base_mpc, outages);
[mpc_before, island_info] = normalize_case_after_contingency(mpc_fault, cfg, scenario, renewable_info);
if isfield(stage_record, 'shed') && isfield(stage_record.shed, 'island_load_shed_mw')
    cumulative_load_shed_mw = stage_record.shed.island_load_shed_mw;
else
    cumulative_load_shed_mw = island_info.disconnected_load_mw;
end
end

function tbl = empty_robustness_table()
tbl = table(zeros(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    strings(0, 1), false(0, 1), false(0, 1), zeros(0, 1), zeros(0, 1), ...
    zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), ...
    'VariableNames', {'test_case_id', 'scenario_id', 'initial_branch', ...
    'trial_id', 'stage_id', 'setting_name', 'opf_success', ...
    'pf_success_after_apply', 'objective_load_shed_mw', ...
    'max_line_loading_after', 'min_voltage_after', 'max_voltage_after', ...
    'failure_type', 'message'});
end
