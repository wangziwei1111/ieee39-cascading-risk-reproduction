function main_check_paper_ols_outputs()
%MAIN_CHECK_PAPER_OLS_OUTPUTS 检查 paper OLS 源码、配置和诊断结果。
% 输入：
%   无。
% 输出：
%   results/loadshedding/paper_ols_check_log.txt - OLS自检日志。
% 物理含义：
%   确认论文式最优负荷削减只作为可选模式接入，默认仍保持 simple，且
%   search_cascade_markov_line 通过统一策略入口调用切负荷。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'loadshedding');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
log_path = fullfile(out_dir, 'paper_ols_check_log.txt');

fprintf('paper OLS输出自检开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

must_exist(fullfile(project_root, 'src', 'loadshedding', 'solve_paper_ols_load_shedding.m'));
must_exist(fullfile(project_root, 'src', 'loadshedding', 'apply_load_shedding_strategy.m'));
must_exist(fullfile(project_root, 'src', 'loadshedding', 'flatten_ols_records.m'));
must_exist(fullfile(project_root, 'src', 'loadshedding', 'summarize_ols_records.m'));

cfg = base_config();
if ~isfield(cfg, 'load_shedding_mode') || string(cfg.load_shedding_mode) ~= "simple"
    error('cfg.load_shedding_mode 默认值必须保持 simple。');
end

required_cfg_fields = ["paper_ols_enable", "paper_ols_solver", "paper_ols_shed_cost", ...
    "paper_ols_generation_cost", "paper_ols_q_shed_mode", "paper_ols_max_iterations", ...
    "paper_ols_fail_policy"];
for k = 1:numel(required_cfg_fields)
    if ~isfield(cfg, required_cfg_fields(k))
        error('base_config缺少OLS配置字段：%s', required_cfg_fields(k));
    end
end

search_file = fullfile(project_root, 'src', 'cascade', 'search_cascade_markov_line.m');
search_text = string(fileread(search_file));
if ~contains(search_text, "apply_load_shedding_strategy")
    error('search_cascade_markov_line.m 未调用 apply_load_shedding_strategy。');
end
if contains(search_text, "[mpc_current, pf_result, shed] = simple_load_shedding")
    error('search_cascade_markov_line.m 仍保留直接simple_load_shedding主入口调用。');
end

comparison_path = fullfile(out_dir, 'ols_test_comparison.csv');
bus_detail_path = fullfile(out_dir, 'ols_test_bus_shed_details.csv');
must_exist(comparison_path);
must_exist(bus_detail_path);
comparison = readtable(comparison_path);
if height(comparison) == 0
    error('ols_test_comparison.csv 为空。');
end
if ~ismember('ols_status', comparison.Properties.VariableNames) || ~ismember('note', comparison.Properties.VariableNames)
    error('ols_test_comparison.csv 缺少 ols_status 或 note 字段。');
end
failed = contains(string(comparison.ols_status), "failed") | string(comparison.ols_status) == "fallback_to_simple";
if any(failed & strlength(string(comparison.note)) == 0)
    error('OLS失败或回退行必须包含note/message。');
end

smoke_dir = fullfile(out_dir, 'diagnostic_smoke');
summary_path = fullfile(smoke_dir, 'ols_summary.csv');
must_exist(fullfile(smoke_dir, 'markov_chain_summary.csv'));
must_exist(fullfile(smoke_dir, 'ols_stage_details.csv'));
must_exist(summary_path);
ols_summary = readtable(summary_path);
if height(ols_summary) == 0
    error('diagnostic_smoke/ols_summary.csv 为空。');
end

fprintf('OLS单元测试行数：%d\n', height(comparison));
disp(ols_summary);
fprintf('默认load_shedding_mode：%s\n', cfg.load_shedding_mode);
fprintf('paper OLS输出自检通过。\n');

write_plain_log(log_path, comparison, cfg, summary_path);
end

function must_exist(path)
if ~exist(path, 'file')
    error('缺少必要文件：%s', path);
end
end

function write_plain_log(log_path, comparison, cfg, summary_path)
fid = fopen(log_path, 'w');
if fid < 0
    warning('无法写入paper OLS自检日志：%s', log_path);
    return;
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'paper OLS输出自检日志\n');
fprintf(fid, '生成时间：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '默认load_shedding_mode=%s\n', cfg.load_shedding_mode);
fprintf(fid, 'ols_test_comparison行数=%d\n', height(comparison));
s = readtable(summary_path);
fprintf(fid, 'diagnostic_smoke ols_summary行数=%d\n', height(s));
if height(s) > 0
    fprintf(fid, 'total_ols_attempts=%d, successful=%d, failed=%d, fallback=%d\n', ...
        s.total_ols_attempts(1), s.successful_ols_count(1), ...
        s.failed_ols_count(1), s.num_fallback_to_simple(1));
end
fprintf(fid, '配置字段检查：通过。\n');
fprintf(fid, 'search_cascade_markov_line策略入口检查：通过。\n');
fprintf(fid, '自检结论：通过。\n');
end
