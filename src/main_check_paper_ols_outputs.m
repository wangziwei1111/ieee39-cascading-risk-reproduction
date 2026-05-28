function main_check_paper_ols_outputs()
%MAIN_CHECK_PAPER_OLS_OUTPUTS 检查 paper OLS 触发逻辑、源码和诊断结果。
% 输入：
%   无。
% 输出：
%   results/loadshedding/paper_ols_check_log.txt - OLS自检日志。
% 物理含义：
%   确认 OLS 仍是可选模式，默认触发条件保持 nonconverged_only，同时已经具备
%   nonconverged_or_violation 触发诊断能力。

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
must_exist(fullfile(project_root, 'src', 'loadshedding', 'should_trigger_load_shedding.m'));
must_exist(fullfile(project_root, 'src', 'loadshedding', 'flatten_ols_records.m'));
must_exist(fullfile(project_root, 'src', 'loadshedding', 'summarize_ols_records.m'));

cfg = base_config();
if string(cfg.load_shedding_mode) ~= "simple"
    error('cfg.load_shedding_mode 默认值必须保持 simple。');
end
if ~isfield(cfg, 'load_shedding_trigger_mode') || string(cfg.load_shedding_trigger_mode) ~= "nonconverged_only"
    error('cfg.load_shedding_trigger_mode 默认值必须保持 nonconverged_only。');
end
required_cfg_fields = ["paper_ols_enable", "paper_ols_solver", "paper_ols_shed_cost", ...
    "paper_ols_generation_cost", "paper_ols_q_shed_mode", "paper_ols_max_iterations", ...
    "paper_ols_fail_policy", "load_shedding_violation_check_enable", ...
    "load_shedding_trigger_line_overload", "load_shedding_trigger_voltage_violation", ...
    "load_shedding_line_overload_threshold_pu", "load_shedding_voltage_min_pu", ...
    "load_shedding_voltage_max_pu"];
for k = 1:numel(required_cfg_fields)
    if ~isfield(cfg, required_cfg_fields(k))
        error('base_config缺少OLS/触发配置字段：%s', required_cfg_fields(k));
    end
end

search_text = string(fileread(fullfile(project_root, 'src', 'cascade', 'search_cascade_markov_line.m')));
if ~contains(search_text, "apply_load_shedding_strategy")
    error('search_cascade_markov_line.m 未调用 apply_load_shedding_strategy。');
end
if ~contains(search_text, "should_trigger_load_shedding")
    error('search_cascade_markov_line.m 未调用 should_trigger_load_shedding。');
end
if contains(search_text, "[mpc_current, pf_result, shed] = simple_load_shedding")
    error('search_cascade_markov_line.m 仍保留直接simple_load_shedding主入口调用。');
end

comparison_path = fullfile(out_dir, 'ols_test_comparison.csv');
must_exist(comparison_path);
must_exist(fullfile(out_dir, 'ols_test_bus_shed_details.csv'));
comparison = readtable(comparison_path);
required_test_cols = ["pre_has_line_overload", "pre_has_voltage_violation", ...
    "trigger_nonconverged_only", "trigger_nonconverged_or_violation"];
assert_columns(comparison, required_test_cols, 'ols_test_comparison.csv');
if height(comparison) == 0
    error('ols_test_comparison.csv 为空。');
end
failed = contains(string(comparison.ols_status), "failed") | string(comparison.ols_status) == "fallback_to_simple";
if any(failed & strlength(string(comparison.note)) == 0)
    error('OLS失败或回退行必须包含note/message。');
end

trigger_dir = fullfile(out_dir, 'trigger_diagnostic_smoke');
trigger_cmp_path = fullfile(trigger_dir, 'trigger_mode_comparison.csv');
trigger_summary_path = fullfile(trigger_dir, 'ols_trigger_summary.csv');
must_exist(trigger_cmp_path);
must_exist(fullfile(trigger_dir, 'ols_stage_details_nonconverged_only.csv'));
must_exist(fullfile(trigger_dir, 'ols_stage_details_nonconverged_or_violation.csv'));
must_exist(trigger_summary_path);
must_exist(fullfile(trigger_dir, 'ols_trigger_diagnostic_log.txt'));
trigger_cmp = readtable(trigger_cmp_path);
trigger_summary = readtable(trigger_summary_path);
assert_columns(trigger_cmp, ["trigger_mode", "num_triggered_stages"], 'trigger_mode_comparison.csv');
assert_columns(trigger_summary, ["triggered_stage_count", "line_overload_trigger_count"], 'ols_trigger_summary.csv');
if height(trigger_cmp) < 2
    error('trigger_mode_comparison.csv 至少应包含两种触发模式。');
end

nonconv_rows = string(trigger_cmp.trigger_mode) == "nonconverged_only";
violation_rows = string(trigger_cmp.trigger_mode) == "nonconverged_or_violation";
if any(nonconv_rows) && any(violation_rows)
    n_nonconv = trigger_cmp.num_triggered_stages(find(nonconv_rows, 1));
    n_violation = trigger_cmp.num_triggered_stages(find(violation_rows, 1));
else
    n_nonconv = NaN;
    n_violation = NaN;
end

fprintf('OLS单元测试行数：%d\n', height(comparison));
fprintf('nonconverged_only触发阶段数：%g\n', n_nonconv);
fprintf('nonconverged_or_violation触发阶段数：%g\n', n_violation);
fprintf('默认load_shedding_mode：%s\n', cfg.load_shedding_mode);
fprintf('默认load_shedding_trigger_mode：%s\n', cfg.load_shedding_trigger_mode);
fprintf('paper OLS输出自检通过。\n');

write_plain_log(log_path, comparison, trigger_cmp, cfg, n_nonconv, n_violation);
end

function must_exist(path)
if ~exist(path, 'file')
    error('缺少必要文件：%s', path);
end
end

function assert_columns(tbl, columns, label)
for k = 1:numel(columns)
    if ~ismember(columns(k), string(tbl.Properties.VariableNames))
        error('%s 缺少字段：%s', label, columns(k));
    end
end
end

function write_plain_log(log_path, comparison, trigger_cmp, cfg, n_nonconv, n_violation)
fid = fopen(log_path, 'w');
if fid < 0
    warning('无法写入paper OLS自检日志：%s', log_path);
    return;
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'paper OLS触发逻辑自检日志\n');
fprintf(fid, '生成时间：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '默认load_shedding_mode=%s\n', cfg.load_shedding_mode);
fprintf(fid, '默认load_shedding_trigger_mode=%s\n', cfg.load_shedding_trigger_mode);
fprintf(fid, 'ols_test_comparison行数=%d\n', height(comparison));
fprintf(fid, 'trigger_mode_comparison行数=%d\n', height(trigger_cmp));
fprintf(fid, 'nonconverged_only触发阶段数=%g\n', n_nonconv);
fprintf(fid, 'nonconverged_or_violation触发阶段数=%g\n', n_violation);
if ~isnan(n_nonconv) && ~isnan(n_violation) && n_violation > n_nonconv
    fprintf(fid, '说明：nonconverged_or_violation触发次数大于nonconverged_only，这是启用越限触发后的预期现象。\n');
end
fprintf(fid, '配置字段检查：通过。\n');
fprintf(fid, 'search_cascade_markov_line触发入口检查：通过。\n');
fprintf(fid, '自检结论：通过。\n');
end
