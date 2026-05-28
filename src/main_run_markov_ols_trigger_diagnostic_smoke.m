function main_run_markov_ols_trigger_diagnostic_smoke()
%MAIN_RUN_MARKOV_OLS_TRIGGER_DIAGNOSTIC_SMOKE 小规模比较OLS触发模式。
% 输入：
%   无。固定使用 distributed_wind_3000mw_base、前5条初始线路和每线3次样本。
% 输出：
%   results/loadshedding/trigger_diagnostic_smoke/ 下的触发模式对比表和日志。
% 物理含义：
%   对比 nonconverged_only 与 nonconverged_or_violation，检查越限触发是否增加
%   OLS/切负荷诊断阶段。本脚本不写入 final_summary，不运行全量场景。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'loadshedding', 'trigger_diagnostic_smoke');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
log_path = fullfile(out_dir, 'ols_trigger_diagnostic_log.txt');

cfg0 = base_config();
require_matpower(cfg0);

modes = ["nonconverged_only", "nonconverged_or_violation"];
comparison_rows = {};
summary_rows = {};

for k = 1:numel(modes)
    mode = modes(k);
    fprintf('OLS触发诊断：%s\n', mode);
    [chain_summary, ols_details, ols_summary] = run_one_mode(cfg0, mode);
    detail_file = fullfile(out_dir, sprintf('ols_stage_details_%s.csv', mode));
    save_result_table(ols_details, detail_file, true);

    total_load_shed_sum = sum(chain_summary.total_load_shed_mw, 'omitnan');
    mean_basic_cri = mean(chain_summary.basic_CRI, 'omitnan');
    mean_depth = mean(chain_summary.chain_depth, 'omitnan');
    comparison_rows{end + 1, 1} = table( ... %#ok<AGROW>
        mode, height(chain_summary), ols_summary.triggered_stage_count(1), ...
        ols_summary.nonconverged_trigger_count(1), ...
        ols_summary.line_overload_trigger_count(1), ...
        ols_summary.voltage_violation_trigger_count(1), ...
        total_load_shed_sum, mean_basic_cri, mean_depth, ...
        "前5条初始线路、每线3次trial，仅用于触发诊断。", ...
        'VariableNames', {'trigger_mode', 'chain_count', 'num_triggered_stages', ...
        'num_nonconverged_triggers', 'num_line_overload_triggers', ...
        'num_voltage_violation_triggers', 'total_load_shed_mw_sum', ...
        'mean_basic_CRI', 'mean_chain_depth', 'note'});
    ols_summary.trigger_mode = mode;
    ols_summary = movevars(ols_summary, 'trigger_mode', 'Before', 1);
    summary_rows{end + 1, 1} = ols_summary; %#ok<AGROW>
end

trigger_mode_comparison = vertcat(comparison_rows{:});
ols_trigger_summary = vertcat(summary_rows{:});
save_result_table(trigger_mode_comparison, fullfile(out_dir, 'trigger_mode_comparison.csv'), true);
save_result_table(ols_trigger_summary, fullfile(out_dir, 'ols_trigger_summary.csv'), true);
write_log(log_path, trigger_mode_comparison, ols_trigger_summary);
end

function [chain_summary_table, ols_stage_details, ols_summary] = run_one_mode(cfg0, trigger_mode)
cfg = cfg0;
cfg.load_shedding_mode = 'both_diagnostic';
cfg.paper_ols_enable = true;
cfg.load_shedding_trigger_mode = char(trigger_mode);
cfg.markov_num_trials_per_initial_fault = 3;
cfg.markov_random_seed = cfg.seed;
init_random_seed(cfg.markov_random_seed);

base_mpc = build_case39_base(cfg);
scenario = get_scenario_by_id('distributed_wind_3000mw_base', cfg, sum(base_mpc.bus(:, 3)));
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
faults = enumerate_initial_faults(mpc);
faults = faults(1:min(5, height(faults)), :);

chain_cells = cell(height(faults) * cfg.markov_num_trials_per_initial_fault, 1);
row = 0;
for f = 1:height(faults)
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        row = row + 1;
        chain_cells{row} = search_cascade_markov_line( ...
            mpc, faults.branch_index(f), cfg, scenario, renewable_info, trial_id);
    end
end
chain_records = vertcat(chain_cells{:});
[chain_summary_table, ~] = flatten_chain_records(chain_records, cfg);
ols_stage_details = flatten_ols_records(chain_records);
ols_summary = summarize_ols_records(ols_stage_details);
end

function write_log(log_path, comparison, summary)
fid = fopen(log_path, 'w');
if fid < 0
    warning('无法写入OLS触发诊断日志：%s', log_path);
    return;
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'OLS触发诊断smoke日志\n');
fprintf(fid, '生成时间：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
for i = 1:height(comparison)
    fprintf(fid, '%s: chains=%d, triggered=%d, nonconverged=%d, line=%d, voltage=%d, total_shed=%.6f\n', ...
        char(string(comparison.trigger_mode(i))), comparison.chain_count(i), ...
        comparison.num_triggered_stages(i), comparison.num_nonconverged_triggers(i), ...
        comparison.num_line_overload_triggers(i), comparison.num_voltage_violation_triggers(i), ...
        comparison.total_load_shed_mw_sum(i));
end
if height(comparison) == 2 && comparison.num_triggered_stages(2) > comparison.num_triggered_stages(1)
    fprintf(fid, '说明：nonconverged_or_violation 触发次数大于 nonconverged_only，这是越限触发开启后的预期现象。\n');
end
fprintf(fid, 'summary rows=%d\n', height(summary));
end
