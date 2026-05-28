function main_check_paper_ols_outputs()
%MAIN_CHECK_PAPER_OLS_OUTPUTS 检查paper OLS接口和诊断输出。
% 输入：
%   无。
% 输出：
%   results/loadshedding/paper_ols_check_log.txt - 自检日志。
% 物理含义：
%   确认OLS源码、单元测试、diagnostic smoke和默认simple模式均处于可复核状态。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'loadshedding');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
log_path = fullfile(out_dir, 'paper_ols_check_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('paper OLS输出自检开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

must_exist(fullfile(project_root, 'src', 'loadshedding', 'solve_paper_ols_load_shedding.m'));
must_exist(fullfile(project_root, 'src', 'loadshedding', 'apply_load_shedding_strategy.m'));

cfg = base_config();
if ~isfield(cfg, 'load_shedding_mode') || string(cfg.load_shedding_mode) ~= "simple"
    error('cfg.load_shedding_mode 默认值必须保持 simple。');
end

comparison_path = fullfile(out_dir, 'ols_test_comparison.csv');
must_exist(comparison_path);
comparison = readtable(comparison_path);
if height(comparison) == 0
    error('ols_test_comparison.csv 为空。');
end
if ismember('ols_status', comparison.Properties.VariableNames) && ismember('note', comparison.Properties.VariableNames)
    failed = contains(string(comparison.ols_status), "failed") | string(comparison.ols_status) == "fallback_to_simple";
    if any(failed & strlength(string(comparison.note)) == 0)
        error('OLS失败或回退行必须包含note/message。');
    end
else
    error('ols_test_comparison.csv 缺少 ols_status 或 note 字段。');
end

smoke_dir = fullfile(out_dir, 'diagnostic_smoke');
summary_path = fullfile(smoke_dir, 'ols_summary.csv');
if exist(smoke_dir, 'dir')
    must_exist(fullfile(smoke_dir, 'markov_chain_summary.csv'));
    must_exist(fullfile(smoke_dir, 'ols_stage_details.csv'));
    must_exist(summary_path);
    ols_summary = readtable(summary_path);
    if height(ols_summary) == 0
        error('diagnostic_smoke/ols_summary.csv 为空。');
    end
end

fprintf('OLS单元测试行数：%d\n', height(comparison));
if exist(summary_path, 'file')
    disp(readtable(summary_path));
end
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
if exist(summary_path, 'file')
    s = readtable(summary_path);
    fprintf(fid, 'diagnostic_smoke ols_summary行数=%d\n', height(s));
    if height(s) > 0
        fprintf(fid, 'total_ols_attempts=%d, successful=%d, failed=%d, fallback=%d\n', ...
            s.total_ols_attempts(1), s.successful_ols_count(1), ...
            s.failed_ols_count(1), s.num_fallback_to_simple(1));
    end
end
fprintf(fid, '自检结论：通过。\n');
end
