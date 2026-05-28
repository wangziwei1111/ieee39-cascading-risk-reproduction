function main_run_ols_fixed_q_benchmark_smoke()
%MAIN_RUN_OLS_FIXED_Q_BENCHMARK_SMOKE Run fixed-zero-Q OLS diagnostic smoke.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
ensure_dir(table_dir);

cfg0 = base_config();
require_matpower(cfg0);
scenario_ids = ["distributed_wind_3000mw_base", ...
    "distributed_wind_penetration_40pct", "paper_wind_speed_12_00mps"];

rows = {};
for s = 1:numel(scenario_ids)
    fprintf('fixed_q_shed smoke: scenario=%s\n', scenario_ids(s));
    rows{end + 1, 1} = run_fixed_q_case(project_root, root_dir, cfg0, scenario_ids(s)); %#ok<AGROW>
end
fixed_summary = vertcat(rows{:});

delta = build_fixed_vs_free_delta(root_dir, fixed_summary);
writetable(delta, fullfile(table_dir, 'ols_fixed_q_vs_free_q_delta.csv'));
plot_ols_benchmark_smoke_figures(root_dir);
fprintf('OLS fixed-Q benchmark smoke written: %s\n', fullfile(table_dir, 'ols_fixed_q_vs_free_q_delta.csv'));
end

function summary_row = run_fixed_q_case(project_root, root_dir, cfg0, scenario_id)
cfg = cfg0;
cfg.markov_num_trials_per_initial_fault = 5;
cfg.markov_random_seed = cfg.seed;
cfg.load_shedding_mode = 'paper_ols';
cfg.load_shedding_trigger_mode = 'nonconverged_or_violation';
cfg.paper_ols_enable = true;
cfg.paper_ols_formulation = 'positive_injection_generator';
cfg.paper_ols_shed_gen_q_mode = 'fixed_zero_q';
cfg.paper_ols_fail_policy = 'fallback_to_simple_with_warning';
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
cfg.severity_mode = 'basic';

case_root = fullfile(root_dir, 'fixed_q_shed', char(scenario_id));
cfg.results_table_dir = fullfile(case_root, 'tables');
cfg.results_log_dir = fullfile(case_root, 'logs');
cfg.results_chain_dir = fullfile(case_root, 'chains');
cfg.results_figure_dir = fullfile(case_root, 'figures');
ensure_dir(cfg.results_table_dir); ensure_dir(cfg.results_log_dir);
ensure_dir(cfg.results_chain_dir); ensure_dir(cfg.results_figure_dir);

log_path = fullfile(cfg.results_log_dir, 'scenario_run_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'fixed_q_shed OLS benchmark smoke scenario=%s\n', scenario_id);
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

mean_q_mismatch = mean(ols_stage_details.q_mismatch_between_opf_and_applied, 'omitnan');
max_q_mismatch = max(ols_stage_details.q_mismatch_between_opf_and_applied, [], 'omitnan');
summary_row = table(string(scenario_id), "fixed_q_shed", 5, height(chain_summary_table), ...
    "paper_ols", "nonconverged_or_violation", "positive_injection_generator", "fixed_zero_q", ...
    ols_summary.total_ols_attempts(1), ols_summary.successful_ols_count(1), ...
    ols_summary.failed_ols_count(1), ols_summary.fallback_count(1), ...
    ols_summary.triggered_stage_count(1), ols_summary.nonconverged_trigger_count(1), ...
    ols_summary.line_overload_trigger_count(1), ols_summary.voltage_violation_trigger_count(1), ...
    mean_q_mismatch, max_q_mismatch, ols_summary.mean_objective_load_shed_mw(1), ...
    ols_summary.max_objective_load_shed_mw(1), extract_cri(var_basic, 0.95), ...
    extract_cri(var_weighted, 0.95), extract_cri(var_paper, 0.95), ...
    paper_result_status, invalid_stage_ratio, ...
    "5-trial fixed_zero_q diagnostic only; not final paper result.", ...
    'VariableNames', {'scenario_id', 'mode', 'markov_trials_per_initial_fault', 'chain_count', ...
    'load_shedding_mode', 'load_shedding_trigger_mode', 'paper_ols_formulation', ...
    'shed_gen_q_mode', 'total_ols_attempts', 'successful_ols_count', ...
    'failed_ols_count', 'fallback_count', 'triggered_stage_count', ...
    'nonconverged_trigger_count', 'line_overload_trigger_count', ...
    'voltage_violation_trigger_count', 'mean_q_mismatch', 'max_q_mismatch', ...
    'mean_objective_load_shed_mw', 'max_objective_load_shed_mw', ...
    'basic_CRI_095', 'weighted_CRI_095', 'paper_CRI_095', ...
    'paper_result_status', 'invalid_stage_ratio', 'note'});
save_result_table(summary_row, fullfile(cfg.results_table_dir, 'fixed_q_shed_summary.csv'), true);
fprintf(fid, 'chain_count=%d failed_ols=%d mean_q_mismatch=%.12g\n', ...
    height(chain_summary_table), ols_summary.failed_ols_count(1), mean_q_mismatch);
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

function delta = build_fixed_vs_free_delta(root_dir, fixed_summary)
rows = {};
metrics = ["total_ols_attempts", "successful_ols_count", "failed_ols_count", ...
    "failure_rate", "mean_q_mismatch", "max_q_mismatch", "basic_CRI_095", ...
    "weighted_CRI_095", "paper_CRI_095", "invalid_stage_ratio"];
for i = 1:height(fixed_summary)
    scenario_id = string(fixed_summary.scenario_id(i));
    free_summary_path = fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'ols_summary.csv');
    free_stage_path = fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'ols_stage_details.csv');
    free_summary = readtable(free_summary_path);
    free_stage = readtable(free_stage_path);
    free_var = readtable(fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'markov_var_metrics.csv'));
    free_wvar = readtable(fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'markov_var_metrics_weighted.csv'));
    free_pvar = readtable(fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'markov_var_metrics_paper_severity.csv'));
    free_invalid = readtable(fullfile(root_dir, 'paper_ols_violation', char(scenario_id), 'tables', 'markov_paper_invalid_stage_summary.csv'));
    fixed_values = row_values(fixed_summary(i, :));
    free_values = containers.Map();
    free_values('total_ols_attempts') = free_summary.total_ols_attempts(1);
    free_values('successful_ols_count') = free_summary.successful_ols_count(1);
    free_values('failed_ols_count') = free_summary.failed_ols_count(1);
    free_values('failure_rate') = free_summary.failed_ols_count(1) / max(free_summary.total_ols_attempts(1), 1);
    free_q_mismatch = get_optional_numeric_column(free_stage, 'q_mismatch_between_opf_and_applied');
    free_values('mean_q_mismatch') = mean(free_q_mismatch, 'omitnan');
    free_values('max_q_mismatch') = max(free_q_mismatch, [], 'omitnan');
    free_values('basic_CRI_095') = extract_cri(free_var, 0.95);
    free_values('weighted_CRI_095') = extract_cri(free_wvar, 0.95);
    free_values('paper_CRI_095') = extract_cri(free_pvar, 0.95);
    free_values('invalid_stage_ratio') = free_invalid.invalid_stage_ratio(1);
    for m = 1:numel(metrics)
        metric = metrics(m);
        fv = free_values(char(metric));
        zv = fixed_values(char(metric));
        delta_value = zv - fv;
        if abs(fv) > 1e-12
            relative_delta = delta_value / abs(fv);
        else
            relative_delta = NaN;
        end
        interpretation = interpret_fixed_delta(metric, fv, zv, fixed_summary.failed_ols_count(i));
        rows{end + 1, 1} = table(scenario_id, metric, fv, zv, delta_value, ...
            relative_delta, interpretation, ...
            'VariableNames', {'scenario_id', 'metric_name', 'free_q_value', ...
            'fixed_zero_q_value', 'delta_value', 'relative_delta', 'interpretation'}); %#ok<AGROW>
    end
end
delta = vertcat(rows{:});
end

function values = row_values(row)
values = containers.Map();
values('total_ols_attempts') = row.total_ols_attempts(1);
values('successful_ols_count') = row.successful_ols_count(1);
values('failed_ols_count') = row.failed_ols_count(1);
values('failure_rate') = row.failed_ols_count(1) / max(row.total_ols_attempts(1), 1);
values('mean_q_mismatch') = row.mean_q_mismatch(1);
values('max_q_mismatch') = row.max_q_mismatch(1);
values('basic_CRI_095') = row.basic_CRI_095(1);
values('weighted_CRI_095') = row.weighted_CRI_095(1);
values('paper_CRI_095') = row.paper_CRI_095(1);
values('invalid_stage_ratio') = row.invalid_stage_ratio(1);
end

function txt = interpret_fixed_delta(metric, free_value, fixed_value, failed_count)
if metric == "mean_q_mismatch" || metric == "max_q_mismatch"
    if fixed_value < free_value
        txt = "fixed_zero_q reduces Q mismatch; check success rate before adopting.";
    else
        txt = "fixed_zero_q does not reduce this Q mismatch metric.";
    end
elseif metric == "failed_ols_count" || metric == "failure_rate"
    if fixed_value < free_value
        txt = "fixed_zero_q reduces OLS failures in 5-trial diagnostic smoke.";
    elseif fixed_value > free_value
        txt = "fixed_zero_q increases OLS failures; do not adopt without more diagnosis.";
    else
        txt = "fixed_zero_q does not change OLS failure count.";
    end
elseif contains(metric, "CRI")
    txt = "CRI direction is diagnostic only; do not use as final paper result.";
elseif failed_count > 0
    txt = "fixed_zero_q still has OLS failures; diagnostic only.";
else
    txt = "diagnostic metric comparison.";
end
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
