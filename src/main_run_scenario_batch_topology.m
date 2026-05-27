function batch_summary = main_run_scenario_batch_topology()
%MAIN_RUN_SCENARIO_BATCH_TOPOLOGY 运行拓扑/接入方式对比小组。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
run_options = struct();
run_options.batch_mode = 'topology_compare';
run_options.markov_num_trials_per_initial_fault = cfg.scenario_smoke_trials_per_initial_fault;
run_options.resume_existing = true;
run_options.force_rerun = false;
run_options.allow_smoke_reuse = true;
run_options.smoke_note = 'topology_compare batch uses resume_existing=true.';
batch_summary = main_run_scenario_batch('topology_compare', run_options);
end
