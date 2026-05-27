function batch_summary = main_run_scenario_batch_penetration()
%MAIN_RUN_SCENARIO_BATCH_PENETRATION 运行新能源渗透率扫描小组。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
run_options = struct();
run_options.batch_mode = 'penetration_scan';
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.resume_existing = true;
run_options.force_rerun = false;
run_options.smoke_note = 'penetration_scan batch uses resume_existing=true.';
batch_summary = main_run_scenario_batch('penetration_scan', run_options);
end
