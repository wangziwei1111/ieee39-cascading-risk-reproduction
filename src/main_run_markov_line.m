function main_run_markov_line()
%MAIN_RUN_MARKOV_LINE 运行线路停运概率驱动的马尔可夫事故链搜索。
% 输入：
%   无。使用config/base_config.m和config/scenario_config.m中的配置。
% 输出：
%   results/tables/markov_chain_summary.csv - 每条事故链一行的汇总结果。
%   results/tables/markov_chain_stages.csv - 每条事故链逐级状态记录。
%   results/chains/markov_chain_records.mat - 保留完整候选线路表的MAT文件。
%   results/logs/markov_line_run_log.txt - 运行日志。
% 物理含义：
%   本入口在N-1基础上，根据线路负载率计算后续线路停运概率，通过随机
%   抽样形成多级N-1-1-...事故链。当前不计算论文VaR指标。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_log_dir = fullfile(project_root, cfg.results_log_dir);
cfg.results_chain_dir = fullfile(project_root, cfg.results_chain_dir);
scenario = scenario_config();

init_random_seed(cfg.markov_random_seed);

if ~exist(cfg.results_table_dir, 'dir')
    mkdir(cfg.results_table_dir);
end
if ~exist(cfg.results_log_dir, 'dir')
    mkdir(cfg.results_log_dir);
end
if ~exist(cfg.results_chain_dir, 'dir')
    mkdir(cfg.results_chain_dir);
end

log_path = fullfile(cfg.results_log_dir, 'markov_line_run_log.txt');
if exist(log_path, 'file')
    delete(log_path);
end
diary(log_path);
diary on;
cleanup_obj = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('线路马尔可夫事故链搜索开始：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('场景：%s\n', scenario.name);
fprintf('新能源调度模式：%s\n', scenario.renewable_dispatch_mode);
fprintf('随机种子：%d\n', cfg.markov_random_seed);
fprintf('每个初始故障样本数：%d，最大深度：%d\n', ...
    cfg.markov_num_trials_per_initial_fault, cfg.markov_max_depth);

require_matpower(cfg);

base_mpc = build_case39_base(cfg);
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
faults = enumerate_initial_faults(mpc);

num_chains = height(faults) * cfg.markov_num_trials_per_initial_fault;
chain_cells = cell(num_chains, 1);
idx = 0;

for f = 1:height(faults)
    initial_branch = faults.branch_index(f);
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        chain_cells{idx} = search_cascade_markov_line( ...
            mpc, initial_branch, cfg, scenario, renewable_info, trial_id);
    end
    fprintf('已完成初始故障 %d/%d：branch %d (%d-%d)\n', ...
        f, height(faults), initial_branch, faults.from_bus(f), faults.to_bus(f));
end

chain_records = vertcat(chain_cells{:});

[chain_summary_table, chain_stage_table] = flatten_chain_records(chain_records, cfg);

summary_csv = fullfile(cfg.results_table_dir, 'markov_chain_summary.csv');
stage_csv = fullfile(cfg.results_table_dir, 'markov_chain_stages.csv');
records_mat = fullfile(cfg.results_chain_dir, 'markov_chain_records.mat');

save_result_table(chain_summary_table, summary_csv);
save_result_table(chain_stage_table, stage_csv);
save(records_mat, 'chain_records', 'cfg', 'scenario', 'renewable_info', '-v7');

fprintf('事故链汇总结果已写入：%s\n', summary_csv);
fprintf('事故链逐级结果已写入：%s\n', stage_csv);
fprintf('事故链MAT记录已写入：%s\n', records_mat);
fprintf('终止原因统计：\n');
disp(groupsummary(chain_summary_table, 'terminated_reason'));
fprintf('线路马尔可夫事故链搜索结束：%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
end
