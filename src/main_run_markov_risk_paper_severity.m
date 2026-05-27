function main_run_markov_risk_paper_severity()
%MAIN_RUN_MARKOV_RISK_PAPER_SEVERITY 计算line-only论文公式版严重度与VaR。
% 输入：
%   无。读取markov_chain_records.mat、markov_chain_summary.csv和表4-1初始停运概率源文件。
% 输出：
%   paper_formula三类明细表、sample、summary、manifest、chunks，以及paper VaR结果。
% 物理含义：
%   本入口不改变Markov事故链抽样结果，只回放已记录的停运线路集合，补充论文LLR/LFOR/NVOR
%   公式所需的逐级状态变量，并计算line-only paper_formula风险样本。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
cfg.results_chain_dir = fullfile(project_root, cfg.results_chain_dir);
cfg.results_figure_dir = fullfile(project_root, cfg.results_figure_dir);
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', ...
    'line_initial_outage_probability_paper_table_4_1.csv');
cfg.severity_mode = 'paper_formula';
cfg.enable_paper_severity = true;
cfg.paper_severity_formula_confirmed = true;
cfg.var_use_chain_weights = false;

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end

log_path = fullfile(cfg.results_log_dir, 'markov_risk_paper_severity_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('paper_formula严重度计算开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('严重度模式：%s；概率模式：%s\n', cfg.severity_mode, cfg.paper_probability_mode);
fprintf('说明：当前为line-only版本，P_wt(E_k)=1，P_ge(E_k)=1。\n');

summary_csv = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
chain_mat = fullfile(cfg.results_chain_dir, 'markov_chain_records.mat');
if ~exist(summary_csv, 'file')
    error('找不到markov_chain_summary.csv，请先运行main_run_markov_line。');
end
if ~exist(chain_mat, 'file')
    error('找不到markov_chain_records.mat，请先运行main_run_markov_line。');
end

require_matpower(cfg);
base_mpc = build_case39_base(cfg);
scenario = scenario_config();
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
initial_probability_table = load_initial_line_probabilities(cfg, base_mpc);

chain_summary_table = readtable(summary_csv);
loaded = load(chain_mat, 'chain_records');
if ~isfield(loaded, 'chain_records')
    error('markov_chain_records.mat中缺少chain_records变量。');
end

[line_flow_detail_table, bus_voltage_detail_table, stage_probability_table, ...
    invalid_stage_detail_table, invalid_stage_summary_table] = ...
    build_markov_paper_detail_tables(loaded.chain_records, base_mpc, cfg, scenario, ...
    renewable_info, initial_probability_table);

[line_flow_summary_table, bus_voltage_summary_table, stage_probability_summary_table] = ...
    summarize_paper_detail_tables(line_flow_detail_table, bus_voltage_detail_table, ...
    stage_probability_table, invalid_stage_detail_table);
[line_flow_sample_table, bus_voltage_sample_table] = ...
    build_paper_detail_samples(line_flow_detail_table, bus_voltage_detail_table);

paper_chunk_dir = fullfile(cfg.results_table_dir, 'paper_detail_chunks');
[line_manifest_table, line_full_rows, line_full_bytes] = export_paper_detail_table( ...
    line_flow_detail_table, line_flow_sample_table, line_flow_summary_table, ...
    'markov_line_flow_details', cfg, paper_chunk_dir);
[bus_manifest_table, bus_full_rows, bus_full_bytes] = export_paper_detail_table( ...
    bus_voltage_detail_table, bus_voltage_sample_table, bus_voltage_summary_table, ...
    'markov_bus_voltage_details', cfg, paper_chunk_dir);

stage_probability_csv = fullfile(cfg.results_table_dir, 'markov_stage_probability_details.csv');
stage_probability_summary_csv = fullfile(cfg.results_table_dir, 'markov_stage_probability_summary.csv');
invalid_stage_csv = fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_details.csv');
invalid_stage_summary_csv = fullfile(cfg.results_table_dir, 'markov_paper_invalid_stage_summary.csv');
save_result_table(stage_probability_table, stage_probability_csv, true);
save_result_table(stage_probability_summary_table, stage_probability_summary_csv, true);
save_result_table(invalid_stage_detail_table, invalid_stage_csv, true);
save_result_table(invalid_stage_summary_table, invalid_stage_summary_csv, true);

paper_severity = calc_paper_chain_severity(chain_summary_table, cfg, ...
    line_flow_detail_table, bus_voltage_detail_table, stage_probability_table);

initial_branch = chain_summary_table.initial_branch;
trial_id = chain_summary_table.trial_id;
initial_branch_weight = map_initial_branch_weight(initial_branch, initial_probability_table);
num_trials_for_initial_branch = count_trials_per_initial_branch(initial_branch);
sample_weight = ones(height(chain_summary_table), 1) / height(chain_summary_table);
sample_weight_source = repmat("paper_formula_internal_stage_probability", height(chain_summary_table), 1);

risk_samples_paper = table(initial_branch, trial_id, initial_branch_weight, ...
    num_trials_for_initial_branch, sample_weight, sample_weight_source);
risk_samples_paper = [risk_samples_paper, paper_severity];

markov_var_table = calc_markov_var_metrics(risk_samples_paper, cfg, 'paper');
initial_fault_var_table = calc_markov_var_by_initial_fault(risk_samples_paper, cfg, 'paper');
invalid_chain_ratio = mean(~risk_samples_paper.paper_lfor_nvor_complete);
var_output_valid = invalid_chain_ratio <= cfg.paper_max_invalid_chain_ratio_for_var && ...
    ~any(isinf(risk_samples_paper.paper_CRI)) && ...
    mean(isnan(risk_samples_paper.paper_LFOR) | isnan(risk_samples_paper.paper_NVOR)) <= cfg.paper_max_invalid_chain_ratio_for_var;
if var_output_valid
    markov_var_table.result_status = repmat("valid", height(markov_var_table), 1);
    initial_fault_var_table.result_status = repmat("valid", height(initial_fault_var_table), 1);
else
    markov_var_table.result_status = repmat("diagnostic_only", height(markov_var_table), 1);
    initial_fault_var_table.result_status = repmat("diagnostic_only", height(initial_fault_var_table), 1);
    deprecate_existing_paper_var_files(cfg);
    warning('paper_formula存在过多无效阶段，当前结果仅可用于诊断，不能作为论文对照。');
end

risk_samples_csv = fullfile(cfg.results_table_dir, 'markov_risk_samples_paper_severity.csv');
var_metrics_csv = fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv');
by_initial_csv = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_paper_severity.csv');
save_result_table(risk_samples_paper, risk_samples_csv, true);
save_result_table(markov_var_table, var_metrics_csv, true);
save_result_table(initial_fault_var_table, by_initial_csv, true);

severity_type = ["basic"; "paper_formula"];
status = ["available"; "available"];
note = ["当前basic流程验证严重度仍保留"; ...
    "论文公式严重度已按用户提供公式实现；当前为line-only近似"];
severity_status_table = table(severity_type, status, note);
save_result_table(severity_status_table, fullfile(cfg.results_table_dir, 'severity_formula_status.csv'), true);

fprintf('line full CSV bytes：%d\n', line_full_bytes);
fprintf('line full CSV readback rows：%d\n', line_full_rows);
fprintf('line chunk文件数量：%d\n', height(line_manifest_table));
fprintf('line chunk总行数：%d\n', sum(line_manifest_table.row_count));
fprintf('bus full CSV bytes：%d\n', bus_full_bytes);
fprintf('bus full CSV readback rows：%d\n', bus_full_rows);
fprintf('bus chunk文件数量：%d\n', height(bus_manifest_table));
fprintf('bus chunk总行数：%d\n', sum(bus_manifest_table.row_count));
fprintf('stage_probability行数：%d\n', height(stage_probability_table));
fprintf('total_stage_count：%d\n', invalid_stage_summary_table.total_stage_count(1));
fprintf('valid_stage_count：%d\n', invalid_stage_summary_table.valid_stage_count(1));
fprintf('invalid_stage_count：%d\n', invalid_stage_summary_table.invalid_stage_count(1));
fprintf('invalid_stage_ratio：%.6f\n', invalid_stage_summary_table.invalid_stage_ratio(1));
fprintf('nonconverged_stage_count：%d\n', invalid_stage_summary_table.nonconverged_stage_count(1));
fprintf('max valid P_li_pu：%.6f\n', line_flow_summary_table.max_P_li_pu(1));
fprintf('min valid voltage_pu：%.6f\n', bus_voltage_summary_table.min_voltage_pu(1));
fprintf('max valid voltage_pu：%.6f\n', bus_voltage_summary_table.max_voltage_pu(1));
fprintf('是否生成paper VaR：%d\n', double(var_output_valid));
if ~var_output_valid
    fprintf('未生成有效paper VaR原因：paper_formula存在过多无效阶段，当前结果仅可用于诊断。\n');
end
fprintf('paper risk sample行数：%d\n', height(risk_samples_paper));
fprintf('paper VaR表：\n');
disp(markov_var_table);
fprintf('paper_formula严重度计算结束：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
end

function [manifest_table, readback_rows, file_bytes] = export_paper_detail_table( ...
    detail_table, sample_table, summary_table, base_name, cfg, chunk_dir)
%EXPORT_PAPER_DETAIL_TABLE 保存paper明细full/sample/summary/manifest/chunks。
full_csv = fullfile(cfg.results_table_dir, [base_name, '.csv']);
sample_csv = fullfile(cfg.results_table_dir, [base_name, '_sample.csv']);
summary_csv = fullfile(cfg.results_table_dir, [base_name, '_summary.csv']);
manifest_csv = fullfile(cfg.results_table_dir, [base_name, '_manifest.csv']);

if cfg.export_paper_detail_full_csv
    save_result_table(detail_table, full_csv, true);
end
save_result_table(sample_table, sample_csv, true);
save_result_table(summary_table, summary_csv, true);

file_bytes = get_file_bytes(full_csv);
readback = readtable(full_csv);
readback_rows = height(readback);
if height(detail_table) > 0 && readback_rows == 0
    warning('%s full CSV读回为空，将依赖chunks复核。', base_name);
end
if height(detail_table) > 0 && readback_rows ~= height(detail_table)
    error('%s full CSV读回行数%d与原表%d不一致。', base_name, readback_rows, height(detail_table));
end

if cfg.export_paper_detail_chunks
    manifest_table = save_table_chunks(detail_table, chunk_dir, base_name, cfg.paper_detail_chunk_size);
    if sum(manifest_table.row_count) ~= height(detail_table)
        error('%s chunks总行数与原表不一致。', base_name);
    end
    save_result_table(manifest_table, manifest_csv, true);
else
    manifest_table = table();
end
end

function deprecate_existing_paper_var_files(cfg)
%DEPRECATE_EXISTING_PAPER_VAR_FILES 标记旧paper VaR为不可用于论文对照。
src = fullfile(cfg.results_table_dir, 'markov_var_metrics_paper_severity.csv');
dst = fullfile(cfg.results_table_dir, 'deprecated_markov_var_metrics_paper_severity_invalid.csv');
if exist(src, 'file')
    copyfile(src, dst);
end
end

function initial_branch_weight = map_initial_branch_weight(initial_branch, initial_probability_table)
%MAP_INITIAL_BRANCH_WEIGHT 将表4-1归一化权重映射到事故链样本。
initial_branch_weight = zeros(numel(initial_branch), 1);
for i = 1:numel(initial_branch)
    row = initial_probability_table(initial_probability_table.branch_index == initial_branch(i), :);
    if isempty(row)
        error('表4-1概率表中找不到初始线路%d。', initial_branch(i));
    end
    initial_branch_weight(i) = row.normalized_weight(1);
end
end

function counts = count_trials_per_initial_branch(initial_branch)
%COUNT_TRIALS_PER_INITIAL_BRANCH 统计每条初始线路对应的Monte Carlo样本数。
counts = zeros(numel(initial_branch), 1);
branches = unique(initial_branch);
for i = 1:numel(branches)
    mask = initial_branch == branches(i);
    counts(mask) = sum(mask);
end
end
