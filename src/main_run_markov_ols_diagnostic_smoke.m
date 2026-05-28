function main_run_markov_ols_diagnostic_smoke()
%MAIN_RUN_MARKOV_OLS_DIAGNOSTIC_SMOKE 运行小规模Markov OLS诊断烟测。
% 输入：
%   无。固定使用 distributed_wind_3000mw_base、前5条初始线路和每线3次样本。
% 输出：
%   results/loadshedding/diagnostic_smoke/markov_chain_summary.csv
%   results/loadshedding/diagnostic_smoke/ols_stage_details.csv
%   results/loadshedding/diagnostic_smoke/ols_summary.csv
%   results/loadshedding/diagnostic_smoke/ols_diagnostic_log.txt
% 物理含义：
%   both_diagnostic 模式主链路仍返回 simple_load_shedding 结果，OLS只做旁路诊断，
%   因此不改变线路Markov抽样逻辑或既有场景结果。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'loadshedding', 'diagnostic_smoke');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

log_path = fullfile(out_dir, 'ols_diagnostic_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('Markov OLS诊断烟测开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

cfg = base_config();
cfg.load_shedding_mode = 'both_diagnostic';
cfg.paper_ols_enable = true;
cfg.markov_num_trials_per_initial_fault = 3;
cfg.markov_random_seed = cfg.seed;
cfg.results_table_dir = out_dir;
cfg.results_chain_dir = out_dir;
cfg.results_log_dir = out_dir;
require_matpower(cfg);
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
        initial_branch = faults.branch_index(f);
        fprintf('诊断链：initial_branch=%d, trial=%d\n', initial_branch, trial_id);
        chain_cells{row} = search_cascade_markov_line(mpc, initial_branch, cfg, scenario, renewable_info, trial_id);
    end
end
chain_records = vertcat(chain_cells{:});

[chain_summary_table, ~] = flatten_chain_records(chain_records, cfg);
ols_stage_details = flatten_ols_records(chain_records);
ols_summary = summarize_ols_records(ols_stage_details);

save_result_table(chain_summary_table, fullfile(out_dir, 'markov_chain_summary.csv'), true);
save_result_table(ols_stage_details, fullfile(out_dir, 'ols_stage_details.csv'), true);
save_result_table(ols_summary, fullfile(out_dir, 'ols_summary.csv'), true);
save(fullfile(out_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', '-v7.3');

fprintf('诊断链条数：%d\n', height(chain_summary_table));
fprintf('OLS逐级记录行数：%d\n', height(ols_stage_details));
disp(ols_summary);
fprintf('Markov OLS诊断烟测完成。\n');
write_plain_log(log_path, chain_summary_table, ols_stage_details, ols_summary);
end

function write_plain_log(log_path, chain_summary_table, ols_stage_details, ols_summary)
fid = fopen(log_path, 'w');
if fid < 0
    warning('无法写入OLS诊断烟测日志：%s', log_path);
    return;
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Markov OLS诊断烟测日志\n');
fprintf(fid, '生成时间：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '链条数：%d\n', height(chain_summary_table));
fprintf(fid, 'OLS逐级记录行数：%d\n', height(ols_stage_details));
if ~isempty(ols_summary) && height(ols_summary) > 0
    fprintf(fid, 'total_ols_attempts=%d\n', ols_summary.total_ols_attempts(1));
    fprintf(fid, 'successful_ols_count=%d\n', ols_summary.successful_ols_count(1));
    fprintf(fid, 'failed_ols_count=%d\n', ols_summary.failed_ols_count(1));
    fprintf(fid, 'num_fallback_to_simple=%d\n', ols_summary.num_fallback_to_simple(1));
end
fprintf(fid, '说明：both_diagnostic主链路仍使用simple_load_shedding，OLS仅用于旁路诊断。\n');
end
