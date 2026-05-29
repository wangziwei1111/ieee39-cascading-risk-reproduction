function main_run_generator_state_probability_diagnostic_smoke()
%MAIN_RUN_GENERATOR_STATE_PROBABILITY_DIAGNOSTIC_SMOKE Small record-only P_ge(E_k) smoke.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'generator', 'generator_state_probability_diagnostic_smoke');
ensure_dir(out_root);

cfg0 = base_config();
require_matpower(cfg0);
parameter_sets = ["strict_missing", "paper_formula_structure_only", "diagnostic_voltage_frequency_probability"];
for k = 1:numel(parameter_sets)
    run_one(project_root, out_root, cfg0, parameter_sets(k));
end
fprintf('generator state probability diagnostic smoke written: %s\n', out_root);
end

function run_one(project_root, out_root, cfg0, parameter_set_id)
cfg = load_generator_outage_probability_parameter_set(cfg0, parameter_set_id);
cfg.generator_state_probability_enable = true;
cfg.generator_state_probability_mode = 'diagnostic_probability_only';
cfg.enable_wind_voltage_trip_sampling = false;
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
generator_trip_detail_table = flatten_generator_trip_records_local(chain_records);
generator_state_stage_table = flatten_generator_state_probability_records(chain_records);
generator_state_summary_table = summarize_generator_state_probability_records(generator_state_stage_table, cfg);

save(fullfile(case_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', 'renewable_info', 'base_mpc', '-v7.3');
writetable(chain_summary_table, fullfile(case_dir, 'markov_chain_summary.csv'));
writetable(generator_trip_detail_table, fullfile(case_dir, 'generator_trip_probability_details.csv'));
writetable(generator_state_stage_table, fullfile(case_dir, 'generator_state_probability_stage_details.csv'));
writetable(generator_state_summary_table, fullfile(case_dir, 'generator_state_probability_summary.csv'));
write_log(fullfile(case_dir, 'diagnostic_log.txt'), cfg, parameter_set_id, chain_summary_table, generator_state_summary_table);
end

function tbl = flatten_generator_trip_records_local(chain_records)
tables = {};
for c = 1:numel(chain_records)
    stages = chain_records(c).stage_records;
    for s = 1:numel(stages)
        if isfield(stages(s), 'generator_trip_table') && istable(stages(s).generator_trip_table) && ...
                height(stages(s).generator_trip_table) > 0
            tables{end+1,1} = stages(s).generator_trip_table; %#ok<AGROW>
        end
    end
end
if isempty(tables)
    tbl = table();
else
    tbl = vertcat(tables{:});
end
end

function write_log(path, cfg, parameter_set_id, chain_summary_table, summary_table)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'generator_state_probability_diagnostic_smoke\n');
fprintf(fid, 'parameter_set_id=%s\n', parameter_set_id);
fprintf(fid, 'probability_model=%s\n', cfg.generator_outage_probability_model);
fprintf(fid, 'calibration_status=%s\n', cfg.gen_trip_parameter_calibration_status);
fprintf(fid, 'scenario=distributed_wind_3000mw_base\n');
fprintf(fid, 'initial_branches=1:5\n');
fprintf(fid, 'trials_per_initial_fault=%d\n', cfg.markov_num_trials_per_initial_fault);
fprintf(fid, 'chain_count=%d\n', height(chain_summary_table));
fprintf(fid, 'valid_stage_count=%d\n', summary_table.valid_stage_count(1));
fprintf(fid, 'missing_probability_stage_count=%d\n', summary_table.missing_probability_stage_count(1));
fprintf(fid, 'note=Record-only diagnostic; no traditional generator was tripped and Markov line sampling was unchanged.\n');
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
