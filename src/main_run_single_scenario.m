function scenario_result = main_run_single_scenario(scenario_id, run_options)
%MAIN_RUN_SINGLE_SCENARIO 运行一个第4章场景的隔离式smoke/full流程。
% 输入：
%   scenario_id - 场景编号。
%   run_options - 可选结构体，可覆盖markov_num_trials_per_initial_fault等运行参数。
% 输出：
%   scenario_result - 单场景汇总结果。
% 物理含义：
%   每个场景独立完成基础潮流、N-1、Markov、basic/weighted/paper VaR和自检所需表格。
%   输出全部写入 results/scenarios/<scenario_id>/，不覆盖全局基准结果。

if nargin < 2
    run_options = struct();
end

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg = configure_scenario_output_dirs(cfg, project_root, scenario_id);
cfg.markov_random_seed = cfg.seed;
if isfield(run_options, 'markov_num_trials_per_initial_fault')
    cfg.markov_num_trials_per_initial_fault = run_options.markov_num_trials_per_initial_fault;
end
if isfield(run_options, 'smoke_note')
    cfg.scenario_run_note = run_options.smoke_note;
else
    cfg.scenario_run_note = '';
end

ensure_dirs(cfg);
log_path = fullfile(cfg.results_log_dir, 'scenario_run_log.txt');
diary(log_path);
diary on;

scenario_result = init_scenario_result(scenario_id, cfg);
try
    fprintf('开始运行场景：%s\n', scenario_id);
    require_matpower(cfg);
    base_mpc = build_case39_base(cfg);
    base_load_mw = sum(base_mpc.bus(:, 3));
    scenario = get_scenario_by_id(scenario_id, cfg, base_load_mw);
    if isfield(scenario, 'renewable_trip_enable')
        cfg.enable_wind_voltage_trip_sampling = logical(scenario.renewable_trip_enable);
    end
    save_scenario_metadata(scenario, cfg, fullfile(fileparts(cfg.results_table_dir), 'config'));

    [scenario_mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
    basecase_table = run_basecase_validation_scenario(scenario_mpc, cfg, renewable_info);
    basecase_converged = logical(basecase_table.basecase_converged(1));
    run_minimal_n1_scenario(scenario_mpc, cfg, scenario, renewable_info, base_load_mw);
    chain_records = run_markov_line_scenario(scenario_mpc, cfg, scenario, renewable_info, base_load_mw);
    run_basic_risk_scenario(scenario_mpc, cfg);
    run_weighted_risk_scenario(scenario_mpc, cfg);
    run_paper_risk_scenario(chain_records, scenario_mpc, cfg, scenario, renewable_info);
    run_uniform_weighted_compare_scenario(cfg);
    run_basic_paper_compare_scenario(cfg);

    scenario_result = build_scenario_result(scenario_id, scenario, cfg, basecase_converged, 'success', '');
    fprintf('场景运行完成：%s\n', scenario_id);
catch ME
    scenario_result = build_failed_result(scenario_id, cfg, ME);
    fprintf(2, '场景运行失败：%s\n%s\n', scenario_id, getReport(ME, 'extended', 'hyperlinks', 'off'));
end

diary off;
end

function cfg = configure_scenario_output_dirs(cfg, project_root, scenario_id)
cfg.project_root = project_root;
scenario_root = fullfile(project_root, cfg.scenario_results_root, scenario_id);
cfg.results_table_dir = fullfile(scenario_root, 'tables');
cfg.results_log_dir = fullfile(scenario_root, 'logs');
cfg.results_chain_dir = fullfile(scenario_root, 'chains');
cfg.results_figure_dir = fullfile(scenario_root, 'figures');
cfg.scenario_config_dir = fullfile(scenario_root, 'config');
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
end

function ensure_dirs(cfg)
dirs = {cfg.results_table_dir, cfg.results_log_dir, cfg.results_chain_dir, cfg.results_figure_dir, cfg.scenario_config_dir};
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir')
        mkdir(dirs{k});
    end
end
end

function result = init_scenario_result(scenario_id, cfg)
result = struct('scenario_id', string(scenario_id), 'total_wind_capacity_mw', NaN, ...
    'wind_buses', "", 'wind_speed_mps', NaN, 'renewable_dispatch_mode', "", ...
    'markov_trials_per_initial_fault', cfg.markov_num_trials_per_initial_fault, ...
    'basecase_converged', false, 'chain_count', 0, 'invalid_stage_ratio', NaN, ...
    'basic_CRI_095', NaN, 'weighted_CRI_095', NaN, 'paper_CRI_095', NaN, ...
    'status', "failed", 'note', "");
end

function basecase_table = run_basecase_validation_scenario(mpc, cfg, renewable_info)
% 无故障基础运行点校验。
[pf_result, converged] = run_ac_powerflow(mpc);
violations = check_violations(pf_result, cfg);
gen_status = mpc.gen(:, 8) > 0;
slack_bus = mpc.bus(mpc.bus(:, 2) == 3, 1);
if isempty(slack_bus)
    slack_bus = NaN;
end
slack_rows = find(mpc.gen(:, 1) == slack_bus(1) & gen_status);
slack_pg = NaN;
if converged && ~isempty(slack_rows)
    slack_pg = sum(pf_result.gen(slack_rows, 2));
end
pg_above_pmax = sum(mpc.gen(gen_status, 2) > mpc.gen(gen_status, 9) + 1e-6);
pg_below_pmin = sum(mpc.gen(gen_status, 2) < mpc.gen(gen_status, 10) - 1e-6);

basecase_table = table(sum(mpc.bus(:, 3)), sum(mpc.gen(gen_status, 2)), ...
    renewable_info.total_wind_output_mw, slack_pg, converged, pg_above_pmax, pg_below_pmin, ...
    violations.num_overloaded_lines, violations.num_voltage_violations, ...
    'VariableNames', {'total_load_mw', 'total_generation_setpoint_mw', 'total_wind_output_mw', ...
    'slack_pg_mw', 'basecase_converged', 'pg_above_pmax_count', 'pg_below_pmin_count', ...
    'base_overloaded_line_count', 'base_voltage_violation_count'});
save_result_table(basecase_table, fullfile(cfg.results_table_dir, 'basecase_validation.csv'), true);
end

function run_minimal_n1_scenario(base_mpc, cfg, scenario, renewable_info, base_load_mw)
% 场景内N-1最小闭环。
faults = enumerate_initial_faults(base_mpc);
rows = cell(height(faults), 1);
island_rows = cell(height(faults), 1);
for i = 1:height(faults)
    branch_idx = faults.branch_index(i);
    mpc_fault = base_mpc;
    mpc_fault.branch(branch_idx, 11) = 0;
    [mpc_norm, island_info] = normalize_case_after_contingency(mpc_fault, cfg, scenario, renewable_info);
    [pf_result, converged_before] = run_ac_powerflow(mpc_norm);
    shed = empty_shed(island_info.disconnected_load_mw);
    converged_after = converged_before;
    if ~converged_before
        [~, pf_result, shed] = simple_load_shedding(mpc_norm, cfg, island_info.disconnected_load_mw);
        converged_after = logical(shed.converged_after_shed);
    end
    violations = check_violations(pf_result, cfg);
    metrics = calc_basic_risk_metrics(pf_result, violations, shed, base_load_mw);
    cri = calc_cri(metrics.SLLR, metrics.SLFOR, metrics.SNVOR, cfg.risk_weights);
    rows{i} = table(branch_idx, faults.from_bus(i), faults.to_bus(i), ...
        island_info.island_count, island_info.main_island_id, island_info.disconnected_load_mw, ...
        island_info.disconnected_generation_mw, island_info.disconnected_wind_mw, ...
        island_info.original_slack_in_main_island, island_info.new_slack_bus, ...
        converged_before, converged_after, shed.corrective_load_shed_mw, shed.total_load_shed_mw, ...
        violations.num_overloaded_lines, violations.max_line_loading_pu, ...
        violations.num_voltage_violations, violations.max_voltage_deviation_pu, ...
        metrics.SLLR, metrics.SLFOR, metrics.SNVOR, cri, ...
        island_info.main_island_load_share, island_info.original_slack_island_load_share, ...
        string(island_info.main_island_selection_reason), ...
        'VariableNames', {'branch_index', 'from_bus', 'to_bus', 'island_count', 'main_island_id', ...
        'disconnected_load_mw', 'disconnected_generation_mw', 'disconnected_wind_mw', ...
        'original_slack_in_main_island', 'new_slack_bus', 'pf_converged_before_shedding', ...
        'pf_converged_after_shedding', 'corrective_load_shed_mw', 'load_shed_mw', ...
        'num_overloaded_lines', 'max_line_loading_pu', 'num_voltage_violations', ...
        'max_voltage_deviation_pu', 'SLLR', 'SLFOR', 'SNVOR', 'CRI', ...
        'main_island_load_share', 'original_slack_island_load_share', 'main_island_selection_reason'});
    island_rows{i} = table(branch_idx, faults.from_bus(i), faults.to_bus(i), ...
        island_info.island_count, island_info.main_island_id, island_info.disconnected_load_mw, ...
        island_info.disconnected_generation_mw, island_info.disconnected_wind_mw, ...
        island_info.new_slack_bus, island_info.main_island_load_mw, island_info.main_island_load_share, ...
        island_info.main_island_generation_mw, island_info.main_island_gen_share, ...
        island_info.original_slack_island_id, island_info.original_slack_island_load_mw, ...
        island_info.original_slack_island_load_share, island_info.original_slack_island_generation_mw, ...
        string(island_info.main_island_selection_reason), ...
        'VariableNames', {'branch_index', 'from_bus', 'to_bus', 'island_count', 'main_island_id', ...
        'disconnected_load_mw', 'disconnected_generation_mw', 'disconnected_wind_mw', ...
        'new_slack_bus', 'main_island_load_mw', 'main_island_load_share', ...
        'main_island_generation_mw', 'main_island_gen_share', 'original_slack_island_id', ...
        'original_slack_island_load_mw', 'original_slack_island_load_share', ...
        'original_slack_island_generation_mw', 'main_island_selection_reason'});
end
save_result_table(vertcat(rows{:}), fullfile(cfg.results_table_dir, 'minimal_result.csv'), true);
save_result_table(vertcat(island_rows{:}), fullfile(cfg.results_table_dir, 'island_diagnostics.csv'), true);
end

function chain_records = run_markov_line_scenario(base_mpc, cfg, scenario, renewable_info, base_load_mw)
% 场景内Markov线路事故链搜索。
rng(cfg.markov_random_seed);
faults = enumerate_initial_faults(base_mpc);
num_chains = height(faults) * cfg.markov_num_trials_per_initial_fault;
chain_cells = cell(num_chains, 1);
idx = 0;
for f = 1:height(faults)
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        chain_cells{idx} = search_cascade_markov_line(base_mpc, faults.branch_index(f), cfg, scenario, renewable_info, trial_id);
    end
end
chain_records = vertcat(chain_cells{:});

[chain_summary_table, chain_stage_table] = flatten_chain_records(chain_records, cfg);
candidate_detail_table = flatten_candidate_tables(chain_records);
candidate_summary_table = summarize_candidate_details(candidate_detail_table);
candidate_sample_table = build_candidate_sample(candidate_detail_table);

save_result_table(chain_summary_table, fullfile(cfg.results_table_dir, 'markov_chain_summary.csv'), true);
save_result_table(chain_stage_table, fullfile(cfg.results_table_dir, 'markov_chain_stages.csv'), true);
save_result_table(candidate_detail_table, fullfile(cfg.results_table_dir, 'markov_candidate_details.csv'), true);
save_result_table(candidate_summary_table, fullfile(cfg.results_table_dir, 'markov_candidate_summary.csv'), true);
save_result_table(candidate_sample_table, fullfile(cfg.results_table_dir, 'markov_candidate_details_sample.csv'), true);

manifest = save_table_chunks(candidate_detail_table, fullfile(cfg.results_table_dir, 'candidate_chunks'), ...
    'markov_candidate_details', cfg.candidate_detail_chunk_size);
save_result_table(manifest, fullfile(cfg.results_table_dir, 'markov_candidate_details_manifest.csv'), true);

save(fullfile(cfg.results_chain_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', 'renewable_info', 'base_load_mw', '-v7');
end

function run_basic_risk_scenario(mpc, cfg)
% 等权basic VaR。
cfg_basic = cfg;
cfg_basic.var_use_chain_weights = false;
cfg_basic.initial_fault_probability_mode = 'uniform';
chain_summary_table = readtable(fullfile(cfg.results_table_dir, 'markov_chain_summary.csv'));
initial_probability_table = load_initial_line_probabilities(cfg_basic, mpc);
risk_samples = build_markov_risk_samples(chain_summary_table, cfg_basic, initial_probability_table);
markov_var_table = calc_markov_var_metrics(risk_samples, cfg_basic, 'basic');
by_initial_table = calc_markov_var_by_initial_fault(risk_samples, cfg_basic, 'basic');
save_result_table(risk_samples, fullfile(cfg.results_table_dir, 'markov_risk_samples.csv'), true);
save_result_table(markov_var_table, fullfile(cfg.results_table_dir, 'markov_var_metrics.csv'), true);
save_result_table(by_initial_table, fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault.csv'), true);
plot_markov_var_summary(markov_var_table, by_initial_table, cfg_basic);
end

function run_weighted_risk_scenario(mpc, cfg)
% 表4-1初始停运概率加权VaR。
cfg_weighted = cfg;
cfg_weighted.var_use_chain_weights = true;
cfg_weighted.initial_fault_probability_mode = 'paper_table_4_1';
cfg_weighted.initial_fault_probability_file = fullfile(cfg.project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
chain_summary_table = readtable(fullfile(cfg.results_table_dir, 'markov_chain_summary.csv'));
initial_probability_table = load_initial_line_probabilities(cfg_weighted, mpc);
risk_samples = build_markov_risk_samples(chain_summary_table, cfg_weighted, initial_probability_table);
markov_var_table = calc_markov_var_metrics(risk_samples, cfg_weighted, 'basic');
by_initial_table = calc_markov_var_by_initial_fault(risk_samples, cfg_weighted, 'basic');
save_result_table(risk_samples, fullfile(cfg.results_table_dir, 'markov_risk_samples_weighted.csv'), true);
save_result_table(markov_var_table, fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv'), true);
save_result_table(by_initial_table, fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_weighted.csv'), true);
end

function run_paper_risk_scenario(chain_records, mpc, cfg, scenario, renewable_info)
% line-only paper_formula严重度与VaR。
cfg_paper = cfg;
cfg_paper.severity_mode = 'paper_formula';
cfg_paper.enable_paper_severity = true;
cfg_paper.paper_severity_formula_confirmed = true;
cfg_paper.var_use_chain_weights = false;
cfg_paper.initial_fault_probability_mode = 'paper_table_4_1';
cfg_paper.initial_fault_probability_file = fullfile(cfg.project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');

initial_probability_table = load_initial_line_probabilities(cfg_paper, mpc);
[line_flow_detail_table, bus_voltage_detail_table, stage_probability_table, invalid_stage_detail_table, invalid_stage_summary_table] = ...
    build_markov_paper_detail_tables(chain_records, mpc, cfg_paper, scenario, renewable_info, initial_probability_table);
[line_summary, bus_summary, stage_summary] = summarize_paper_detail_tables(line_flow_detail_table, bus_voltage_detail_table, stage_probability_table, invalid_stage_detail_table);
[line_sample, bus_sample] = build_paper_detail_samples(line_flow_detail_table, bus_voltage_detail_table);

export_paper_detail_table(line_flow_detail_table, line_sample, line_summary, cfg_paper, 'markov_line_flow_details');
export_paper_detail_table(bus_voltage_detail_table, bus_sample, bus_summary, cfg_paper, 'markov_bus_voltage_details');
save_result_table(stage_probability_table, fullfile(cfg.results_table_dir, 'markov_stage_probability_details.csv'), true);
save_result_table(stage_summary, fullfile(cfg.results_table_dir, 'markov_stage_probability_summary.csv'), true);
save_result_table(invalid_stage_detail_table, fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_details.csv'), true);
save_result_table(invalid_stage_summary_table, fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_summary.csv'), true);

chain_summary_table = readtable(fullfile(cfg.results_table_dir, 'markov_chain_summary.csv'));
paper_risk_samples = calc_paper_chain_severity(chain_summary_table, cfg_paper, line_flow_detail_table, bus_voltage_detail_table, stage_probability_table);
paper_risk_samples = [chain_summary_table(:, {'initial_branch', 'trial_id'}), paper_risk_samples];
invalid_ratio = mean(~paper_risk_samples.paper_lfor_nvor_complete);
save_result_table(paper_risk_samples, fullfile(cfg.results_table_dir, 'markov_risk_samples_paper_severity.csv'), true);
if invalid_ratio > cfg_paper.paper_max_invalid_chain_ratio_for_var
    paper_var_table = diagnostic_paper_var_table(cfg_paper, invalid_ratio);
    paper_by_initial = diagnostic_paper_by_initial_table(chain_summary_table, invalid_ratio);
    save_result_table(paper_var_table, fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv'), true);
    save_result_table(paper_by_initial, fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_paper_severity.csv'), true);
    fprintf('paper_formula无效事故链比例 %.4f 超过阈值 %.4f，本场景paper VaR标记为diagnostic_only。\n', ...
        invalid_ratio, cfg_paper.paper_max_invalid_chain_ratio_for_var);
    return;
end
paper_var_table = calc_markov_var_metrics(paper_risk_samples, cfg_paper, 'paper');
paper_by_initial = calc_markov_var_by_initial_fault(paper_risk_samples, cfg_paper, 'paper');
paper_var_table.result_status = repmat("valid", height(paper_var_table), 1);
save_result_table(paper_var_table, fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv'), true);
save_result_table(paper_by_initial, fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_paper_severity.csv'), true);
end

function paper_var_table = diagnostic_paper_var_table(cfg, invalid_ratio)
sigma = cfg.var_confidence_levels(:);
SLLR = NaN(numel(sigma), 1);
SLFOR = NaN(numel(sigma), 1);
SNVOR = NaN(numel(sigma), 1);
CRI = NaN(numel(sigma), 1);
result_status = repmat("diagnostic_only", numel(sigma), 1);
note = repmat("paper_formula invalid chain ratio exceeds threshold: " + string(invalid_ratio), numel(sigma), 1);
paper_var_table = table(sigma, SLLR, SLFOR, SNVOR, CRI, result_status, note);
end

function by_initial = diagnostic_paper_by_initial_table(chain_summary_table, invalid_ratio)
initial_branch = unique(chain_summary_table.initial_branch);
SLLR = NaN(numel(initial_branch), 1);
SLFOR = NaN(numel(initial_branch), 1);
SNVOR = NaN(numel(initial_branch), 1);
CRI = NaN(numel(initial_branch), 1);
result_status = repmat("diagnostic_only", numel(initial_branch), 1);
note = repmat("paper_formula invalid chain ratio exceeds threshold: " + string(invalid_ratio), numel(initial_branch), 1);
by_initial = table(initial_branch, SLLR, SLFOR, SNVOR, CRI, result_status, note);
end

function run_uniform_weighted_compare_scenario(cfg)
uniform_tbl = readtable(fullfile(cfg.results_table_dir, 'markov_var_metrics.csv'));
weighted_tbl = readtable(fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv'));
comparison = join_var_tables(uniform_tbl, weighted_tbl, 'uniform', 'weighted');
save_result_table(comparison, fullfile(cfg.results_table_dir, 'var_uniform_vs_weighted_comparison.csv'), true);
plot_two_cri(comparison.sigma, comparison.uniform_CRI, comparison.weighted_CRI, ...
    'uniform与表4-1加权VaR的CRI对比', 'uniform', 'weighted', ...
    fullfile(cfg.results_figure_dir, 'var_uniform_vs_weighted_cri.png'));
end

function run_basic_paper_compare_scenario(cfg)
basic_tbl = readtable(fullfile(cfg.results_table_dir, 'markov_var_metrics.csv'));
paper_tbl = readtable(fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv'));
comparison = join_var_tables(basic_tbl, paper_tbl, 'basic', 'paper');
save_result_table(comparison, fullfile(cfg.results_table_dir, 'basic_vs_paper_severity_comparison.csv'), true);
plot_two_cri(comparison.sigma, comparison.basic_CRI, comparison.paper_CRI, ...
    'basic与paper formula的CRI对比', 'basic', 'paper formula', ...
    fullfile(cfg.results_figure_dir, 'basic_vs_paper_cri_comparison.png'));
end

function export_paper_detail_table(detail_table, sample_table, summary_table, cfg, base_name)
save_result_table(detail_table, fullfile(cfg.results_table_dir, [base_name, '.csv']), true);
save_result_table(sample_table, fullfile(cfg.results_table_dir, [base_name, '_sample.csv']), true);
save_result_table(summary_table, fullfile(cfg.results_table_dir, [base_name, '_summary.csv']), true);
manifest = save_table_chunks(detail_table, fullfile(cfg.results_table_dir, 'paper_detail_chunks'), base_name, cfg.paper_detail_chunk_size);
save_result_table(manifest, fullfile(cfg.results_table_dir, [base_name, '_manifest.csv']), true);
end

function tbl = join_var_tables(left, right, left_name, right_name)
sigma = left.sigma;
right = sortrows(right, 'sigma');
left = sortrows(left, 'sigma');
tbl = table(sigma, ...
    left.SLLR, right.SLLR, right.SLLR - left.SLLR, ...
    left.SLFOR, right.SLFOR, right.SLFOR - left.SLFOR, ...
    left.SNVOR, right.SNVOR, right.SNVOR - left.SNVOR, ...
    left.CRI, right.CRI, right.CRI - left.CRI, ...
    'VariableNames', {'sigma', ...
    [left_name '_SLLR'], [right_name '_SLLR'], 'delta_SLLR', ...
    [left_name '_SLFOR'], [right_name '_SLFOR'], 'delta_SLFOR', ...
    [left_name '_SNVOR'], [right_name '_SNVOR'], 'delta_SNVOR', ...
    [left_name '_CRI'], [right_name '_CRI'], 'delta_CRI'});
end

function plot_two_cri(sigma, cri_a, cri_b, title_text, label_a, label_b, out_file)
if ~exist(fileparts(out_file), 'dir')
    mkdir(fileparts(out_file));
end
fig = figure('Visible', 'off', 'Color', 'w');
plot(sigma, cri_a, '-o', 'LineWidth', 1.5);
hold on;
plot(sigma, cri_b, '-s', 'LineWidth', 1.5);
grid on;
xlabel('置信水平 \sigma');
ylabel('CRI');
title(title_text);
legend(label_a, label_b, 'Location', 'best');
saveas(fig, out_file);
close(fig);
end

function sample_table = build_candidate_sample(candidate_detail_table)
if isempty(candidate_detail_table) || height(candidate_detail_table) == 0
    sample_table = candidate_detail_table;
    return;
end
selected_rows = find(candidate_detail_table.trip_selected == 1);
unselected = candidate_detail_table(candidate_detail_table.trip_selected == 0, :);
[~, order] = sort(unselected.outage_probability, 'descend');
top_unselected = order(1:min(500, numel(order)));
sample_table = [candidate_detail_table(selected_rows, :); unselected(top_unselected, :)];
if isempty(sample_table)
    sample_table = candidate_detail_table(1:min(10, height(candidate_detail_table)), :);
end
end

function shed = empty_shed(existing_shed_mw)
shed = struct('island_load_shed_mw', existing_shed_mw, ...
    'corrective_load_shed_mw', 0, ...
    'load_shed_frac', 0, ...
    'load_shed_mw', existing_shed_mw, ...
    'total_load_shed_mw', existing_shed_mw, ...
    'iterations', 0, ...
    'converged_after_shed', true);
end

function scenario_result = build_scenario_result(scenario_id, scenario, cfg, basecase_converged, status, note)
summary_path = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
invalid_path = fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_summary.csv');
basic_path = fullfile(cfg.results_table_dir, 'markov_var_metrics.csv');
weighted_path = fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv');
paper_path = fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv');

chain_count = height(readtable(summary_path));
invalid_summary = readtable(invalid_path);
invalid_stage_ratio = get_scalar_or_nan(invalid_summary, 'invalid_stage_ratio');
basic_CRI_095 = get_cri_at_sigma(basic_path, 0.95);
weighted_CRI_095 = get_cri_at_sigma(weighted_path, 0.95);
paper_CRI_095 = get_cri_at_sigma(paper_path, 0.95);

scenario_result = struct('scenario_id', string(scenario_id), ...
    'total_wind_capacity_mw', scenario.total_wind_capacity_mw, ...
    'wind_buses', join_vector(scenario.wind_buses), ...
    'wind_speed_mps', scenario.wind_speed_mps, ...
    'renewable_dispatch_mode', string(scenario.renewable_dispatch_mode), ...
    'markov_trials_per_initial_fault', cfg.markov_num_trials_per_initial_fault, ...
    'basecase_converged', logical(basecase_converged), ...
    'chain_count', chain_count, ...
    'invalid_stage_ratio', invalid_stage_ratio, ...
    'basic_CRI_095', basic_CRI_095, ...
    'weighted_CRI_095', weighted_CRI_095, ...
    'paper_CRI_095', paper_CRI_095, ...
    'status', string(status), ...
    'note', string(note));
end

function scenario_result = build_failed_result(scenario_id, cfg, ME)
scenario_result = init_scenario_result(scenario_id, cfg);
scenario_result.status = "failed";
scenario_result.note = string(ME.message);
end

function value = get_cri_at_sigma(file_path, sigma_value)
if ~exist(file_path, 'file')
    value = NaN;
    return;
end
tbl = readtable(file_path);
idx = find(abs(tbl.sigma - sigma_value) < 1e-9, 1);
if isempty(idx)
    value = NaN;
else
    value = tbl.CRI(idx);
end
end

function value = get_scalar_or_nan(tbl, field_name)
if ismember(field_name, tbl.Properties.VariableNames) && height(tbl) >= 1
    value = tbl.(field_name)(1);
else
    value = NaN;
end
end

function s = join_vector(v)
if isempty(v)
    s = "";
else
    s = strjoin(string(v(:).'), ',');
end
end
