function batch_summary = main_run_scenario_batch_smoke()
%MAIN_RUN_SCENARIO_BATCH_SMOKE 运行第4章场景扫描smoke test。
% 输入：
%   无。
% 输出：
%   batch_summary - 三个smoke场景的汇总表。
% 物理含义：
%   该入口只用于检查场景框架是否可运行。每个初始故障仅运行5条Markov样本，不是最终论文结果。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();

scenario_ids = {'no_renewable_base', 'distributed_wind_40pct', 'centralized_wind_40pct'};
run_options = struct();
run_options.markov_num_trials_per_initial_fault = cfg.scenario_smoke_trials_per_initial_fault;
run_options.smoke_note = 'smoke test uses 5 trials per initial fault, not final paper result.';

rows = cell(numel(scenario_ids), 1);
for k = 1:numel(scenario_ids)
    result_struct = main_run_single_scenario(scenario_ids{k}, run_options);
    rows{k} = struct2table(result_struct);
end

batch_summary = vertcat(rows{:});
scenario_root = fullfile(project_root, cfg.scenario_results_root);
if ~exist(scenario_root, 'dir')
    mkdir(scenario_root);
end
save_result_table(batch_summary, fullfile(scenario_root, 'scenario_batch_summary_smoke.csv'), true);

collect_scenario_results(scenario_ids, fullfile(project_root, cfg.scenario_results_root));
plot_scenario_comparison(fullfile(project_root, cfg.scenario_results_root));
fprintf('场景smoke test完成，结果：%s\n', fullfile(scenario_root, 'scenario_batch_summary_smoke.csv'));
end
