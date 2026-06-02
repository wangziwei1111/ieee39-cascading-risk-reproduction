function main_run_formal_scenario_aligned_var_pilot()
%MAIN_RUN_FORMAL_SCENARIO_ALIGNED_VAR_PILOT Run fixed-parameter formal VaR pilot.
% This is a scenario-aligned pilot only. It does not run local search, all_full,
% final_summary, OLS benchmark, or actual wind/generator trip transitions.

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
if ~exist(out_root, 'dir'), mkdir(out_root); end
readiness_file = fullfile(project_root, 'results', 'calibration', 'diagnostics', 'formal_scenario_aligned_var_pilot_readiness.csv');
log_file = fullfile(out_root, 'formal_var_pilot_run_log.txt');
fid = fopen(log_file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'formal scenario-aligned VaR pilot run log\n');

if exist(readiness_file, 'file') ~= 2
    fprintf(fid, 'BLOCKED missing readiness file: %s\n', readiness_file);
    error('Missing formal VaR pilot readiness file.');
end
R = readtable(readiness_file, 'TextType', 'string', 'Delimiter', ',');
if ~logical(R.formal_var_pilot_ready(1))
    fprintf(fid, 'BLOCKED formal_var_pilot_ready is not 1. No simulation run.\n');
    error('formal_var_pilot_ready != 1; refusing to run formal VaR pilot.');
end

target_path = fullfile(project_root, 'results', 'calibration', 'diagnostics', 'calibration_target_benchmark_candidate_v2.csv');
targets = readtable(target_path, 'TextType', 'string', 'Delimiter', ',');
targets = targets(targets.recommended_use == 1, :);
scenario_ids = unique(targets.scenario_id, 'stable');
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
snapshot_source = fullfile(project_root, 'results', 'calibration', 'diagnostics', 'pilot_scenario_config_snapshot.csv');
snapshot_table = readtable(snapshot_source, 'TextType', 'string', 'Delimiter', ',');

for p = 1:numel(parameter_sets)
    parameter_set_id = parameter_sets(p);
    cfg_seed = load_benchmark_calibration_parameter_set(base_config(), parameter_set_id);
    cfg_seed.markov_num_trials_per_initial_fault = 10;
    cfg_seed.markov_random_seed = cfg_seed.seed;
    scenario_root_rel = fullfile('results', 'calibration', 'formal_var_pilot', char(parameter_set_id));
    for s = 1:numel(scenario_ids)
        scenario_id = scenario_ids(s);
        scenario_dir = fullfile(project_root, scenario_root_rel, char(scenario_id));
        if ~exist(scenario_dir, 'dir'), mkdir(scenario_dir); end
        write_scenario_config_snapshot(snapshot_table, scenario_id, parameter_set_id, cfg_seed, scenario_dir);
        chain_path = fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv');
        if exist(chain_path, 'file') == 2
            fprintf(fid, 'SKIP existing result: %s / %s\n', parameter_set_id, scenario_id);
            continue;
        end
        fprintf(fid, 'RUN parameter_set=%s scenario=%s trials=10\n', parameter_set_id, scenario_id);
        run_options = struct();
        run_options.markov_num_trials_per_initial_fault = 10;
        run_options.scenario_results_root = scenario_root_rel;
        run_options.cfg_overrides = cfg_seed;
        run_options.smoke_note = "formal scenario-aligned VaR pilot; not final benchmark; no local search";
        try
            main_run_single_scenario(char(scenario_id), run_options);
        catch ME
            fprintf(fid, 'FAILED %s / %s: %s\n', parameter_set_id, scenario_id, ME.message);
        end
    end
end
fprintf(fid, 'DONE\n');
fprintf('Wrote %s\n', log_file);
end

function write_scenario_config_snapshot(snapshot_table, scenario_id, parameter_set_id, cfg, scenario_dir)
idx = find(snapshot_table.scenario_id == scenario_id, 1);
if isempty(idx)
    error('Missing dry-run scenario snapshot for %s', scenario_id);
end
row = snapshot_table(idx, :);
[expected_wind_power_total_mw, curve_detail] = compute_snapshot_wind_curve(row, cfg);
actual_wind_pg_total_mw_in_case = get_table_value(row, 'actual_wind_pg_total_mw_in_case', expected_wind_power_total_mw);
T = table(string(scenario_id), string(parameter_set_id), row.wind_injection_mode, row.wind_buses, ...
    row.wind_capacity_total_mw, row.paper_wind_penetration, row.load_based_wind_penetration, ...
    row.wind_penetration_basis, row.wind_speed_mps, row.branch_count, row.slack_bus, ...
    string(curve_detail.curve_profile), curve_detail.cut_in_speed, curve_detail.rated_speed, ...
    curve_detail.cut_out_speed, expected_wind_power_total_mw, actual_wind_pg_total_mw_in_case, ...
    string(curve_detail.source_status), ...
    cfg.markov_num_trials_per_initial_fault, cfg.markov_random_seed, ...
    string(cfg.paper_line_parameter_calibration_status), ...
    "formal scenario-aligned VaR pilot config snapshot; not final benchmark", ...
    'VariableNames', {'scenario_id','parameter_set_id','wind_injection_mode','wind_buses', ...
    'wind_capacity_total_mw','paper_wind_penetration','load_based_wind_penetration', ...
    'wind_penetration_basis','wind_speed_mps','branch_count','slack_bus', ...
    'wind_power_curve_profile','wind_cut_in_speed','wind_rated_speed','wind_cut_out_speed', ...
    'expected_wind_power_total_mw','actual_wind_pg_total_mw_in_case','wind_curve_source_status', ...
    'markov_trials_per_initial_fault','random_seed','calibration_status','note'});
writetable(T, fullfile(scenario_dir, 'scenario_config_snapshot.csv'));
end

function [power_mw, detail] = compute_snapshot_wind_curve(row, cfg)
curve_cfg = cfg;
curve_cfg.wind_power_curve_profile = get_cfg_string(cfg, 'wind_power_curve_profile', 'paper_2_12_20');
speed = get_table_value(row, 'wind_speed_mps', NaN);
capacity = get_table_value(row, 'wind_capacity_total_mw', NaN);
[power_mw, detail] = compute_paper_wind_power_curve(speed, capacity, curve_cfg);
end

function value = get_table_value(T, name, default_value)
if ismember(name, T.Properties.VariableNames)
    raw = T.(name)(1);
    if isnumeric(raw)
        value = double(raw);
    else
        value = str2double(string(raw));
    end
    if isnan(value)
        value = default_value;
    end
else
    value = default_value;
end
end

function value = get_cfg_string(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end
