function batch_summary = main_run_scenario_batch_wind_speed()
%MAIN_RUN_SCENARIO_BATCH_WIND_SPEED 运行风速扫描小组。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
run_options = struct();
run_options.batch_mode = 'wind_speed_scan';
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.resume_existing = true;
run_options.force_rerun = false;
run_options.allow_smoke_reuse = false;
run_options.smoke_note = 'wind_speed_scan batch uses resume_existing=true.';
batch_summary = main_run_scenario_batch('wind_speed_scan', run_options);
end
