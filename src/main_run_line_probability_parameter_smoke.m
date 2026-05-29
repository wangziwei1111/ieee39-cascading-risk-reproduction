function main_run_line_probability_parameter_smoke()
%MAIN_RUN_LINE_PROBABILITY_PARAMETER_SMOKE Small Markov smoke for P_L parameter sets.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'outage');
smoke_root = fullfile(out_root, 'line_probability_parameter_smoke');
if ~exist(smoke_root, 'dir'), mkdir(smoke_root); end

cfg0 = base_config();
require_matpower(cfg0);
parameter_sets = ["engineering"; "table41_P_L0_only"; ...
    "low_hidden_failure_diagnostic"; "medium_hidden_failure_diagnostic"];
rows = {};
for i = 1:numel(parameter_sets)
    rows{end+1,1} = run_one(project_root, smoke_root, cfg0, parameter_sets(i)); %#ok<AGROW>
end
summary = vertcat(rows{:});
writetable(summary, fullfile(out_root, 'line_probability_parameter_smoke_summary.csv'));
fprintf('line probability parameter smoke written: %s\n', fullfile(out_root, 'line_probability_parameter_smoke_summary.csv'));
end

function summary_row = run_one(project_root, smoke_root, cfg0, parameter_set_id)
cfg = cfg0;
cfg.markov_num_trials_per_initial_fault = 3;
cfg.markov_random_seed = cfg.seed;
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
cfg.severity_mode = 'basic';
if parameter_set_id == "engineering"
    cfg.line_outage_probability_model = 'engineering';
    calibration_status = "engineering_baseline";
else
    cfg = load_paper_line_probability_parameter_set(cfg, parameter_set_id);
    cfg.line_outage_probability_model = 'paper_formula';
    cfg.paper_line_missing_param_policy = 'fallback_to_engineering_with_warning';
    calibration_status = string(cfg.paper_line_parameter_calibration_status);
end
rng(cfg.markov_random_seed);

case_root = fullfile(smoke_root, char(parameter_set_id));
table_dir = fullfile(case_root, 'tables');
log_dir = fullfile(case_root, 'logs');
chain_dir = fullfile(case_root, 'chains');
ensure_dir(table_dir); ensure_dir(log_dir); ensure_dir(chain_dir);

base_mpc0 = build_case39_base(cfg);
scenario = get_scenario_by_id('distributed_wind_3000mw_base', cfg, sum(base_mpc0.bus(:,3)));
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);
initial_probability_table = load_initial_line_probabilities(cfg, base_mpc);
initial_probability_table_smoke = subset_initial_probability_table(initial_probability_table, 1:5);

chain_records = run_markov_records(base_mpc, cfg, scenario, renewable_info);
[chain_summary_table, ~] = flatten_chain_records(chain_records, cfg);
candidate_details = flatten_candidate_tables(chain_records);

save(fullfile(chain_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', '-v7.3');
writetable(chain_summary_table, fullfile(table_dir, 'markov_chain_summary.csv'));
writetable(candidate_details, fullfile(table_dir, 'candidate_probability_details.csv'));

cfg.var_use_chain_weights = false;
risk_samples = build_markov_risk_samples(chain_summary_table, cfg);
var_basic = calc_markov_var_metrics(risk_samples, cfg, 'basic');
writetable(risk_samples, fullfile(table_dir, 'markov_risk_samples.csv'));
writetable(var_basic, fullfile(table_dir, 'markov_var_metrics.csv'));

cfg.var_use_chain_weights = true;
risk_samples_weighted = build_markov_risk_samples(chain_summary_table, cfg, initial_probability_table_smoke);
var_weighted = calc_markov_var_metrics(risk_samples_weighted, cfg, 'basic');
writetable(var_weighted, fullfile(table_dir, 'markov_var_metrics_weighted.csv'));

cfg.var_use_chain_weights = false;
cfg.severity_mode = 'paper_formula';
cfg.enable_paper_severity = true;
cfg.paper_severity_formula_confirmed = true;
[line_flow_detail_table, bus_voltage_detail_table, stage_probability_table, ~, invalid_stage_summary_table] = ...
    build_markov_paper_detail_tables(chain_records, base_mpc, cfg, scenario, renewable_info, initial_probability_table_smoke);
paper_severity = calc_paper_chain_severity(chain_summary_table, cfg, ...
    line_flow_detail_table, bus_voltage_detail_table, stage_probability_table);
risk_samples_paper = build_paper_risk_samples(chain_summary_table, paper_severity, initial_probability_table_smoke);
var_paper = calc_markov_var_metrics(risk_samples_paper, cfg, 'paper');
invalid_stage_ratio = invalid_stage_summary_table.invalid_stage_ratio(1);
paper_result_status = "valid";
if invalid_stage_ratio > cfg.paper_max_invalid_chain_ratio_for_var || any(isnan(risk_samples_paper.paper_CRI))
    paper_result_status = "diagnostic_only";
end
var_paper.result_status = repmat(paper_result_status, height(var_paper), 1);
writetable(var_paper, fullfile(table_dir, 'markov_var_metrics_paper_severity.csv'));
writetable(invalid_stage_summary_table, fullfile(table_dir, 'markov_paper_invalid_stage_summary.csv'));

fallback_count = count_fallback(candidate_details);
recommendation = recommend(parameter_set_id, fallback_count, calibration_status);
summary_row = table(parameter_set_id, string(cfg.line_outage_probability_model), ...
    cfg.markov_num_trials_per_initial_fault, height(chain_summary_table), ...
    height(candidate_details), fallback_count, ...
    mean(candidate_details.outage_probability, 'omitnan'), ...
    max(candidate_details.outage_probability, [], 'omitnan'), ...
    extract_cri(var_basic), extract_cri(var_weighted), extract_cri(var_paper), ...
    paper_result_status, invalid_stage_ratio, calibration_status, recommendation, ...
    'VariableNames', {'parameter_set_id', 'model_type', 'markov_trials_per_initial_fault', ...
    'chain_count', 'candidate_count', 'fallback_count', ...
    'mean_candidate_probability', 'max_candidate_probability', ...
    'basic_CRI_095', 'weighted_CRI_095', 'paper_CRI_095', ...
    'paper_result_status', 'invalid_stage_ratio', 'calibration_status', 'recommendation'});
write_log(fullfile(log_dir, 'smoke_run_log.txt'), summary_row);
end

function chain_records = run_markov_records(base_mpc, cfg, scenario, renewable_info)
chain_cells = {};
idx = 0;
for b = 1:5
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        chain_cells{idx,1} = search_cascade_markov_line(base_mpc, b, cfg, scenario, renewable_info, trial_id); %#ok<AGROW>
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

function subset = subset_initial_probability_table(initial_probability_table, branch_indices)
subset = initial_probability_table(ismember(initial_probability_table.branch_index, branch_indices), :);
if isempty(subset)
    error('Initial probability subset is empty.');
end
subset.normalized_weight = subset.normalized_weight ./ sum(subset.normalized_weight);
end

function value = extract_cri(var_table)
idx = find(abs(var_table.sigma - 0.95) < 1e-9, 1);
if isempty(idx), value = NaN; else, value = var_table.CRI(idx); end
end

function n = count_fallback(candidate_details)
if isempty(candidate_details) || ~ismember('paper_formula_used_fallback', candidate_details.Properties.VariableNames)
    n = 0;
else
    n = sum(logical(candidate_details.paper_formula_used_fallback));
end
end

function recommendation = recommend(parameter_set_id, fallback_count, calibration_status)
if parameter_set_id == "strict_missing"
    recommendation = "not_usable_missing_parameters";
elseif fallback_count > 0
    recommendation = "requires_parameter_completion";
elseif calibration_status == "diagnostic_assumption_not_paper"
    recommendation = "diagnostic_only_not_for_formal_benchmark";
else
    recommendation = "diagnostic_only_not_for_formal_benchmark";
end
end

function write_log(path, row)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'line probability parameter smoke\n');
fprintf(fid, 'parameter_set_id=%s\n', row.parameter_set_id);
fprintf(fid, 'chain_count=%d\n', row.chain_count);
fprintf(fid, 'fallback_count=%d\n', row.fallback_count);
fprintf(fid, 'recommendation=%s\n', row.recommendation);
fprintf(fid, 'note=Diagnostic 5x3 smoke only; not final benchmark.\n');
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
