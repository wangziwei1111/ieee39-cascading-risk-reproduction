function main_check_paper_table_4_1_consistency()
%MAIN_CHECK_PAPER_TABLE_4_1_CONSISTENCY 校验表4-1源数据、验证结果和weighted样本权重一致性。
% 输入：
%   无。读取 data/ 和 results/tables/ 下的表4-1概率、验证结果和加权风险样本。
% 输出：
%   results/logs/paper_table_4_1_consistency_log.txt
% 物理含义：
%   保证weighted VaR可以从 data 源文件重新计算得到，而不是只依赖results下
%   已生成的中间结果。任何不一致均直接报错，避免不可复现实验结果进入后续分析。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);

data_path = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
validated_path = fullfile(cfg.results_table_dir, 'paper_table_4_1_probability_validated.csv');
weighted_samples_path = fullfile(cfg.results_table_dir, 'markov_risk_samples_weighted.csv');
log_path = fullfile(cfg.results_log_dir, 'paper_table_4_1_consistency_log.txt');

log_lines = strings(0, 1);
try
    log_lines(end + 1) = "表4-1源数据一致性校验开始：" + string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    log_lines(end + 1) = "data源文件：" + string(data_path);
    log_lines(end + 1) = "validated文件：" + string(validated_path);
    log_lines(end + 1) = "weighted样本文件：" + string(weighted_samples_path);

    must_exist(data_path);
    must_exist(validated_path);
    must_exist(weighted_samples_path);

    source_table = readtable(data_path);
    validated_table = readtable(validated_path);
    weighted_samples = readtable(weighted_samples_path);

    check_probability_tables(source_table, validated_table);
    check_weighted_samples(weighted_samples, validated_table);

    log_lines(end + 1) = "表4-1源数据已填写：46行，且不存在NaN。";
    log_lines(end + 1) = "表4-1源数据与validated结果一致。";
    log_lines(end + 1) = "weighted risk sample权重一致。";
    log_lines(end + 1) = "sample_weight总和=" + string(sprintf('%.16f', sum(weighted_samples.sample_weight)));
    log_lines(end + 1) = "表4-1源数据一致性校验结束：" + string(datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
catch ME
    log_lines(end + 1) = "一致性校验失败：" + string(ME.message);
    write_log(log_path, log_lines);
    fprintf('%s\n', log_lines);
    rethrow(ME);
end
end

function check_probability_tables(source_table, validated_table)
%CHECK_PROBABILITY_TABLES 校验data源表与validated表的概率字段一致。
% 输入：
%   source_table - data目录下的表4-1源数据。
%   validated_table - results目录下由校验脚本生成的概率表。
% 输出：
%   无。任何不一致直接报错。
if height(source_table) ~= 46 || height(validated_table) ~= 46
    error('data源表和validated表都必须为46行。');
end

required_source = {'branch_index', 'from_bus', 'to_bus', ...
    'paper_prob_times_1e_minus_4', 'initial_outage_probability', 'source_note'};
required_validated = {'branch_index', 'from_bus', 'to_bus', ...
    'paper_prob_times_1e_minus_4', 'initial_outage_probability', 'normalized_weight'};
assert_columns(source_table, required_source, 'data源表');
assert_columns(validated_table, required_validated, 'validated表');

source_table = sortrows(source_table, 'branch_index');
validated_table = sortrows(validated_table, 'branch_index');

if any(source_table.branch_index ~= validated_table.branch_index) || ...
        any(source_table.from_bus ~= validated_table.from_bus) || ...
        any(source_table.to_bus ~= validated_table.to_bus)
    error('data源表与validated表的branch_index/from_bus/to_bus不一致。');
end

if any(isnan(source_table.paper_prob_times_1e_minus_4)) || ...
        any(isnan(source_table.initial_outage_probability))
    error('data源文件中存在NaN，weighted VaR不可复现。');
end

tol = 1e-12;
if any(abs(source_table.paper_prob_times_1e_minus_4 - validated_table.paper_prob_times_1e_minus_4) > tol)
    error('data源表与validated表的paper_prob_times_1e_minus_4不一致。');
end
if any(abs(source_table.initial_outage_probability - validated_table.initial_outage_probability) > tol)
    error('data源表与validated表的initial_outage_probability不一致。');
end
if any(abs(source_table.initial_outage_probability - source_table.paper_prob_times_1e_minus_4 * 1e-4) > tol)
    error('data源表不满足 initial_outage_probability = paper_prob_times_1e_minus_4 * 1e-4。');
end

expected_weight = source_table.initial_outage_probability / sum(source_table.initial_outage_probability);
if any(abs(validated_table.normalized_weight - expected_weight) > tol)
    error('validated表的normalized_weight与data源概率归一化结果不一致。');
end
end

function check_weighted_samples(weighted_samples, validated_table)
%CHECK_WEIGHTED_SAMPLES 校验weighted风险样本权重与表4-1归一化权重一致。
% 输入：
%   weighted_samples - markov_risk_samples_weighted.csv读入表。
%   validated_table - 表4-1校验结果表。
% 输出：
%   无。任何不一致直接报错。
required = {'initial_branch', 'initial_branch_weight', 'sample_weight'};
assert_columns(weighted_samples, required, 'weighted风险样本表');

tol = 1e-10;
for i = 1:height(validated_table)
    branch = validated_table.branch_index(i);
    mask = weighted_samples.initial_branch == branch;
    if ~any(mask)
        error('weighted风险样本中缺少初始线路%d。', branch);
    end
    expected_weight = validated_table.normalized_weight(i);
    if any(abs(weighted_samples.initial_branch_weight(mask) - expected_weight) > tol)
        error('初始线路%d的initial_branch_weight与validated normalized_weight不一致。', branch);
    end
end

if abs(sum(weighted_samples.sample_weight) - 1) > tol
    error('weighted风险样本sample_weight总和不为1。');
end
end

function assert_columns(tbl, required_columns, label)
%ASSERT_COLUMNS 检查表格是否包含必需列。
missing = setdiff(required_columns, tbl.Properties.VariableNames);
if ~isempty(missing)
    error('%s缺少字段：%s', label, strjoin(missing, ', '));
end
end

function must_exist(path_text)
%MUST_EXIST 检查文件是否存在。
if ~exist(path_text, 'file')
    error('缺少文件：%s', path_text);
end
end

function write_log(log_path, log_lines)
%WRITE_LOG 写出一致性校验日志。
out_dir = fileparts(log_path);
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
fid = fopen(log_path, 'w', 'n', 'UTF-8');
if fid < 0
    error('无法写入日志文件：%s', log_path);
end
cleanup_obj = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(log_lines)
    fprintf(fid, '%s\n', log_lines(i));
end
end
