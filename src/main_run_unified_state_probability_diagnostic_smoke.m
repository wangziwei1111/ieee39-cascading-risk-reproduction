function main_run_unified_state_probability_diagnostic_smoke()
%MAIN_RUN_UNIFIED_STATE_PROBABILITY_DIAGNOSTIC_SMOKE Same-run P_line/P_wt/P_ge/P_total smoke.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'composite', 'unified_state_probability_diagnostic_smoke');
ensure_dir(out_dir);
cfg = base_config();
require_matpower(cfg);
cfg = load_paper_line_probability_parameter_set(cfg, 'table41_P_L0_only');
cfg = load_wind_trip_probability_parameter_set(cfg, 'diagnostic_linear_voltage_probability');
cfg = load_generator_outage_probability_parameter_set(cfg, 'diagnostic_voltage_frequency_probability');
cfg.unified_state_probability_diagnostic_enable = true;
cfg.unified_state_probability_diagnostic_mode = 'diagnostic_probability_only';
cfg.unified_line_probability_parameter_set = 'table41_P_L0_only';
cfg.unified_wind_probability_parameter_set = 'diagnostic_linear_voltage_probability';
cfg.unified_generator_probability_parameter_set = 'diagnostic_voltage_frequency_probability';
cfg.unified_composite_probability_missing_policy = 'component_nan';
cfg.line_outage_probability_model = 'paper_formula_diagnostic';
cfg.paper_line_missing_param_policy = 'fallback_to_engineering_with_warning';
cfg.enable_wind_voltage_trip_sampling = true;
cfg.wind_trip_state_probability_enable = true;
cfg.wind_trip_state_probability_mode = 'diagnostic_probability_only';
cfg.generator_state_probability_enable = true;
cfg.generator_state_probability_mode = 'diagnostic_probability_only';
cfg.markov_num_trials_per_initial_fault = 3;
cfg.markov_random_seed = cfg.seed;
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
rng(cfg.markov_random_seed);

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
unified_stage_table = flatten_unified_state_probability_records(chain_records);
unified_summary_table = summarize_unified_state_probability_records(unified_stage_table);
wind_trip_detail_table = flatten_wind_trip_records(chain_records);
generator_trip_detail_table = flatten_generator_trip_records_local(chain_records);
line_candidate_detail_table = flatten_unified_line_probability_tables(chain_records);
stage_severity_table = flatten_stage_severity_records(chain_records);

save(fullfile(out_dir, 'markov_chain_records.mat'), 'chain_records', 'cfg', 'scenario', 'renewable_info', 'base_mpc', '-v7.3');
writetable(chain_summary_table, fullfile(out_dir, 'markov_chain_summary.csv'));
writetable(unified_stage_table, fullfile(out_dir, 'unified_state_probability_stage_details.csv'));
writetable(unified_summary_table, fullfile(out_dir, 'unified_state_probability_summary.csv'));
writetable(stage_severity_table, fullfile(out_dir, 'stage_severity_details.csv'));
writetable(wind_trip_detail_table, fullfile(out_dir, 'wind_trip_probability_details.csv'));
writetable(generator_trip_detail_table, fullfile(out_dir, 'generator_trip_probability_details.csv'));
writetable(line_candidate_detail_table, fullfile(out_dir, 'line_probability_candidate_details.csv'));
write_log(fullfile(out_dir, 'diagnostic_log.txt'), cfg, chain_summary_table, unified_summary_table);
fprintf('unified state probability diagnostic smoke written: %s\n', out_dir);
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
if isempty(tables), tbl = table(); else, tbl = vertcat(tables{:}); end
end

function tbl = flatten_unified_line_probability_tables(chain_records)
tables = {};
for c = 1:numel(chain_records)
    stages = chain_records(c).stage_records;
    for s = 1:numel(stages)
        if isfield(stages(s), 'unified_component_tables') && ...
                isfield(stages(s).unified_component_tables, 'line_probability_table')
            t = stages(s).unified_component_tables.line_probability_table;
            if istable(t) && height(t) > 0
                t.initial_branch = repmat(chain_records(c).initial_branch, height(t), 1);
                t.trial_id = repmat(chain_records(c).trial_id, height(t), 1);
                t.stage_id = repmat(stages(s).stage_id, height(t), 1);
                t = movevars(t, {'initial_branch', 'trial_id', 'stage_id'}, 'Before', 1);
                tables{end+1,1} = t; %#ok<AGROW>
            end
        end
    end
end
if isempty(tables), tbl = table(); else, tbl = vertcat(tables{:}); end
end

function write_log(path, cfg, chain_summary_table, unified_summary_table)
fid = fopen(path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'unified_state_probability_diagnostic_smoke\n');
fprintf(fid, 'scenario=distributed_wind_3000mw_base\n');
fprintf(fid, 'initial_branches=1:5\n');
fprintf(fid, 'trials_per_initial_fault=%d\n', cfg.markov_num_trials_per_initial_fault);
fprintf(fid, 'chain_count=%d\n', height(chain_summary_table));
fprintf(fid, 'line_parameter_set=%s\n', cfg.unified_line_probability_parameter_set);
fprintf(fid, 'wind_parameter_set=%s\n', cfg.unified_wind_probability_parameter_set);
fprintf(fid, 'generator_parameter_set=%s\n', cfg.unified_generator_probability_parameter_set);
fprintf(fid, 'valid_P_total_stage_count=%d\n', unified_summary_table.valid_P_total_stage_count(1));
fprintf(fid, 'note=Diagnostic only; no wind/generator state transition and no final_summary output.\n');
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
