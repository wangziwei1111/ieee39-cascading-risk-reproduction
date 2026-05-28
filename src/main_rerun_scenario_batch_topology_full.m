function batch_summary = main_rerun_scenario_batch_topology_full()
%MAIN_RERUN_SCENARIO_BATCH_TOPOLOGY_FULL 强制重跑正式20-trial拓扑对比场景。
% 输入：
%   无。
% 输出：
%   results/scenarios/scenario_batch_summary_topology_compare.csv
% 物理含义：
%   仅重跑 no_renewable_base、distributed_wind_3000mw_base、centralized_wind_40pct，
%   用正式 Markov 样本数生成拓扑对比结果；不影响渗透率、风速和脱网记录场景。
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
cfg = base_config();

run_options = struct();
run_options.batch_mode = 'topology_compare';
run_options.markov_num_trials_per_initial_fault = cfg.markov_num_trials_per_initial_fault;
run_options.resume_existing = false;
run_options.force_rerun = true;
run_options.allow_smoke_reuse = false;
run_options.smoke_note = 'forced full topology_compare rerun; smoke reuse disabled.';

batch_summary = main_run_scenario_batch('topology_compare', run_options);
end
