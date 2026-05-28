function main_check_original_paper_alignment_audit()
%MAIN_CHECK_ORIGINAL_PAPER_ALIGNMENT_AUDIT 检查原文对齐审计资料是否完整且状态合法。
% 输入：
%   无。仅读取审计文档和 original_paper_gap_audit.csv，不运行仿真。
% 输出：
%   results/final_summary/logs/original_paper_alignment_audit_check_log.txt
% 物理含义：
%   防止把缺失的 P_wt/P_ge、实际脱网和 diagnostic_only 场景误写成完整复现。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

docs_dir = fullfile(project_root, 'docs');
table_dir = fullfile(project_root, 'results', 'final_summary', 'tables');
log_dir = fullfile(project_root, 'results', 'final_summary', 'logs');
if ~exist(log_dir, 'dir')
    mkdir(log_dir);
end

required_docs = {
    fullfile(docs_dir, 'original_paper_alignment_audit.md')
    fullfile(docs_dir, 'required_original_paper_inputs.md')
    fullfile(docs_dir, 'next_reproduction_steps.md')
    };
for i = 1:numel(required_docs)
    if ~exist(required_docs{i}, 'file')
        error('缺少审计文档：%s', required_docs{i});
    end
end

audit_path = fullfile(table_dir, 'original_paper_gap_audit.csv');
if ~exist(audit_path, 'file')
    error('缺少审计表：%s', audit_path);
end
audit_table = readtable(audit_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
if height(audit_table) == 0
    error('original_paper_gap_audit.csv 为空。');
end
if height(audit_table) < 30
    error('original_paper_gap_audit.csv 行数不足30，当前为%d。', height(audit_table));
end

allowed_status = ["matched", "partially_matched", "simplified", "missing", "unknown_need_paper"];
status = string(audit_table.alignment_status);
if any(~ismember(status, allowed_status))
    bad = unique(status(~ismember(status, allowed_status)));
    error('alignment_status 存在非法值：%s', strjoin(bad, ', '));
end
if ~any(string(audit_table.priority) == "P0")
    error('审计表必须至少包含一个 P0 缺失项。');
end

require_status(audit_table, "P_wt", ["simplified", "missing"]);
require_status(audit_table, "P_ge", ["simplified", "missing"]);
require_status(audit_table, "新能源实际脱网状态转移", "missing");
if ~any(contains(string(audit_table.module), "新能源实际脱网"))
    error('审计表必须包含 renewable actual trip / 新能源实际脱网条目。');
end
if ~any(contains(string(audit_table.current_implementation), "diagnostic_only") | ...
        contains(string(audit_table.simplification_or_gap), "diagnostic_only"))
    error('审计表必须记录 centralized_wind_40pct diagnostic_only。');
end

log_file = fullfile(log_dir, 'original_paper_alignment_audit_check_log.txt');
fid = fopen(log_file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'Original paper alignment audit check passed.\n');
fprintf(fid, 'audit_rows=%d\n', height(audit_table));
fprintf(fid, 'P0_rows=%d\n', sum(string(audit_table.priority) == "P0"));
fprintf(fid, 'statuses=%s\n', strjoin(unique(status), ', '));
fprintf('Original paper alignment audit check passed: %s\n', log_file);
end

function require_status(audit_table, module_pattern, allowed)
idx = contains(string(audit_table.module), module_pattern);
if ~any(idx)
    error('审计表缺少模块：%s', module_pattern);
end
actual = string(audit_table.alignment_status(idx));
if any(~ismember(actual, allowed))
    error('模块 %s 的状态必须属于 [%s]，当前为 [%s]。', ...
        module_pattern, strjoin(allowed, ', '), strjoin(unique(actual), ', '));
end
end
