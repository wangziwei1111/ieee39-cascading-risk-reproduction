function main_run_ols_benchmark_smoke()
%MAIN_RUN_OLS_BENCHMARK_SMOKE Compare simple and paper_ols_violation modes.
% This 5-trial smoke run writes only under results/loadshedding and is not a
% final thesis result.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
log_dir = fullfile(root_dir, 'logs');
figure_dir = fullfile(root_dir, 'figures');
ensure_dir(table_dir); ensure_dir(log_dir); ensure_dir(figure_dir);

cfg0 = base_config();
require_matpower(cfg0);
scenario_ids = ["distributed_wind_3000mw_base", ...
    "distributed_wind_penetration_40pct", "paper_wind_speed_12_00mps"];
mode_defs = build_mode_defs();

summary_rows = {};
for s = 1:numel(scenario_ids)
    for m = 1:numel(mode_defs)
        scenario_id = scenario_ids(s);
        mode_def = mode_defs(m);
        fprintf('OLS benchmark smoke: scenario=%s mode=%s\n', scenario_id, mode_def.mode_id);
        summary_rows{end + 1, 1} = run_one_case(project_root, root_dir, cfg0, scenario_id, mode_def); %#ok<AGROW>
    end
end

summary_table = vertcat(summary_rows{:});
save_result_table(summary_table, fullfile(table_dir, 'ols_benchmark_smoke_summary.csv'), true);

delta_table = build_delta_table(summary_table);
save_result_table(delta_table, fullfile(table_dir, 'ols_vs_simple_delta.csv'), true);

benchmark_table = build_paper_benchmark_comparison(project_root, summary_table);
save_result_table(benchmark_table, fullfile(table_dir, 'ols_smoke_vs_paper_benchmark.csv'), true);

plot_ols_benchmark_smoke_figures(root_dir);
write_overall_log(fullfile(log_dir, 'ols_benchmark_smoke_run_log.txt'), summary_table, delta_table);
end

function mode_defs = build_mode_defs()
mode_defs = struct([]);
mode_defs(1).mode_id = "simple";
mode_defs(1).load_shedding_mode = 'simple';
mode_defs(1).trigger_mode = 'nonconverged_only';
mode_defs(1).paper_ols_enable = false;
mode_defs(1).fail_policy = 'fallback_to_simple_with_warning';
mode_defs(2).mode_id = "paper_ols_violation";
mode_defs(2).load_shedding_mode = 'paper_ols';
mode_defs(2).trigger_mode = 'nonconverged_or_violation';
mode_defs(2).paper_ols_enable = true;
mode_defs(2).fail_policy = 'fallback_to_simple_with_warning';
end

function summary_row = run_one_case(project_root, root_dir, cfg0, scenario_id, mode_def)
cfg = cfg0;
cfg.markov_num_trials_per_initial_fault = 5;
cfg.markov_random_seed = cfg.seed;
cfg.load_shedding_mode = mode_def.load_shedding_mode;
cfg.load_shedding_trigger_mode = mode_def.trigger_mode;
cfg.paper_ols_enable = mode_def.paper_ols_enable;
cfg.paper_ols_fail_policy = mode_def.fail_policy;
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
cfg.severity_mode = 'basic';

case_root = fullfile(root_dir, char(mode_def.mode_id), char(scenario_id));
cfg.results_table_dir = fullfile(case_root, 'tables');
cfg.results_log_dir = fullfile(case_root, 'logs');
cfg.results_chain_dir = fullfile(case_root, 'chains');
cfg.results_figure_dir = fullfile(case_root, 'figures');
ensure_dir(cfg.results_table_dir); ensure_dir(cfg.results_log_dir);
ensure_dir(cfg.results_chain_dir); ensure_dir(cfg.results_figure_dir);

log_path = fullfile(cfg.results_log_dir, 'scenario_run_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'OLS benchmark smoke scenario=%s mode=%s\n', scenario_id, mode_def.mode_id);
fprintf(fid, '5-trial smoke only, not final thesis result.\n');

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
risk_samples_paper = build_paper_risk_samples(chain_summary_table, paper_severity, initial_probability_table);
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

basic_CRI_095 = extract_cri(var_basic, 0.95);
weighted_CRI_095 = extract_cri(var_weighted, 0.95);
paper_CRI_095 = extract_cri(var_paper, 0.95);

note = "5-trial OLS benchmark smoke, not final paper result.";
if ols_summary.fallback_count(1) > 0
    note = note + " OLS fallback exists; diagnostic only.";
end
if ols_summary.failed_ols_count(1) > 0
    note = note + " Some OLS attempts failed; see ols_stage_details.csv messages.";
end
summary_row = table(string(scenario_id), string(mode_def.mode_id), cfg.markov_num_trials_per_initial_fault, ...
    height(chain_summary_table), string(cfg.load_shedding_mode), string(cfg.load_shedding_trigger_mode), ...
    logical(cfg.paper_ols_enable), string(cfg.paper_ols_fail_policy), ...
    ols_summary.total_ols_attempts(1), ols_summary.successful_ols_count(1), ...
    ols_summary.failed_ols_count(1), ols_summary.fallback_count(1), ...
    ols_summary.triggered_stage_count(1), ols_summary.nonconverged_trigger_count(1), ...
    ols_summary.line_overload_trigger_count(1), ols_summary.voltage_violation_trigger_count(1), ...
    ols_summary.mean_objective_load_shed_mw(1), ols_summary.max_objective_load_shed_mw(1), ...
    basic_CRI_095, weighted_CRI_095, paper_CRI_095, paper_result_status, invalid_stage_ratio, note, ...
    'VariableNames', {'scenario_id', 'mode', 'markov_trials_per_initial_fault', 'chain_count', ...
    'load_shedding_mode', 'load_shedding_trigger_mode', 'paper_ols_enable', 'paper_ols_fail_policy', ...
    'total_ols_attempts', 'successful_ols_count', 'failed_ols_count', 'fallback_count', ...
    'triggered_stage_count', 'nonconverged_trigger_count', 'line_overload_trigger_count', ...
    'voltage_violation_trigger_count', 'mean_objective_load_shed_mw', 'max_objective_load_shed_mw', ...
    'basic_CRI_095', 'weighted_CRI_095', 'paper_CRI_095', 'paper_result_status', ...
    'invalid_stage_ratio', 'note'});
fprintf(fid, 'chain_count=%d basic_CRI_095=%.12g weighted_CRI_095=%.12g paper_CRI_095=%.12g\n', ...
    height(chain_summary_table), basic_CRI_095, weighted_CRI_095, paper_CRI_095);
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

function risk_samples_paper = build_paper_risk_samples(chain_summary_table, paper_severity, initial_probability_table)
initial_branch = chain_summary_table.initial_branch;
trial_id = chain_summary_table.trial_id;
initial_branch_weight = zeros(height(chain_summary_table), 1);
for i = 1:height(chain_summary_table)
    row = initial_probability_table(initial_probability_table.branch_index == initial_branch(i), :);
    initial_branch_weight(i) = row.normalized_weight(1);
end
num_trials_for_initial_branch = zeros(height(chain_summary_table), 1);
branches = unique(initial_branch);
for b = 1:numel(branches)
    mask = initial_branch == branches(b);
    num_trials_for_initial_branch(mask) = sum(mask);
end
sample_weight = ones(height(chain_summary_table), 1) / height(chain_summary_table);
sample_weight_source = repmat("paper_formula_internal_stage_probability", height(chain_summary_table), 1);
risk_samples_paper = table(initial_branch, trial_id, initial_branch_weight, ...
    num_trials_for_initial_branch, sample_weight, sample_weight_source);
risk_samples_paper = [risk_samples_paper, paper_severity];
end

function value = extract_cri(var_table, sigma_value)
idx = find(abs(var_table.sigma - sigma_value) < 1e-9, 1);
if isempty(idx)
    value = NaN;
else
    value = var_table.CRI(idx);
end
end

function delta_table = build_delta_table(summary_table)
metrics = ["basic_CRI_095", "weighted_CRI_095", "paper_CRI_095", "invalid_stage_ratio", ...
    "triggered_stage_count", "total_ols_attempts", "successful_ols_count", "failed_ols_count", ...
    "fallback_count", "mean_objective_load_shed_mw", "max_objective_load_shed_mw"];
rows = {};
scenarios = unique(summary_table.scenario_id, 'stable');
for s = 1:numel(scenarios)
    simple = summary_table(summary_table.scenario_id == scenarios(s) & summary_table.mode == "simple", :);
    ols = summary_table(summary_table.scenario_id == scenarios(s) & summary_table.mode == "paper_ols_violation", :);
    for m = 1:numel(metrics)
        sv = simple.(char(metrics(m)))(1);
        ov = ols.(char(metrics(m)))(1);
        delta = ov - sv;
        if abs(sv) > 1e-12
            rel = delta / abs(sv);
        else
            rel = NaN;
        end
        interp = interpret_delta(metrics(m), sv, ov, ols.fallback_count(1));
        rows{end + 1, 1} = table(scenarios(s), metrics(m), sv, ov, delta, rel, interp, ...
            'VariableNames', {'scenario_id', 'metric_name', 'simple_value', ...
            'paper_ols_violation_value', 'delta_value', 'relative_delta', 'interpretation'}); %#ok<AGROW>
    end
end
delta_table = vertcat(rows{:});
end

function txt = interpret_delta(metric, sv, ov, fallback_count)
if fallback_count > 0
    txt = "OLS fallback exists; diagnostic only.";
elseif contains(metric, "CRI")
    if ov < sv
        txt = "OLS constraint correction lowers the current risk indicator; interpret with paper scale checks.";
    elseif ov > sv
        txt = "OLS introduces load shedding or violation constraints that raise the current risk indicator.";
    else
        txt = "No visible difference between OLS and simple for this metric.";
    end
else
    txt = "Small-sample diagnostic metric difference; directionality only.";
end
end

function benchmark_table = build_paper_benchmark_comparison(project_root, summary_table)
bench = readtable(fullfile(project_root, 'paper_inputs', 'filled', 'paper_result_benchmark.csv'));
maps = {
    "Table 4-4", "distributed_3000mw", "distributed_wind_3000mw_base";
    "Table 4-5", "penetration_40pct", "distributed_wind_penetration_40pct";
    "Table 4-6", "wind_speed_12_00mps", "paper_wind_speed_12_00mps"
    };
rows = {};
for i = 1:size(maps, 1)
    paper_table = maps{i, 1};
    paper_scenario = maps{i, 2};
    repro_scenario = maps{i, 3};
    mask = string(bench.paper_figure_or_table) == paper_table & ...
        string(bench.scenario_id) == paper_scenario & string(bench.metric_name) == "CRI";
    if any(mask)
        paper_CRI = bench.paper_value(find(mask, 1));
        paper_unit = string(bench.unit(find(mask, 1)));
    else
        paper_CRI = NaN;
        paper_unit = "10^-4";
    end
    simple = summary_table(summary_table.scenario_id == repro_scenario & summary_table.mode == "simple", :);
    ols = summary_table(summary_table.scenario_id == repro_scenario & summary_table.mode == "paper_ols_violation", :);
    rows{end + 1, 1} = table(string(paper_table), string(paper_scenario), string(repro_scenario), ...
        paper_CRI, paper_unit, simple.paper_CRI_095(1), ols.paper_CRI_095(1), ...
        simple.weighted_CRI_095(1), ols.weighted_CRI_095(1), ...
        "comparable_with_caution", ...
        "raw comparison / unit alignment pending; 5-trial smoke only; OLS directionality diagnostic.", ...
        'VariableNames', {'paper_table', 'paper_scenario_id', 'reproduction_scenario_id', ...
        'paper_CRI', 'paper_unit', 'simple_paper_formula_CRI', ...
        'paper_ols_violation_paper_formula_CRI', 'simple_weighted_CRI', ...
        'paper_ols_violation_weighted_CRI', 'comparison_status', 'diagnosis_note'}); %#ok<AGROW>
end
benchmark_table = vertcat(rows{:});
end

function write_overall_log(log_path, summary_table, delta_table)
fid = fopen(log_path, 'w');
if fid < 0
    warning('Unable to write OLS benchmark smoke log: %s', log_path);
    return;
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'OLS benchmark smoke run log\n');
fprintf(fid, 'generated_at=%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, 'summary rows=%d delta rows=%d\n', height(summary_table), height(delta_table));
fprintf(fid, 'note=5-trial smoke only, not final paper result.\n');
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
