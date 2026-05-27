function batch_summary = main_run_scenario_batch_trip_record()
%MAIN_RUN_SCENARIO_BATCH_TRIP_RECORD 运行新能源脱网概率记录对比小组。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
run_options = struct();
run_options.batch_mode = 'renewable_trip_record';
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.resume_existing = true;
run_options.force_rerun = false;
run_options.allow_smoke_reuse = false;
run_options.smoke_note = 'renewable_trip_record batch records trip probability only; no actual renewable tripping.';
batch_summary = main_run_scenario_batch('renewable_trip_record', run_options);
scenario_root = fullfile(project_root, cfg.scenario_results_root);
compare_trip_record_vs_base(scenario_root);
plot_scenario_comparison(scenario_root, 'renewable_trip_record');
end
