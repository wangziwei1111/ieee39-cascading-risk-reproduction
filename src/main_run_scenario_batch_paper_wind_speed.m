function batch_summary = main_run_scenario_batch_paper_wind_speed()
%MAIN_RUN_SCENARIO_BATCH_PAPER_WIND_SPEED 运行论文表4-6指定风速点批次。
% 物理含义：
%   只运行 11.28/11.52/11.76/12.00 m/s 四个论文风速点；该批次与工程
%   wind_speed_scan 分离，不复用 8/10/12/14/16 m/s 结果。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();
run_options = struct();
run_options.batch_mode = 'paper_wind_speed_scan';
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.resume_existing = true;
run_options.force_rerun = false;
run_options.allow_smoke_reuse = false;
run_options.smoke_note = 'paper_wind_speed_scan uses thesis Table 4-6 wind speed points only.';
batch_summary = main_run_scenario_batch('paper_wind_speed_scan', run_options);
end
