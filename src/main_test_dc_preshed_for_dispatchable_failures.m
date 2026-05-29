function main_test_dc_preshed_for_dispatchable_failures()
%MAIN_TEST_DC_PRESHED_FOR_DISPATCHABLE_FAILURES Test DC preshed on dispatchable failures.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
index_path = fullfile(table_dir, 'dispatchable_failure_case_index.csv');
must_exist(index_path);
opts = detectImportOptions(index_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
index = readtable(index_path, opts);
cfg0 = base_config();
cfg0.paper_ols_formulation = 'dispatchable_load';
cfg0.paper_ols_dispatchable_load_q_mode = 'variable_absorption';
cfg0.paper_ols_two_stage_enable = false;
cfg0.paper_ols_enable = true;
require_matpower(cfg0);

rows = {};
for i = 1:height(index)
    case_dir_values = get_table_column(index, "case_dir");
    case_dir = char(strrep(string(case_dir_values(i)), '/', filesep));
    mat_path = fullfile(case_dir, 'mpc_before_ols.mat');
    if ~exist(mat_path, 'file')
        rows{end + 1, 1} = missing_case_row(index(i, :), "missing_mpc_before_ols"); %#ok<AGROW>
        continue;
    end
    data = load(mat_path, 'mpc_before', 'cumulative_load_shed_mw');
    rows{end + 1, 1} = run_baseline(index(i, :), data.mpc_before, cfg0, data.cumulative_load_shed_mw); %#ok<AGROW>
    [mpc_preshed, dc_detail] = solve_dc_ols_preshed(data.mpc_before, cfg0);
    rows{end + 1, 1} = run_dc_pf(index(i, :), mpc_preshed, dc_detail, cfg0, data.cumulative_load_shed_mw); %#ok<AGROW>
    rows{end + 1, 1} = run_dc_polish(index(i, :), mpc_preshed, dc_detail, cfg0, data.cumulative_load_shed_mw); %#ok<AGROW>
end

test_tbl = vertcat(rows{:});
summary = summarize_tests(test_tbl);
save_result_table(test_tbl, fullfile(table_dir, 'dc_preshed_dispatchable_failure_test.csv'), true);
save_result_table(summary, fullfile(table_dir, 'dc_preshed_dispatchable_summary.csv'), true);
plot_ols_benchmark_smoke_figures(root_dir);
fprintf('DC preshed dispatchable failure test written: %s\n', fullfile(table_dir, 'dc_preshed_dispatchable_failure_test.csv'));
end

function row = run_baseline(idx, mpc_before, cfg, cumulative)
[~, ~, shed, detail] = solve_paper_ols_load_shedding(mpc_before, cfg, cumulative);
row = make_row(idx, "baseline_dispatchable_load", false, NaN, false, false, ...
    logical(detail.pf_success_after_apply), shed.total_load_shed_mw, detail, string(detail.diagnosis_failure_type), string(detail.message));
end

function row = run_dc_pf(idx, mpc_preshed, dc_detail, cfg, cumulative)
if ~logical(dc_detail.lp_success)
    row = make_row(idx, "dc_preshed_ac_pf", false, dc_detail.objective_load_shed_mw, ...
        false, false, false, cumulative, struct(), "dc_preshed_failed", string(dc_detail.message));
    return;
end
[pf_result, pf_success] = run_ac_powerflow(mpc_preshed);
detail = after_pf_detail(pf_result, pf_success, cfg);
row = make_row(idx, "dc_preshed_ac_pf", true, dc_detail.objective_load_shed_mw, ...
    pf_success, false, false, cumulative + dc_detail.objective_load_shed_mw, detail, ...
    classify_after_pf(pf_success), string(dc_detail.message));
end

function row = run_dc_polish(idx, mpc_preshed, dc_detail, cfg, cumulative)
if ~logical(dc_detail.lp_success)
    row = make_row(idx, "dc_preshed_ac_ols_polish", false, dc_detail.objective_load_shed_mw, ...
        false, false, false, cumulative, struct(), "dc_preshed_failed", string(dc_detail.message));
    return;
end
[~, ~, shed, detail] = solve_paper_ols_load_shedding(mpc_preshed, cfg, cumulative + dc_detail.objective_load_shed_mw);
total_load = shed.total_load_shed_mw;
row = make_row(idx, "dc_preshed_ac_ols_polish", true, dc_detail.objective_load_shed_mw, ...
    false, logical(detail.opf_success), logical(detail.pf_success_after_apply), total_load, ...
    detail, string(detail.diagnosis_failure_type), string(detail.message));
end

function row = missing_case_row(idx, message)
row = make_row(idx, "missing_case", false, NaN, false, false, false, NaN, struct(), "missing_case", message);
end

function row = make_row(idx, test_mode, dc_success, dc_obj, ac_pf_success, ac_ols_success, pf_after_ols_success, total_load, detail, failure_type, message)
[max_loading, min_v, max_v] = detail_metrics(detail);
row = table(string(idx.case_export_id(1)), string(idx.scenario_id(1)), ...
    idx.initial_branch(1), idx.trial_id(1), idx.stage_id(1), string(test_mode), ...
    logical(dc_success), dc_obj, logical(ac_pf_success), logical(ac_ols_success), ...
    logical(pf_after_ols_success), total_load, max_loading, min_v, max_v, ...
    string(failure_type), string(message), ...
    'VariableNames', {'case_export_id', 'scenario_id', 'initial_branch', ...
    'trial_id', 'stage_id', 'test_mode', 'dc_lp_success', ...
    'dc_objective_load_shed_mw', 'ac_pf_success_after_dc_preshed', ...
    'ac_ols_success_after_dc_preshed', 'pf_success_after_ac_ols', ...
    'total_load_shed_mw', 'max_line_loading_after', 'min_voltage_after', ...
    'max_voltage_after', 'failure_type_after', 'message'});
end

function detail = after_pf_detail(pf_result, pf_success, cfg)
detail = struct();
if pf_success
    violations = check_violations(pf_result, cfg);
    detail.max_line_loading_after_apply = violations.max_line_loading_pu;
    detail.min_voltage_after_apply = min(pf_result.bus(:, 8));
    detail.max_voltage_after_apply = max(pf_result.bus(:, 8));
else
    detail.max_line_loading_after_apply = NaN;
    detail.min_voltage_after_apply = NaN;
    detail.max_voltage_after_apply = NaN;
end
end

function [max_loading, min_v, max_v] = detail_metrics(detail)
max_loading = get_struct_field(detail, 'max_line_loading_after_apply', NaN);
min_v = get_struct_field(detail, 'min_voltage_after_apply', NaN);
max_v = get_struct_field(detail, 'max_voltage_after_apply', NaN);
end

function t = classify_after_pf(success)
if success
    t = "success";
else
    t = "dc_feasible_ac_infeasible";
end
end

function summary = summarize_tests(test_tbl)
modes = unique(string(test_tbl.test_mode), 'stable');
rows = {};
for i = 1:numel(modes)
    rows_i = test_tbl(string(test_tbl.test_mode) == modes(i), :);
    case_count = height(rows_i);
    dc_lp_success_count = sum(rows_i.dc_lp_success);
    ac_pf_success_count = sum(rows_i.ac_pf_success_after_dc_preshed);
    ac_ols_success_count = sum(rows_i.ac_ols_success_after_dc_preshed);
    pf_after_ac_ols_success_count = sum(rows_i.pf_success_after_ac_ols);
    if modes(i) == "dc_preshed_ac_pf"
        success_rate = ac_pf_success_count / max(case_count, 1);
    elseif modes(i) == "dc_preshed_ac_ols_polish"
        success_rate = pf_after_ac_ols_success_count / max(case_count, 1);
    else
        success_rate = pf_after_ac_ols_success_count / max(case_count, 1);
    end
    recommendation = "diagnostic_only";
    if success_rate > 0.9
        recommendation = "candidate_for_next_diagnostic";
    elseif success_rate < 0.5
        recommendation = "not_ready_for_formal_benchmark";
    end
    rows{end + 1, 1} = table(modes(i), case_count, dc_lp_success_count, ...
        ac_pf_success_count, ac_ols_success_count, pf_after_ac_ols_success_count, ...
        mean(rows_i.total_load_shed_mw, 'omitnan'), success_rate, recommendation, ...
        'VariableNames', {'test_mode', 'case_count', 'dc_lp_success_count', ...
        'ac_pf_success_count', 'ac_ols_success_count', ...
        'pf_after_ac_ols_success_count', 'mean_total_load_shed_mw', ...
        'success_rate', 'recommendation'}); %#ok<AGROW>
end
summary = vertcat(rows{:});
end

function value = get_struct_field(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end

function must_exist(path)
if ~exist(path, 'file'), error('Required file is missing: %s', path); end
end

function col = get_table_column(tbl, name)
vars = string(tbl.Properties.VariableNames);
idx = find(vars == name, 1);
if isempty(idx)
    idx = find(vars == name + "_", 1);
end
if isempty(idx)
    error('Missing expected table column: %s', name);
end
col = tbl.(vars(idx));
end
