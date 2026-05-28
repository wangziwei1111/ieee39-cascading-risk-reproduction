function main_check_paper_benchmark_comparison()
%MAIN_CHECK_PAPER_BENCHMARK_COMPARISON 检查论文 benchmark 对照输出是否完整且语义安全。
% 该脚本不运行仿真，只检查对照表、诊断表和图是否存在，且不可比较场景没有被误标。

project_root = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(project_root, 'results', 'paper_alignment');
table_dir = fullfile(root, 'tables');
fig_dir = fullfile(root, 'figures');
log_dir = fullfile(root, 'logs');
if ~exist(log_dir, 'dir')
    mkdir(log_dir);
end

mapping_path = require_file(table_dir, 'paper_to_reproduction_scenario_mapping.csv');
paper_path = require_file(table_dir, 'paper_benchmark_standardized.csv');
repro_path = require_file(table_dir, 'reproduction_result_standardized.csv');
comparison_path = require_file(table_dir, 'paper_vs_reproduction_comparison.csv');
gap_path = require_file(table_dir, 'paper_alignment_gap_diagnosis.csv');
priority_path = require_file(table_dir, 'next_model_fix_priority.csv'); %#ok<NASGU>

mapping = readtable(mapping_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
paper = readtable(paper_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
repro = readtable(repro_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve'); %#ok<NASGU>
comparison = readtable(comparison_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
gap = readtable(gap_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');

if isempty(comparison) || height(comparison) == 0
    error('paper_vs_reproduction_comparison.csv 为空。');
end
if height(gap) < 10
    error('paper_alignment_gap_diagnosis.csv 至少应包含 G01-G10。');
end
for i = 1:10
    gid = "G" + compose('%02d', i);
    if ~any(string(gap.gap_id) == gid)
        error('缺少差异诊断项：%s', gid);
    end
end

table46 = comparison(string(comparison.paper_table) == "Table 4-6", :);
if isempty(table46) || ~all(string(table46.comparison_status) == "not_comparable_missing_reproduction")
    error('Table 4-6 必须存在且标记为 not_comparable_missing_reproduction。');
end

table42 = comparison(string(comparison.paper_table) == "Table 4-2", :);
if isempty(table42) || ~all(string(table42.comparison_status) == "not_comparable_model_missing")
    error('Table 4-2 必须存在且标记为 not_comparable_model_missing。');
end

diag = comparison(string(comparison.comparison_status) == "not_comparable_diagnostic_only", :);
if any(string(diag.comparison_status) == "comparable")
    error('diagnostic_only 结果不得标为 comparable。');
end

nan_rows = isnan(comparison.reproduction_value_raw);
if any(comparison.reproduction_value_raw(nan_rows) == 0)
    error('NaN reproduction 不得被填 0。');
end

if ~any(string(mapping.mapping_status) == "missing_reproduction")
    error('映射表必须保留 missing_reproduction 状态。');
end
if ~any(string(paper.paper_unit) == "10^-4")
    error('paper benchmark 标准化表必须保留 10^-4 单位。');
end

require_file(fig_dir, 'table45_penetration_cri_paper_vs_reproduction.png');
require_file(fig_dir, 'table44_topology_cri_paper_vs_reproduction.png');
require_file(fig_dir, 'paper_alignment_status_matrix.png');

log_file = fullfile(log_dir, 'paper_benchmark_comparison_check_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Paper benchmark comparison check passed.\n');
fprintf(fid, 'mapping_rows=%d\n', height(mapping));
fprintf(fid, 'paper_rows=%d\n', height(paper));
fprintf(fid, 'comparison_rows=%d\n', height(comparison));
fprintf(fid, 'gap_rows=%d\n', height(gap));
fprintf(fid, 'table46_rows=%d\n', height(table46));
fprintf(fid, 'table42_rows=%d\n', height(table42));
fprintf('Paper benchmark comparison check passed: %s\n', log_file);
end

function path = require_file(dir_path, file_name)
path = fullfile(dir_path, file_name);
if ~exist(path, 'file')
    error('缺少文件：%s', path);
end
end
