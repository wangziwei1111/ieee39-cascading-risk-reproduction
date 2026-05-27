function batch_summary = main_run_scenario_batch_full()
%MAIN_RUN_SCENARIO_BATCH_FULL 第4章完整场景扫描入口。
% 输入：
%   无。
% 输出：
%   batch_summary - 完整场景扫描汇总表。
% 物理含义：
%   该脚本准备完整扫描列表，但不会由smoke test自动调用。完整运行耗时较长，需人工确认后执行。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
require_matpower(cfg);
base_mpc = build_case39_base(cfg);
base_load_mw = sum(base_mpc.bus(:, 3));
scenarios = build_scenario_library(cfg, base_load_mw);

scenario_ids = {scenarios.scenario_id};
run_options = struct();
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.smoke_note = 'full batch uses configured Markov trials per initial fault.';

rows = cell(numel(scenario_ids), 1);
for k = 1:numel(scenario_ids)
    result_struct = main_run_single_scenario(scenario_ids{k}, run_options);
    rows{k} = struct2table(result_struct);
end

batch_summary = vertcat(rows{:});
scenario_root = fullfile(project_root, cfg.scenario_results_root);
save_result_table(batch_summary, fullfile(scenario_root, 'scenario_batch_summary_full.csv'), true);
collect_scenario_results(scenario_ids, scenario_root);
plot_scenario_comparison(scenario_root);
end
