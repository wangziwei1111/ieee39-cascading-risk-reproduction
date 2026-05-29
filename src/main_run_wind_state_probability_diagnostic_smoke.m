function main_run_wind_state_probability_diagnostic_smoke()
%MAIN_RUN_WIND_STATE_PROBABILITY_DIAGNOSTIC_SMOKE Small record-only P_wt(E_k) smoke.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'renewable', 'wind_state_probability_diagnostic_smoke');
ensure_dir(out_root);

cfg0 = base_config();
require_matpower(cfg0);
parameter_sets = ["strict_missing", "lvrt_hvrt_threshold_record", "diagnostic_linear_voltage_probability"];
for k = 1:numel(parameter_sets)
    run_one(project_root, out_root, cfg0, parameter_sets(k));
end
fprintf('wind state probability diagnostic smoke written: %s\n', out_root);
end

function run_one(project_root, out_root, cfg0, parameter_set_id)
cfg = load_wind_trip_probability_parameter_set(cfg0, parameter_set_id);
cfg.enable_wind_voltage_trip_sampling = true;
cfg.wind_trip_record_only = true;
cfg.wind_trip_state_probability_enable = true;
cfg.wind_trip_state_probability_mode = 'diagnostic_probability_only';
cfg.markov_num_trials_per_initial_fault = 3;
cfg.markov_random_seed = cfg.seed;
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
cfg.line_outage_probability_model = 'engineering';
rng(cfg.markov_random_seed);

case_dir = fullfile(out_root, char(parameter_set_id));
ensure_dir(case_dir);

base_mpc0 = build_case39_base(cfg);
scenario = get_scenario_by_id('distributed_wind_3000mw_base', cfg, sum(base_mpc0.bus(:, 3)));
[base_mpc, renewable_info] = apply_renewable_scenario(base_mpc0, scenario);

chain_cells = {};
idx = 0;
for initial_branch = 1:5
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        chain_cells{idx, 1} = search_cascade_markov_line(base_mpc, initial_branch, cfg, scenario, renewable_info, trial_id); %#ok<AGROW>
    end
end
chain_records = vertcat(chain_cells{:});
[chain_summary_table, ~] = flatten_chain_records(chain_records, cfg);
wind_trip_detail_table = flatten_wind_trip_records(chain_records);
wind_state_stage_table = flatten_wind_state_probability_records(chain_records);
wind_state_summary_table = summarize_wind_state_probability_records(wind_state_stage_table, cfg);

save(fullfile(case_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', 'renewable_info', 'base_mpc', '-v7.3');
writetable(chain_summary_table, fullfile(case_dir, 'markov_chain_summary.csv'));
writetable(wind_trip_detail_table, fullfile(case_dir, 'wind_trip_probability_details.csv'));
writetable(wind_state_stage_table, fullfile(case_dir, 'wind_state_probability_stage_details.csv'));
writetable(wind_state_summary_table, fullfile(case_dir, 'wind_state_probability_summary.csv'));
write_log(fullfile(case_dir, 'diagnostic_log.txt'), cfg, parameter_set_id, chain_summary_table, wind_state_summary_table);
end

function write_log(path, cfg, parameter_set_id, chain_summary_table, summary_table)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'wind_state_probability_diagnostic_smoke\n');
fprintf(fid, 'parameter_set_id=%s\n', parameter_set_id);
fprintf(fid, 'probability_model=%s\n', cfg.wind_trip_probability_model);
fprintf(fid, 'calibration_status=%s\n', cfg.wind_trip_parameter_calibration_status);
fprintf(fid, 'scenario=distributed_wind_3000mw_base\n');
fprintf(fid, 'initial_branches=1:5\n');
fprintf(fid, 'trials_per_initial_fault=%d\n', cfg.markov_num_trials_per_initial_fault);
fprintf(fid, 'chain_count=%d\n', height(chain_summary_table));
fprintf(fid, 'valid_stage_count=%d\n', summary_table.valid_stage_count(1));
fprintf(fid, 'missing_probability_stage_count=%d\n', summary_table.missing_probability_stage_count(1));
fprintf(fid, 'note=Record-only diagnostic; no wind unit was tripped and Markov line sampling was unchanged.\n');
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
