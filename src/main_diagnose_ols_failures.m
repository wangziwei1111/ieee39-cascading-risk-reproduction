function main_diagnose_ols_failures()
%MAIN_DIAGNOSE_OLS_FAILURES Build OLS failure diagnosis tables from smoke CSVs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
log_dir = fullfile(root_dir, 'logs');
if ~exist(table_dir, 'dir'), mkdir(table_dir); end
if ~exist(log_dir, 'dir'), mkdir(log_dir); end

scenario_ids = ["distributed_wind_3000mw_base", ...
    "distributed_wind_penetration_40pct", "paper_wind_speed_12_00mps"];
cfg = base_config();

rows = {};
for s = 1:numel(scenario_ids)
    scenario_id = scenario_ids(s);
    path = fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'ols_stage_details.csv');
    if ~exist(path, 'file')
        error('Missing OLS stage details: %s', path);
    end
    tbl = readtable(path);
    attempted = string(tbl.load_shedding_mode) == "paper_ols" & logical(tbl.load_shedding_trigger);
    failed = tbl(attempted & (string(tbl.ols_status) == "failed" | tbl.opf_success == 0), :);
    for i = 1:height(failed)
        row = failed(i, :);
        trigger_detail = struct( ...
            'max_line_loading_pu', row.max_line_loading_pu_before_shed, ...
            'min_voltage_pu', row.min_voltage_pu_before_shed, ...
            'max_voltage_pu', row.max_voltage_pu_before_shed);
        ols_detail = struct( ...
            'status', string(row.ols_status), ...
            'opf_success', logical(row.opf_success), ...
            'pf_success_after_apply', logical(row.pf_success_after_apply), ...
            'objective_load_shed_mw', row.objective_load_shed_mw, ...
            'total_load_shed_mw', row.total_load_shed_mw, ...
            'corrective_load_shed_mw', row.corrective_load_shed_mw, ...
            'message', string(row.message));
        info = diagnose_ols_failure([], [], ols_detail, trigger_detail, cfg);
        rows{end + 1, 1} = table(scenario_id, row.initial_branch, row.trial_id, row.stage_id, ...
            string(row.load_shedding_trigger_reason), row.max_line_loading_pu_before_shed, ...
            row.min_voltage_pu_before_shed, row.max_voltage_pu_before_shed, ...
            row.objective_load_shed_mw, row.total_load_shed_mw, row.corrective_load_shed_mw, ...
            logical(row.opf_success), logical(row.pf_success_after_apply), string(row.ols_status), ...
            string(row.message), info.failure_type, info.likely_cause, info.recommended_fix, ...
            'VariableNames', {'scenario_id', 'initial_branch', 'trial_id', 'stage_id', ...
            'load_shedding_trigger_reason', 'max_line_loading_pu_before_shed', ...
            'min_voltage_pu_before_shed', 'max_voltage_pu_before_shed', ...
            'objective_load_shed_mw', 'total_load_shed_mw', 'corrective_load_shed_mw', ...
            'opf_success', 'pf_success_after_apply', 'ols_status', 'message', ...
            'failure_type', 'likely_cause', 'recommended_fix'}); %#ok<AGROW>
    end
end

if isempty(rows)
    diagnosis = empty_diagnosis_table();
else
    diagnosis = vertcat(rows{:});
end
writetable(diagnosis, fullfile(table_dir, 'ols_failure_diagnosis.csv'));

summary = build_failure_summary(root_dir, scenario_ids, diagnosis);
writetable(summary, fullfile(table_dir, 'ols_failure_summary.csv'));

plot_ols_benchmark_smoke_figures(root_dir);

log_path = fullfile(log_dir, 'ols_failure_diagnosis_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'OLS failure diagnosis log\n');
fprintf(fid, 'generated_at=%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, 'diagnosis_rows=%d summary_rows=%d\n', height(diagnosis), height(summary));
if any(summary.failure_rate > 0.1)
    fprintf(fid, 'recommendation=Do not proceed to formal OLS benchmark rerun before reducing or explaining OLS failures.\n');
end
fprintf('OLS failure diagnosis written: %s\n', log_path);
end

function summary = build_failure_summary(root_dir, scenario_ids, diagnosis)
rows = {};
types = ["opf_nonconverged", "opf_infeasible", "pf_after_apply_nonconverged", ...
    "rateA_zero_or_too_tight", "voltage_constraint_too_tight", ...
    "generator_limit_binding", "island_or_slack_issue", "unknown"];
for s = 1:numel(scenario_ids)
    scenario_id = scenario_ids(s);
    summary_path = fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'ols_summary.csv');
    ols_summary = readtable(summary_path);
    total_attempts = ols_summary.total_ols_attempts(1);
    failed_count = ols_summary.failed_ols_count(1);
    sub = diagnosis(diagnosis.scenario_id == scenario_id, :);
    counts = zeros(1, numel(types));
    for t = 1:numel(types)
        counts(t) = sum(string(sub.failure_type) == types(t));
    end
    [~, idx] = max(counts);
    if isempty(sub)
        top_type = "none";
        next_action = "No OLS failures in this scenario.";
    else
        top_type = types(idx);
        next_action = recommended_action(top_type);
    end
    rows{end + 1, 1} = table(scenario_id, total_attempts, failed_count, ...
        failed_count / max(total_attempts, 1), counts(1), counts(2), counts(3), counts(4), ...
        counts(5), counts(6), counts(7), counts(8), top_type, next_action, ...
        'VariableNames', {'scenario_id', 'total_ols_attempts', 'failed_ols_count', ...
        'failure_rate', 'opf_nonconverged_count', 'opf_infeasible_count', ...
        'pf_after_apply_nonconverged_count', 'rateA_zero_or_too_tight_count', ...
        'voltage_constraint_too_tight_count', 'generator_limit_binding_count', ...
        'island_or_slack_issue_count', 'unknown_count', 'top_failure_type', ...
        'recommended_next_action'}); %#ok<AGROW>
end
summary = vertcat(rows{:});
end

function action = recommended_action(top_type)
switch string(top_type)
    case "pf_after_apply_nonconverged"
        action = "Inspect dispatchable-shed OPF to PF handoff and run robustness tests with voltage/rate sensitivities.";
    case "opf_nonconverged"
        action = "Test OPF algorithm/scaling options and inspect binding constraints.";
    case "opf_infeasible"
        action = "Check feasibility of voltage, branch, generator, and load-shed bounds.";
    case "rateA_zero_or_too_tight"
        action = "Confirm thesis branch limits and RATE_A replacement assumptions.";
    case "voltage_constraint_too_tight"
        action = "Run diagnostic-only relaxed voltage sensitivity.";
    case "generator_limit_binding"
        action = "Inspect generator P/Q limits and thesis case parameters.";
    case "island_or_slack_issue"
        action = "Check island retention and slack reassignment before OLS.";
    otherwise
        action = "Inspect detailed OLS messages and reconstruct representative failed stages.";
end
end

function tbl = empty_diagnosis_table()
tbl = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    false(0, 1), false(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    strings(0, 1), strings(0, 1), ...
    'VariableNames', {'scenario_id', 'initial_branch', 'trial_id', 'stage_id', ...
    'load_shedding_trigger_reason', 'max_line_loading_pu_before_shed', ...
    'min_voltage_pu_before_shed', 'max_voltage_pu_before_shed', ...
    'objective_load_shed_mw', 'total_load_shed_mw', 'corrective_load_shed_mw', ...
    'opf_success', 'pf_success_after_apply', 'ols_status', 'message', ...
    'failure_type', 'likely_cause', 'recommended_fix'});
end
