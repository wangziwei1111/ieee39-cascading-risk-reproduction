function batch_summary = main_run_scenario_batch_full()
%MAIN_RUN_SCENARIO_BATCH_FULL 第4章完整场景扫描入口。
% 物理含义：
%   full batch耗时较长，建议先运行topology/penetration/wind speed等分组入口。
%   该入口默认断点续跑，不重复覆盖已有完整场景。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();

run_options = struct();
run_options.batch_mode = 'all_full';
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.resume_existing = true;
run_options.force_rerun = false;
run_options.smoke_note = 'full batch uses configured Markov trials per initial fault.';

batch_summary = main_run_scenario_batch('all_full', run_options);
end
