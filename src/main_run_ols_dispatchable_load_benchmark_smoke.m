function main_run_ols_dispatchable_load_benchmark_smoke()
%MAIN_RUN_OLS_DISPATCHABLE_LOAD_BENCHMARK_SMOKE Run 5-trial dispatchable-load OLS smoke.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
ensure_dir(table_dir);
sign_tbl = readtable(fullfile(table_dir, 'dispatchable_load_sign_convention_test.csv'));
if any(string(sign_tbl.status) == "fail")
    error('Dispatchable-load sign convention failed; benchmark smoke is not allowed.');
end

cfg0 = base_config();
require_matpower(cfg0);
scenario_ids = ["distributed_wind_3000mw_base", ...
    "distributed_wind_penetration_40pct", "paper_wind_speed_12_00mps"];

rows = {};
for s = 1:numel(scenario_ids)
    fprintf('dispatchable_load smoke: scenario=%s\n', scenario_ids(s));
    rows{end + 1, 1} = run_dispatchable_case(project_root, root_dir, cfg0, scenario_ids(s)); %#ok<AGROW>
end
dispatch_summary = vertcat(rows{:});
save_result_table(dispatch_summary, fullfile(table_dir, 'ols_dispatchable_load_smoke_summary.csv'), true);

comparison = build_formulation_comparison(root_dir, scenario_ids, dispatch_summary);
save_result_table(comparison, fullfile(table_dir, 'ols_formulation_comparison.csv'), true);
plot_ols_benchmark_smoke_figures(root_dir);
fprintf('dispatchable-load formulation comparison written: %s\n', ...
    fullfile(table_dir, 'ols_formulation_comparison.csv'));
end

function summary_row = run_dispatchable_case(project_root, root_dir, cfg0, scenario_id)
cfg = cfg0;
cfg.markov_num_trials_per_initial_fault = 5;
cfg.markov_random_seed = cfg.seed;
cfg.load_shedding_mode = 'paper_ols';
cfg.load_shedding_trigger_mode = 'nonconverged_or_violation';
cfg.paper_ols_enable = true;
cfg.paper_ols_formulation = 'dispatchable_load';
cfg.paper_ols_dispatchable_load_q_mode = 'variable_absorption';
cfg.paper_ols_fail_policy = 'fallback_to_simple_with_warning';
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
cfg.severity_mode = 'basic';

case_root = fullfile(root_dir, 'dispatchable_load', char(scenario_id));
cfg.results_table_dir = fullfile(case_root, 'tables');
cfg.results_log_dir = fullfile(case_root, 'logs');
cfg.results_chain_dir = fullfile(case_root, 'chains');
cfg.results_figure_dir = fullfile(case_root, 'figures');
ensure_dir(cfg.results_table_dir); ensure_dir(cfg.results_log_dir);
ensure_dir(cfg.results_chain_dir); ensure_dir(cfg.results_figure_dir);

log_path = fullfile(cfg.results_log_dir, 'scenario_run_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'dispatchable_load OLS benchmark smoke scenario=%s\n', scenario_id);
fprintf(fid, '5-trial diagnostic only; not final thesis result.\n');

init_random_seed(cfg.markov_random_seed);
base_mpc0 = build_case39_base(cfg);
scenario = get_scenario_by_id(char(scenario_id), cfg, sum(base_mpc0.bus(:, 3)));
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);
initial_probability_table = load_initial_line_probabilities(cfg, base_mpc);

chain_records = run_markov_records(base_mpc, cfg, scenario, renewable_info);
[chain_summary_table, ~] = flatten_chain_records(chain_records, cfg);
ols_stage_details = flatten_ols_records(chain_records);
ols_summary = summarize_ols_records(ols_stage_details);

save_result_table(chain_summary_table, fullfile(cfg.results_table_dir, 'markov_chain_summary.csv'), true);
save(fullfile(cfg.results_chain_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', '-v7.3');
save_result_table(ols_stage_details, fullfile(cfg.results_table_dir, 'ols_stage_details.csv'), true);
save_result_table(ols_summary, fullfile(cfg.results_table_dir, 'ols_summary.csv'), true);

cfg.var_use_chain_weights = false;
risk_samples = build_markov_risk_samples(chain_summary_table, cfg);
var_basic = calc_markov_var_metrics(risk_samples, cfg, 'basic');
save_result_table(risk_samples, fullfile(cfg.results_table_dir, 'markov_risk_samples.csv'), true);
save_result_table(var_basic, fullfile(cfg.results_table_dir, 'markov_var_metrics.csv'), true);

cfg.var_use_chain_weights = true;
risk_samples_weighted = build_markov_risk_samples(chain_summary_table, cfg, initial_probability_table);
var_weighted = calc_markov_var_metrics(risk_samples_weighted, cfg, 'basic');
save_result_table(risk_samples_weighted, fullfile(cfg.results_table_dir, 'markov_risk_samples_weighted.csv'), true);
save_result_table(var_weighted, fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv'), true);

cfg.var_use_chain_weights = false;
cfg.severity_mode = 'paper_formula';
cfg.enable_paper_severity = true;
cfg.paper_severity_formula_confirmed = true;
[line_flow_detail_table, bus_voltage_detail_table, stage_probability_table, ...
    ~, invalid_stage_summary_table] = ...
    build_markov_paper_detail_tables(chain_records, base_mpc, cfg, scenario, renewable_info, initial_probability_table);
paper_severity = calc_paper_chain_severity(chain_summary_table, cfg, ...
    line_flow_detail_table, bus_voltage_detail_table, stage_probability_table);
risk_samples_paper = build_paper_risk_samples(chain_summary_table, paper_severity);
var_paper = calc_markov_var_metrics(risk_samples_paper, cfg, 'paper');
invalid_stage_ratio = invalid_stage_summary_table.invalid_stage_ratio(1);
paper_result_status = "valid";
if invalid_stage_ratio > cfg.paper_max_invalid_chain_ratio_for_var || any(isnan(risk_samples_paper.paper_CRI))
    paper_result_status = "diagnostic_only";
end
var_paper.result_status = repmat(paper_result_status, height(var_paper), 1);
save_result_table(risk_samples_paper, fullfile(cfg.results_table_dir, 'markov_risk_samples_paper_severity.csv'), true);
save_result_table(var_paper, fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv'), true);
save_result_table(invalid_stage_summary_table, fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_summary.csv'), true);

mean_q_mismatch = mean(get_optional_numeric_column(ols_stage_details, 'q_mismatch_between_opf_and_applied'), 'omitnan');
max_q_mismatch = max(get_optional_numeric_column(ols_stage_details, 'q_mismatch_between_opf_and_applied'), [], 'omitnan');
max_positive_q_injection = max(get_optional_numeric_column(ols_stage_details, 'max_positive_q_injection'), [], 'omitnan');
summary_row = table(string(scenario_id), "dispatchable_load", 5, height(chain_summary_table), ...
    "paper_ols", "nonconverged_or_violation", "dispatchable_load", "variable_absorption", ...
    ols_summary.total_ols_attempts(1), ols_summary.successful_ols_count(1), ...
    ols_summary.failed_ols_count(1), ols_summary.fallback_count(1), ...
    ols_summary.triggered_stage_count(1), ols_summary.nonconverged_trigger_count(1), ...
    ols_summary.line_overload_trigger_count(1), ols_summary.voltage_violation_trigger_count(1), ...
    mean_q_mismatch, max_q_mismatch, max_positive_q_injection, ...
    ols_summary.mean_objective_load_shed_mw(1), ols_summary.max_objective_load_shed_mw(1), ...
    extract_cri(var_basic, 0.95), extract_cri(var_weighted, 0.95), extract_cri(var_paper, 0.95), ...
    paper_result_status, invalid_stage_ratio, ...
    "5-trial dispatchable_load variable_absorption diagnostic only; not final paper result.", ...
    'VariableNames', {'scenario_id', 'mode', 'markov_trials_per_initial_fault', 'chain_count', ...
    'load_shedding_mode', 'load_shedding_trigger_mode', 'paper_ols_formulation', ...
    'q_mode', 'total_ols_attempts', 'successful_ols_count', 'failed_ols_count', ...
    'fallback_count', 'triggered_stage_count', 'nonconverged_trigger_count', ...
    'line_overload_trigger_count', 'voltage_violation_trigger_count', ...
    'mean_q_mismatch', 'max_q_mismatch', 'max_positive_q_injection', ...
    'mean_objective_load_shed_mw', 'max_objective_load_shed_mw', ...
    'basic_CRI_095', 'weighted_CRI_095', 'paper_CRI_095', ...
    'paper_result_status', 'invalid_stage_ratio', 'note'});
save_result_table(summary_row, fullfile(cfg.results_table_dir, 'dispatchable_load_summary.csv'), true);
fprintf(fid, 'chain_count=%d failed_ols=%d mean_q_mismatch=%.12g max_positive_q_injection=%.12g\n', ...
    height(chain_summary_table), ols_summary.failed_ols_count(1), mean_q_mismatch, max_positive_q_injection);
end

function comparison = build_formulation_comparison(root_dir, scenario_ids, dispatch_summary)
rows = {};
for s = 1:numel(scenario_ids)
    scenario_id = scenario_ids(s);
    rows{end + 1, 1} = read_formulation_row(root_dir, scenario_id, ...
        "positive_injection_generator", "free_q", ...
        fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables')); %#ok<AGROW>
    rows{end + 1, 1} = read_formulation_row(root_dir, scenario_id, ...
        "positive_injection_generator", "fixed_zero_q", ...
        fullfile(root_dir, 'fixed_q_shed', char(scenario_id), 'tables')); %#ok<AGROW>
    drow = dispatch_summary(string(dispatch_summary.scenario_id) == scenario_id, :);
    rows{end + 1, 1} = summary_to_formulation_row(drow); %#ok<AGROW>
end
comparison = vertcat(rows{:});
comparison.recommendation = repmat("diagnostic_only", height(comparison), 1);
for s = 1:numel(scenario_ids)
    sid = scenario_ids(s);
    sub = comparison(string(comparison.scenario_id) == sid, :);
    dispatch_idx = find(string(comparison.scenario_id) == sid & string(comparison.formulation) == "dispatchable_load", 1);
    if isempty(dispatch_idx), continue; end
    dispatch_failure = comparison.failure_rate(dispatch_idx);
    other_failure = sub.failure_rate(string(sub.formulation) ~= "dispatchable_load");
    other_failure = other_failure(~isnan(other_failure));
    if ~isempty(other_failure) && all(dispatch_failure < other_failure)
        comparison.recommendation(dispatch_idx) = "recommended_for_next_diagnostic";
    elseif dispatch_failure > 0.1
        comparison.recommendation(dispatch_idx) = "not_ready_for_formal_benchmark";
    else
        comparison.recommendation(dispatch_idx) = "candidate_with_caution";
    end
end
end

function row = read_formulation_row(root_dir, scenario_id, formulation, q_mode, table_dir)
ols_summary = readtable(fullfile(table_dir, 'ols_summary.csv'));
stage_path = fullfile(table_dir, 'ols_stage_details.csv');
stage = readtable(stage_path);
basic = readtable(fullfile(table_dir, 'markov_var_metrics.csv'));
weighted = readtable(fullfile(table_dir, 'markov_var_metrics_weighted.csv'));
paper = readtable(fullfile(table_dir, 'markov_var_metrics_paper_severity.csv'));
invalid = readtable(fullfile(table_dir, 'markov_paper_invalid_stage_summary.csv'));
mean_q_mismatch = mean(get_optional_numeric_column(stage, 'q_mismatch_between_opf_and_applied'), 'omitnan');
max_q_mismatch = max(get_optional_numeric_column(stage, 'q_mismatch_between_opf_and_applied'), [], 'omitnan');
max_positive_q_injection = max(get_optional_numeric_column(stage, 'max_positive_q_injection'), [], 'omitnan');
failed = ols_summary.failed_ols_count(1);
attempts = ols_summary.total_ols_attempts(1);
row = table(string(scenario_id), string(formulation), string(q_mode), attempts, ...
    ols_summary.successful_ols_count(1), failed, failed / max(attempts, 1), ...
    mean_q_mismatch, max_q_mismatch, max_positive_q_injection, ...
    extract_cri(basic, 0.95), extract_cri(weighted, 0.95), extract_cri(paper, 0.95), ...
    invalid.invalid_stage_ratio(1), "diagnostic_only", ...
    'VariableNames', {'scenario_id', 'formulation', 'q_mode', 'total_ols_attempts', ...
    'successful_ols_count', 'failed_ols_count', 'failure_rate', 'mean_q_mismatch', ...
    'max_q_mismatch', 'max_positive_q_injection', 'basic_CRI_095', ...
    'weighted_CRI_095', 'paper_CRI_095', 'invalid_stage_ratio', 'recommendation'});
end

function row = summary_to_formulation_row(summary_row)
failed = summary_row.failed_ols_count(1);
attempts = summary_row.total_ols_attempts(1);
row = table(string(summary_row.scenario_id(1)), string(summary_row.paper_ols_formulation(1)), ...
    string(summary_row.q_mode(1)), attempts, summary_row.successful_ols_count(1), failed, ...
    failed / max(attempts, 1), summary_row.mean_q_mismatch(1), summary_row.max_q_mismatch(1), ...
    summary_row.max_positive_q_injection(1), summary_row.basic_CRI_095(1), ...
    summary_row.weighted_CRI_095(1), summary_row.paper_CRI_095(1), ...
    summary_row.invalid_stage_ratio(1), "diagnostic_only", ...
    'VariableNames', {'scenario_id', 'formulation', 'q_mode', 'total_ols_attempts', ...
    'successful_ols_count', 'failed_ols_count', 'failure_rate', 'mean_q_mismatch', ...
    'max_q_mismatch', 'max_positive_q_injection', 'basic_CRI_095', ...
    'weighted_CRI_095', 'paper_CRI_095', 'invalid_stage_ratio', 'recommendation'});
end

function chain_records = run_markov_records(base_mpc, cfg, scenario, renewable_info)
faults = enumerate_initial_faults(base_mpc);
chain_cells = cell(height(faults) * cfg.markov_num_trials_per_initial_fault, 1);
row = 0;
for f = 1:height(faults)
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        row = row + 1;
        chain_cells{row} = search_cascade_markov_line(base_mpc, faults.branch_index(f), cfg, scenario, renewable_info, trial_id);
    end
end
chain_records = vertcat(chain_cells{:});
end

function risk_samples_paper = build_paper_risk_samples(chain_summary_table, paper_severity)
initial_branch = chain_summary_table.initial_branch;
trial_id = chain_summary_table.trial_id;
sample_weight = ones(height(chain_summary_table), 1) / height(chain_summary_table);
sample_weight_source = repmat("paper_formula_internal_stage_probability", height(chain_summary_table), 1);
risk_samples_paper = table(initial_branch, trial_id, sample_weight, sample_weight_source);
risk_samples_paper = [risk_samples_paper, paper_severity];
end

function value = extract_cri(var_table, sigma_value)
idx = find(abs(var_table.sigma - sigma_value) < 1e-9, 1);
if isempty(idx), value = NaN; else, value = var_table.CRI(idx); end
end

function values = get_optional_numeric_column(tbl, field_name)
if ismember(field_name, tbl.Properties.VariableNames)
    values = tbl.(field_name);
else
    values = NaN(height(tbl), 1);
end
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
