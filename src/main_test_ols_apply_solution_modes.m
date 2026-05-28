function main_test_ols_apply_solution_modes()
%MAIN_TEST_OLS_APPLY_SOLUTION_MODES Test how OPF solution application affects PF.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
if ~exist(table_dir, 'dir'), mkdir(table_dir); end

diagnosis_path = fullfile(table_dir, 'ols_failure_diagnosis.csv');
if ~exist(diagnosis_path, 'file')
    error('Run main_diagnose_ols_failures before apply solution mode test.');
end
diagnosis = readtable(diagnosis_path);
failed_cases = diagnosis(1:min(10, height(diagnosis)), :);
modes = ["load_only", "load_and_dispatch", "load_dispatch_and_voltage_init"];
cfg0 = base_config();
require_matpower(cfg0);

rows = {};
for c = 1:height(failed_cases)
    case_row = failed_cases(c, :);
    [mpc_before, cumulative_load_shed_mw] = reconstruct_stage_case(project_root, root_dir, cfg0, case_row);
    for m = 1:numel(modes)
        cfg = cfg0;
        cfg.paper_ols_enable = true;
        cfg.paper_ols_apply_solution_mode = char(modes(m));
        cfg.paper_ols_relax_voltage_limits = false;
        cfg.paper_ols_rate_limit_relax_factor = 1.0;
        [~, ~, ~, detail] = solve_paper_ols_load_shedding(mpc_before, cfg, cumulative_load_shed_mw);
        rows{end + 1, 1} = table(c, string(case_row.scenario_id), case_row.initial_branch, ...
            case_row.trial_id, case_row.stage_id, modes(m), logical(detail.opf_success), ...
            logical(detail.pf_success_after_apply), logical(detail.opf_success_but_pf_failed), ...
            detail.objective_load_shed_mw, detail.max_line_loading_after_apply, ...
            detail.min_voltage_after_apply, detail.max_voltage_after_apply, ...
            string(detail.diagnosis_failure_type), string(detail.message), ...
            'VariableNames', {'test_case_id', 'scenario_id', 'initial_branch', ...
            'trial_id', 'stage_id', 'apply_solution_mode', 'opf_success', ...
            'pf_success_after_apply', 'opf_success_but_pf_failed', ...
            'objective_load_shed_mw', 'max_line_loading_after_apply', ...
            'min_voltage_after_apply', 'max_voltage_after_apply', ...
            'failure_type', 'message'}); %#ok<AGROW>
    end
end

if isempty(rows)
    test_table = empty_test_table();
else
    test_table = vertcat(rows{:});
end
writetable(test_table, fullfile(table_dir, 'ols_apply_solution_mode_test.csv'));

summary = build_summary(test_table, modes);
writetable(summary, fullfile(table_dir, 'ols_apply_solution_mode_summary.csv'));
plot_ols_benchmark_smoke_figures(root_dir);
fprintf('OLS apply solution mode test written: %s\n', fullfile(table_dir, 'ols_apply_solution_mode_test.csv'));
end

function summary = build_summary(test_table, modes)
rows = {};
for i = 1:numel(modes)
    mode = modes(i);
    sub = test_table(test_table.apply_solution_mode == mode, :);
    n = height(sub);
    opf_count = sum(sub.opf_success);
    pf_count = sum(sub.pf_success_after_apply);
    opf_pf_failed = sum(sub.opf_success_but_pf_failed);
    if n > 0
        success_rate = pf_count / n;
        mean_obj = mean(sub.objective_load_shed_mw, 'omitnan');
    else
        success_rate = NaN;
        mean_obj = NaN;
    end
    note = "Diagnostic only; not a formal benchmark result.";
    rows{end + 1, 1} = table(mode, n, opf_count, pf_count, opf_pf_failed, ...
        success_rate, mean_obj, note, ...
        'VariableNames', {'apply_solution_mode', 'test_case_count', ...
        'opf_success_count', 'pf_success_after_apply_count', ...
        'opf_success_but_pf_failed_count', 'success_rate', ...
        'mean_objective_load_shed_mw', 'note'}); %#ok<AGROW>
end
summary = vertcat(rows{:});
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
[mpc_fault, ~] = apply_line_outages(base_mpc, stage_record.all_outaged_branches);
[mpc_before, island_info] = normalize_case_after_contingency(mpc_fault, cfg, scenario, renewable_info);
if isfield(stage_record, 'shed') && isfield(stage_record.shed, 'island_load_shed_mw')
    cumulative_load_shed_mw = stage_record.shed.island_load_shed_mw;
else
    cumulative_load_shed_mw = island_info.disconnected_load_mw;
end
end

function tbl = empty_test_table()
tbl = table(zeros(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), ...
    zeros(0, 1), strings(0, 1), false(0, 1), false(0, 1), ...
    false(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    strings(0, 1), strings(0, 1), ...
    'VariableNames', {'test_case_id', 'scenario_id', 'initial_branch', ...
    'trial_id', 'stage_id', 'apply_solution_mode', 'opf_success', ...
    'pf_success_after_apply', 'opf_success_but_pf_failed', ...
    'objective_load_shed_mw', 'max_line_loading_after_apply', ...
    'min_voltage_after_apply', 'max_voltage_after_apply', ...
    'failure_type', 'message'});
end
