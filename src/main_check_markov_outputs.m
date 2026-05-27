function main_check_markov_outputs()
%MAIN_CHECK_MARKOV_OUTPUTS 自检Markov事故链、候选明细和VaR输出。
% 输入：
%   无。读取 results/tables 下已经生成的结果文件。
% 输出：
%   无。检查失败时抛出error；检查通过时打印中文自检报告。
% 物理含义：
%   在继续接入论文表4-1加权VaR或后续场景扫描前，确认已有uniform流程、
%   候选线路分块归档，以及可选weighted输出均处于可追溯状态。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);

summary_path = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
stage_path = fullfile(cfg.results_table_dir, 'markov_chain_stages.csv');
candidate_path = fullfile(cfg.results_table_dir, 'markov_candidate_details.csv');
candidate_sample_path = fullfile(cfg.results_table_dir, 'markov_candidate_details_sample.csv');
candidate_summary_path = fullfile(cfg.results_table_dir, 'markov_candidate_summary.csv');
candidate_manifest_path = fullfile(cfg.results_table_dir, 'markov_candidate_details_manifest.csv');
candidate_chunk_dir = fullfile(cfg.results_table_dir, 'candidate_chunks');
risk_sample_path = fullfile(cfg.results_table_dir, 'markov_risk_samples.csv');
var_path = fullfile(cfg.results_table_dir, 'markov_var_metrics.csv');
by_initial_path = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault.csv');

must_exist(summary_path);
must_exist(stage_path);
must_exist(candidate_path);
must_exist(candidate_sample_path);
must_exist(candidate_summary_path);
must_exist(candidate_manifest_path);
must_exist(risk_sample_path);
must_exist(var_path);
must_exist(by_initial_path);

summary_table = readtable(summary_path);
stage_table = readtable(stage_path);
candidate_sample_table = readtable(candidate_sample_path);
candidate_summary_table = readtable(candidate_summary_path);
candidate_manifest_table = readtable(candidate_manifest_path);
risk_samples = readtable(risk_sample_path);
var_table = readtable(var_path);
by_initial_table = readtable(by_initial_path);

expected_summary_rows = 46 * cfg.markov_num_trials_per_initial_fault;
if height(summary_table) ~= expected_summary_rows
    error('markov_chain_summary.csv行数应为%d，实际为%d。', ...
        expected_summary_rows, height(summary_table));
end
if isempty(stage_table)
    error('markov_chain_stages.csv为空。');
end
if isempty(candidate_sample_table)
    error('markov_candidate_details_sample.csv为空。');
end
if isempty(candidate_summary_table)
    error('markov_candidate_summary.csv为空。');
end
if isempty(candidate_manifest_table)
    error('markov_candidate_details_manifest.csv为空。');
end
if ~exist(candidate_chunk_dir, 'dir')
    error('candidate_chunks目录不存在：%s', candidate_chunk_dir);
end

required_candidate_columns = {'initial_branch', 'trial_id', 'stage_id', 'candidate_branch', ...
    'from_bus', 'to_bus', 'loading_pu', 'outage_probability', 'random_u', 'trip_selected'};

[full_candidate_ok, full_candidate_rows] = validate_full_candidate_csv( ...
    candidate_path, cfg, stage_table, required_candidate_columns);

[chunk_total_rows, chunk_selected_count, chunk_max_loading, chunk_max_probability] = ...
    validate_candidate_chunks_from_manifest(candidate_chunk_dir, candidate_manifest_table, ...
    candidate_summary_table, cfg, required_candidate_columns);

if height(risk_samples) ~= height(summary_table)
    error('markov_risk_samples.csv行数应与markov_chain_summary.csv一致。');
end
required_sigmas = cfg.var_confidence_levels(:);
for i = 1:numel(required_sigmas)
    if ~any(abs(var_table.sigma - required_sigmas(i)) < 1e-12)
        error('markov_var_metrics.csv缺少sigma=%.2f。', required_sigmas(i));
    end
end
if height(by_initial_table) ~= 46
    error('markov_var_by_initial_fault.csv应包含46条初始线路，实际为%d。', height(by_initial_table));
end

[paper_validated_status, weighted_status] = check_optional_weighted_outputs(cfg);

fprintf('Markov输出自检通过。\n');
fprintf('markov_chain_summary行数：%d\n', height(summary_table));
fprintf('markov_chain_stages行数：%d\n', height(stage_table));
if full_candidate_ok
    fprintf('full candidate CSV行数：%d\n', full_candidate_rows);
else
    fprintf('full candidate CSV读取异常，已使用chunks完成校验。\n');
end
fprintf('chunk文件数量：%d\n', height(candidate_manifest_table));
fprintf('chunk总行数：%d\n', chunk_total_rows);
fprintf('candidate_summary总行数：%d\n', candidate_summary_table.total_candidate_rows(1));
fprintf('candidate_details_sample行数：%d\n', height(candidate_sample_table));
fprintf('trip_selected=1数量：%d\n', chunk_selected_count);
fprintf('max loading_pu：%.6f\n', chunk_max_loading);
fprintf('max outage_probability：%.6f\n', chunk_max_probability);
fprintf('markov_risk_samples行数：%d\n', height(risk_samples));
fprintf('markov_var_metrics sigma列表：%s\n', mat2str(var_table.sigma'));
fprintf('markov_var_metrics行数：%d\n', height(var_table));
fprintf('markov_var_by_initial_fault行数：%d\n', height(by_initial_table));
fprintf('%s\n', paper_validated_status);
fprintf('%s\n', weighted_status);
end

function must_exist(path_text)
%MUST_EXIST 检查文件是否存在。
if ~exist(path_text, 'file')
    error('缺少输出文件：%s', path_text);
end
end

function [full_ok, row_count] = validate_full_candidate_csv(candidate_path, cfg, stage_table, required_columns)
%VALIDATE_FULL_CANDIDATE_CSV 校验完整候选线路CSV。
full_ok = true;
row_count = 0;
file_info = dir(candidate_path);
if isempty(file_info) || file_info.bytes < 100
    warning('markov_candidate_details.csv文件过小，将依赖chunks检查。');
    full_ok = false;
    return;
end

candidate_table = readtable(candidate_path);
row_count = height(candidate_table);
if isempty(candidate_table)
    warning('full markov_candidate_details.csv读回为空，将依赖chunks检查。');
    full_ok = false;
    return;
end

missing_columns = setdiff(required_columns, candidate_table.Properties.VariableNames);
if ~isempty(missing_columns)
    warning('full markov_candidate_details.csv缺少列：%s，将依赖chunks检查。', ...
        strjoin(missing_columns, ', '));
    full_ok = false;
    return;
end

validate_candidate_values(candidate_table, cfg, stage_table, 'full markov_candidate_details.csv');
end

function validate_candidate_values(candidate_table, cfg, stage_table, label)
%VALIDATE_CANDIDATE_VALUES 校验候选线路表字段和值域。
if height(candidate_table) <= height(stage_table)
    error('%s行数%d应大于事故链逐级状态行数%d。', ...
        label, height(candidate_table), height(stage_table));
end
if max(candidate_table.outage_probability) <= cfg.line_outage_p0
    error('%s最大停运概率未高于基础概率line_outage_p0。', label);
end
if ~any(candidate_table.trip_selected == 1)
    error('%s中不存在trip_selected=1的记录。', label);
end
if any(candidate_table.random_u < 0 | candidate_table.random_u > 1)
    error('%s中random_u存在[0,1]以外的值。', label);
end
if any(candidate_table.outage_probability < 0 | candidate_table.outage_probability > 1)
    error('%s中outage_probability存在[0,1]以外的值。', label);
end
if any(candidate_table.loading_pu < 0)
    error('%s中loading_pu存在负值。', label);
end
end

function [total_rows, selected_count, max_loading, max_probability] = validate_candidate_chunks_from_manifest( ...
    chunk_dir, manifest_table, summary_table, cfg, required_columns)
%VALIDATE_CANDIDATE_CHUNKS_FROM_MANIFEST 根据manifest逐块校验候选线路明细。
total_rows = 0;
selected_count = 0;
max_loading = -Inf;
max_probability = -Inf;

for i = 1:height(manifest_table)
    chunk_path = fullfile(chunk_dir, char(manifest_table.file_name(i)));
    if ~exist(chunk_path, 'file')
        error('manifest记录的chunk文件不存在：%s', chunk_path);
    end
    bytes = get_file_bytes(chunk_path);
    if bytes < 100
        error('chunk文件过小：%s (%d bytes)', chunk_path, bytes);
    end
    chunk = readtable(chunk_path);
    missing_columns = setdiff(required_columns, chunk.Properties.VariableNames);
    if ~isempty(missing_columns)
        error('chunk文件缺少列：%s，文件：%s', strjoin(missing_columns, ', '), chunk_path);
    end
    if height(chunk) ~= manifest_table.row_count(i)
        error('chunk行数与manifest不一致：%s', chunk_path);
    end
    validate_candidate_values(chunk, cfg, table(), sprintf('chunk %s', chunk_path));
    total_rows = total_rows + height(chunk);
    selected_count = selected_count + sum(chunk.trip_selected == 1);
    max_loading = max(max_loading, max(chunk.loading_pu));
    max_probability = max(max_probability, max(chunk.outage_probability));
end

if total_rows ~= summary_table.total_candidate_rows(1)
    error('chunk总行数%d与candidate_summary总行数%d不一致。', ...
        total_rows, summary_table.total_candidate_rows(1));
end
if selected_count <= 0
    error('所有chunk中都没有trip_selected=1记录。');
end
if max_probability <= cfg.line_outage_p0
    error('所有chunk中的最大停运概率未高于基础概率line_outage_p0。');
end
end

function [paper_status, weighted_status] = check_optional_weighted_outputs(cfg)
%CHECK_OPTIONAL_WEIGHTED_OUTPUTS 检查可选表4-1校验和weighted VaR输出。
% 输入：
%   cfg - 全局配置，包含结果目录和置信水平。
% 输出：
%   paper_status, weighted_status - 中文状态说明。
validated_path = fullfile(cfg.results_table_dir, 'paper_table_4_1_probability_validated.csv');
weighted_samples_path = fullfile(cfg.results_table_dir, 'markov_risk_samples_weighted.csv');
weighted_var_path = fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv');
weighted_by_initial_path = fullfile(cfg.results_table_dir, 'markov_var_by_initial_fault_weighted.csv');
comparison_path = fullfile(cfg.results_table_dir, 'var_uniform_vs_weighted_comparison.csv');

if exist(validated_path, 'file')
    validated = readtable(validated_path);
    if height(validated) ~= 46
        error('paper_table_4_1_probability_validated.csv应包含46行。');
    end
    paper_status = "表4-1校验文件存在：46行。";
else
    paper_status = "表4-1未填写或未通过校验，加权VaR尚未运行。";
end

if exist(weighted_samples_path, 'file') || exist(weighted_var_path, 'file') || exist(weighted_by_initial_path, 'file')
    must_exist(weighted_samples_path);
    must_exist(weighted_var_path);
    must_exist(weighted_by_initial_path);
    evalc('main_check_paper_table_4_1_consistency');
    weighted_samples = readtable(weighted_samples_path);
    weighted_var = readtable(weighted_var_path);
    weighted_by_initial = readtable(weighted_by_initial_path);
    if abs(sum(weighted_samples.sample_weight) - 1) > 1e-10
        error('markov_risk_samples_weighted.csv的sample_weight总和不为1。');
    end
    for i = 1:numel(cfg.var_confidence_levels)
        if ~any(abs(weighted_var.sigma - cfg.var_confidence_levels(i)) < 1e-12)
            error('markov_var_metrics_weighted.csv缺少sigma=%.2f。', cfg.var_confidence_levels(i));
        end
    end
    if height(weighted_by_initial) ~= 46
        error('markov_var_by_initial_fault_weighted.csv应包含46行。');
    end
    weighted_status = "表4-1源数据已填写；表4-1源数据与validated结果一致；weighted risk sample 权重一致；sample_weight总和=1。";
else
    weighted_status = "表4-1未填写，加权VaR尚未运行。";
end

if exist(comparison_path, 'file')
    comparison = readtable(comparison_path);
    if height(comparison) ~= numel(cfg.var_confidence_levels)
        error('var_uniform_vs_weighted_comparison.csv行数应等于置信水平数量。');
    end
end
end
