function batch_summary = main_run_scenario_batch_smoke()
%MAIN_RUN_SCENARIO_BATCH_SMOKE 运行第4章场景扫描smoke test。
% 物理含义：
%   smoke只用于框架检查，每个初始故障使用5条Markov样本，不是最终论文结果。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();

run_options = struct();
run_options.batch_mode = 'smoke';
run_options.markov_num_trials_per_initial_fault = cfg.scenario_smoke_trials_per_initial_fault;
run_options.resume_existing = false;
run_options.force_rerun = true;
run_options.smoke_note = 'smoke test uses 5 trials per initial fault, not final paper result.';

batch_summary = main_run_scenario_batch('smoke', run_options);
end
