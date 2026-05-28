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
require_matpower(cfg);
case_cache = containers.Map('KeyType', 'char', 'ValueType', 'any');

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
        [mpc_before, ~, case_cache] = reconstruct_stage_case(project_root, root_dir, cfg, scenario_id, row, case_cache);
        info = diagnose_ols_failure(mpc_before, [], ols_detail, trigger_detail, cfg);
        rows{end + 1, 1} = table(scenario_id, row.initial_branch, row.trial_id, row.stage_id, ...
            string(row.load_shedding_trigger_reason), row.max_line_loading_pu_before_shed, ...
            row.min_voltage_pu_before_shed, row.max_voltage_pu_before_shed, ...
            row.objective_load_shed_mw, row.total_load_shed_mw, row.corrective_load_shed_mw, ...
            logical(row.opf_success), logical(row.pf_success_after_apply), string(row.ols_status), ...
            string(row.message), info.failure_type, info.likely_cause, info.recommended_fix, ...
            logical(info.has_online_slack_after_island), info.slack_bus_id, info.online_gen_count, ...
            info.online_gen_pmax_sum, info.load_mw_before_ols, info.load_mw_after_ols, ...
            info.generation_pmax_margin_mw, info.num_binding_p_generators, ...
            info.num_binding_q_generators, logical(info.opf_success_but_pf_failed), ...
            'VariableNames', {'scenario_id', 'initial_branch', 'trial_id', 'stage_id', ...
            'load_shedding_trigger_reason', 'max_line_loading_pu_before_shed', ...
            'min_voltage_pu_before_shed', 'max_voltage_pu_before_shed', ...
            'objective_load_shed_mw', 'total_load_shed_mw', 'corrective_load_shed_mw', ...
            'opf_success', 'pf_success_after_apply', 'ols_status', 'message', ...
            'failure_type', 'likely_cause', 'recommended_fix', ...
            'has_online_slack_after_island', 'slack_bus_id', 'online_gen_count', ...
            'online_gen_pmax_sum', 'load_mw_before_ols', 'load_mw_after_ols', ...
            'generation_pmax_margin_mw', 'num_binding_p_generators', ...
            'num_binding_q_generators', 'opf_success_but_pf_failed'}); %#ok<AGROW>
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
    "generation_capacity_insufficient", "generator_q_limit_binding", ...
    "generator_limit_binding", "network_constraint_tight", ...
    "island_or_slack_issue", "unknown"];
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
    opf_pf_failed = sum(logical(sub.opf_success_but_pf_failed));
    apply_rec = apply_solution_recommendation(opf_pf_failed, failed_count);
    rows{end + 1, 1} = table(scenario_id, total_attempts, failed_count, ...
        failed_count / max(total_attempts, 1), counts(1), counts(2), counts(3), counts(4), ...
        counts(5), counts(6), counts(7), counts(8), counts(9), counts(10), counts(11), ...
        opf_pf_failed, top_type, next_action, apply_rec, ...
        'VariableNames', {'scenario_id', 'total_ols_attempts', 'failed_ols_count', ...
        'failure_rate', 'opf_nonconverged_count', 'opf_infeasible_count', ...
        'pf_after_apply_nonconverged_count', 'rateA_zero_or_too_tight_count', ...
        'voltage_constraint_too_tight_count', 'generation_capacity_insufficient_count', ...
        'generator_q_limit_binding_count', 'generator_limit_binding_count', ...
        'network_constraint_tight_count', 'island_or_slack_issue_count', 'unknown_count', ...
        'opf_success_but_pf_failed_count', 'top_failure_type', ...
        'recommended_next_action', 'apply_solution_mode_recommendation'}); %#ok<AGROW>
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
    case "generator_q_limit_binding"
        action = "Inspect generator Q limits and voltage support assumptions.";
    case "generation_capacity_insufficient"
        action = "Inspect island generation capacity and retained load.";
    case "network_constraint_tight"
        action = "Inspect branch limits and network constraints.";
    case "island_or_slack_issue"
        action = "Check island retention and slack reassignment before OLS.";
    otherwise
        action = "Inspect detailed OLS messages and reconstruct representative failed stages.";
end
end

function action = apply_solution_recommendation(opf_pf_failed, failed_count)
if failed_count > 0 && opf_pf_failed / failed_count >= 0.25
    action = "Run apply-solution-mode diagnostics; OPF success but PF failure is material.";
else
    action = "Apply-solution-mode change is not the dominant next fix.";
end
end

function [mpc_before, cumulative_load_shed_mw, case_cache] = reconstruct_stage_case(project_root, root_dir, cfg, scenario_id, row, case_cache)
key = char(scenario_id);
if isKey(case_cache, key)
    data = case_cache(key);
else
    base_mpc0 = build_case39_base(cfg);
    scenario = get_scenario_by_id(key, cfg, sum(base_mpc0.bus(:, 3)));
    [base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);
    mat_path = fullfile(root_dir, 'paper_ols_violation', key, 'chains', 'markov_chain_records.mat');
    loaded = load(mat_path, 'chain_records');
    data = struct('base_mpc', base_mpc, 'scenario', scenario, ...
        'renewable_info', renewable_info, 'chain_records', loaded.chain_records);
    case_cache(key) = data;
end
chain_records = data.chain_records;
match_idx = find([chain_records.initial_branch]' == row.initial_branch & ...
    [chain_records.trial_id]' == row.trial_id, 1);
stage_record = chain_records(match_idx).stage_records(row.stage_id);
[mpc_fault, ~] = apply_line_outages(data.base_mpc, stage_record.all_outaged_branches);
[mpc_before, island_info] = normalize_case_after_contingency(mpc_fault, cfg, data.scenario, data.renewable_info);
if isfield(stage_record, 'shed') && isfield(stage_record.shed, 'island_load_shed_mw')
    cumulative_load_shed_mw = stage_record.shed.island_load_shed_mw;
else
    cumulative_load_shed_mw = island_info.disconnected_load_mw;
end
end

function tbl = empty_diagnosis_table()
tbl = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    false(0, 1), false(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
    strings(0, 1), strings(0, 1), false(0, 1), zeros(0, 1), zeros(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), ...
    'VariableNames', {'scenario_id', 'initial_branch', 'trial_id', 'stage_id', ...
    'load_shedding_trigger_reason', 'max_line_loading_pu_before_shed', ...
    'min_voltage_pu_before_shed', 'max_voltage_pu_before_shed', ...
    'objective_load_shed_mw', 'total_load_shed_mw', 'corrective_load_shed_mw', ...
    'opf_success', 'pf_success_after_apply', 'ols_status', 'message', ...
    'failure_type', 'likely_cause', 'recommended_fix', ...
    'has_online_slack_after_island', 'slack_bus_id', 'online_gen_count', ...
    'online_gen_pmax_sum', 'load_mw_before_ols', 'load_mw_after_ols', ...
    'generation_pmax_margin_mw', 'num_binding_p_generators', ...
    'num_binding_q_generators', 'opf_success_but_pf_failed'});
end
