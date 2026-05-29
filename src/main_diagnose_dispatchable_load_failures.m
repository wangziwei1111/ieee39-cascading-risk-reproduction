function main_diagnose_dispatchable_load_failures()
%MAIN_DIAGNOSE_DISPATCHABLE_LOAD_FAILURES Diagnose dispatchable-load smoke failures.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
ensure_dir(table_dir);
scenario_ids = ["distributed_wind_3000mw_base", ...
    "distributed_wind_penetration_40pct", "paper_wind_speed_12_00mps"];

rows = {};
summary_rows = {};
for s = 1:numel(scenario_ids)
    sid = scenario_ids(s);
    stage_path = fullfile(root_dir, 'dispatchable_load', char(sid), 'tables', 'ols_stage_details.csv');
    must_exist(stage_path);
    stage = readtable(stage_path);
    attempt_mask = string(stage.load_shedding_mode) == "paper_ols";
    fail_mask = attempt_mask & (string(stage.ols_status) == "failed" | ...
        stage.opf_success == 0 | stage.pf_success_after_apply == 0 | ...
        contains(string(stage.message), "did not converge", 'IgnoreCase', true) | ...
        contains(string(stage.message), "不收敛"));
    fails = stage(fail_mask, :);
    for i = 1:height(fails)
        [failure_type, likely_cause, recommended_fix] = classify_failure(fails(i, :));
        rows{end + 1, 1} = table(sid, fails.initial_branch(i), fails.trial_id(i), ...
            fails.stage_id(i), string(fails.load_shedding_trigger_reason(i)), ...
            fails.max_line_loading_pu_before_shed(i), fails.min_voltage_pu_before_shed(i), ...
            fails.max_voltage_pu_before_shed(i), logical(fails.opf_success(i)), ...
            logical(fails.pf_success_after_apply(i)), string(fails.ols_status(i)), ...
            string(fails.message(i)), failure_type, likely_cause, recommended_fix, ...
            'VariableNames', {'scenario_id', 'initial_branch', 'trial_id', ...
            'stage_id', 'trigger_reason', 'max_line_loading_pu_before_shed', ...
            'min_voltage_pu_before_shed', 'max_voltage_pu_before_shed', ...
            'opf_success', 'pf_success_after_apply', 'ols_status', 'message', ...
            'failure_type', 'likely_cause', 'recommended_fix'}); %#ok<AGROW>
    end
    summary_rows{end + 1, 1} = summarize_scenario(sid, stage, fails); %#ok<AGROW>
end

if isempty(rows)
    diagnosis = empty_diagnosis();
else
    diagnosis = vertcat(rows{:});
end
summary = vertcat(summary_rows{:});
save_result_table(diagnosis, fullfile(table_dir, 'dispatchable_load_failure_diagnosis.csv'), true);
save_result_table(summary, fullfile(table_dir, 'dispatchable_load_failure_summary.csv'), true);
fprintf('dispatchable-load failure diagnosis written: %s\n', fullfile(table_dir, 'dispatchable_load_failure_diagnosis.csv'));
end

function [failure_type, likely_cause, recommended_fix] = classify_failure(row)
if ~logical(row.opf_success(1))
    failure_type = "dispatchable_opf_nonconverged";
    likely_cause = "Dispatchable-load AC OPF did not converge under the current AC voltage/reactive constraints.";
    recommended_fix = "Test DC-OLS preshed and AC polish to separate active-network feasibility from AC numerical/reactive issues.";
elseif ~logical(row.pf_success_after_apply(1))
    failure_type = "dispatchable_pf_after_apply_nonconverged";
    likely_cause = "AC OPF returned a solution but the applied load-side state did not converge in ordinary AC PF.";
    recommended_fix = "Replay with DC preshed and dispatchable-load AC polish; inspect PF initialization and reactive feasibility.";
elseif row.max_line_loading_pu_before_shed(1) > 1.5
    failure_type = "network_hard_infeasible";
    likely_cause = "Very high pre-shed branch loading may require more corrective action than current AC-OLS can find.";
    recommended_fix = "Use DC feasibility screen and inspect branch constraints.";
elseif row.min_voltage_pu_before_shed(1) < 0.85 || row.max_voltage_pu_before_shed(1) > 1.15
    failure_type = "ac_reactive_voltage_infeasible";
    likely_cause = "Pre-shed voltage state is outside normal AC feasibility range.";
    recommended_fix = "Inspect reactive limits and voltage constraints before formal OLS rerun.";
else
    failure_type = "unknown";
    likely_cause = "Failure did not match a simple rule.";
    recommended_fix = "Export the case and replay with DC preshed diagnostics.";
end
end

function summary = summarize_scenario(sid, stage, fails)
attempts = stage(string(stage.load_shedding_mode) == "paper_ols", :);
total_dispatchable_attempts = height(attempts);
dispatchable_failed_count = height(fails);
failure_rate = dispatchable_failed_count / max(total_dispatchable_attempts, 1);
types = strings(height(fails), 1);
for i = 1:height(fails)
    [types(i), ~, ~] = classify_failure(fails(i, :));
end
opf_count = sum(types == "dispatchable_opf_nonconverged");
pf_count = sum(types == "dispatchable_pf_after_apply_nonconverged");
network_count = sum(types == "network_hard_infeasible");
dc_ac_count = sum(types == "dc_feasible_ac_infeasible");
top_failure_type = top_type(types);
if failure_rate > 0.1
    action = "Run DC preshed and two-stage diagnostic before any formal benchmark.";
else
    action = "Failure rate is low in this smoke; still diagnostic only.";
end
summary = table(sid, total_dispatchable_attempts, dispatchable_failed_count, failure_rate, ...
    opf_count, pf_count, network_count, dc_ac_count, top_failure_type, action, ...
    'VariableNames', {'scenario_id', 'total_dispatchable_attempts', ...
    'dispatchable_failed_count', 'failure_rate', 'opf_nonconverged_count', ...
    'pf_after_apply_nonconverged_count', 'network_hard_infeasible_count', ...
    'dc_feasible_ac_infeasible_count', 'top_failure_type', 'recommended_next_action'});
end

function t = top_type(types)
if isempty(types)
    t = "none";
    return;
end
u = unique(types);
counts = zeros(numel(u), 1);
for i = 1:numel(u)
    counts(i) = sum(types == u(i));
end
[~, idx] = max(counts);
t = u(idx);
end

function tbl = empty_diagnosis()
tbl = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), false(0,1), false(0,1), ...
    strings(0,1), strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'scenario_id', 'initial_branch', 'trial_id', 'stage_id', ...
    'trigger_reason', 'max_line_loading_pu_before_shed', ...
    'min_voltage_pu_before_shed', 'max_voltage_pu_before_shed', ...
    'opf_success', 'pf_success_after_apply', 'ols_status', 'message', ...
    'failure_type', 'likely_cause', 'recommended_fix'});
end

function must_exist(path)
if ~exist(path, 'file'), error('Required file is missing: %s', path); end
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
