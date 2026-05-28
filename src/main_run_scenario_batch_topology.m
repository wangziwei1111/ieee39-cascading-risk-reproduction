function batch_summary = main_run_scenario_batch_topology()
%MAIN_RUN_SCENARIO_BATCH_TOPOLOGY 运行正式拓扑/接入方式对比小组。
% 该入口使用 cfg.markov_num_trials_per_initial_fault，不复用 smoke 的 5-trial 结果。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
run_options = struct();
run_options.batch_mode = 'topology_compare';
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.resume_existing = true;
run_options.force_rerun = false;
run_options.allow_smoke_reuse = false;
run_options.smoke_note = 'topology_compare uses full trial count and does not reuse smoke results.';
batch_summary = main_run_scenario_batch('topology_compare', run_options);
end
