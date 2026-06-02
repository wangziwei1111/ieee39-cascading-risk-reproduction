function main_run_full_event_formal_scenario_aligned_var_pilot()
%MAIN_RUN_FULL_EVENT_FORMAL_SCENARIO_ALIGNED_VAR_PILOT Run fixed full-event formal VaR pilot.
% This does not run local search, final_summary, all_full, OLS benchmark, or actual wind/generator trips.

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
ensure_dir(out_root);
log_path = fullfile(out_root, 'full_event_formal_var_pilot_run_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'full-event formal scenario-aligned VaR pilot run log\n');

transition_ready_path = fullfile(project_root, 'results', 'calibration', 'transition_probability', 'full_event_formal_var_pilot_readiness.csv');
scenario_ready_path = fullfile(project_root, 'results', 'calibration', 'diagnostics', 'formal_scenario_aligned_var_pilot_readiness.csv');
assert_ready(transition_ready_path, 'ready_for_full_event_formal_var_pilot', fid);
assert_ready(scenario_ready_path, 'formal_var_pilot_ready', fid);

parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_rows = {
"topology_compare","concentrated_bus34";
"topology_compare","distributed_30_39";
"wind_speed_scan","wind_speed_11_28";
"wind_speed_scan","wind_speed_12_00";
"penetration_scan","penetration_40pct";
"penetration_scan","penetration_60pct";
"penetration_scan","penetration_80pct"
};
scenario_table = cell2table(scenario_rows, 'VariableNames', {'target_group','scenario_id'});
snapshot_table = readtable(fullfile(project_root, 'results', 'calibration', 'diagnostics', 'pilot_scenario_config_snapshot.csv'), 'TextType', 'string');

for p = 1:numel(parameter_sets)
    parameter_set_id = parameter_sets(p);
    cfg_seed = load_benchmark_calibration_parameter_set(base_config(), parameter_set_id);
    cfg_seed.markov_num_trials_per_initial_fault = 10;
    cfg_seed.markov_random_seed = cfg_seed.seed;
    cfg_seed.chain_transition_probability_mode = 'bernoulli_full_event';
    cfg_seed.var_use_chain_weights = false;
    scenario_root_rel = fullfile('results', 'calibration', 'full_event_formal_var_pilot', char(parameter_set_id));

    for s = 1:height(scenario_table)
        scenario_id = string(scenario_table.scenario_id(s));
        scenario_dir = fullfile(project_root, scenario_root_rel, char(scenario_id));
        ensure_dir(scenario_dir);
        write_scenario_config_snapshot(snapshot_table, scenario_id, parameter_set_id, cfg_seed, scenario_dir);
        chain_path = fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv');
        if exist(chain_path, 'file') == 2
            fprintf(fid, 'SKIP existing result: %s / %s\n', parameter_set_id, scenario_id);
            export_transition_trace_if_possible(scenario_dir);
            continue;
        end
        fprintf(fid, 'RUN parameter_set=%s scenario=%s trials=10 mode=bernoulli_full_event\n', parameter_set_id, scenario_id);
        run_options = struct();
        run_options.markov_num_trials_per_initial_fault = 10;
        run_options.scenario_results_root = scenario_root_rel;
        run_options.cfg_overrides = cfg_seed;
        run_options.smoke_note = "full-event formal scenario-aligned VaR pilot; not final benchmark; no local search";
        try
            main_run_single_scenario(char(scenario_id), run_options);
            export_transition_trace_if_possible(scenario_dir);
        catch ME
            fprintf(fid, 'FAILED %s / %s: %s\n', parameter_set_id, scenario_id, ME.message);
            write_failure_log(scenario_dir, ME);
        end
    end
end
fprintf(fid, 'DONE\n');
fprintf('Wrote %s\n', log_path);
end

function assert_ready(path, field_name, fid)
if exist(path, 'file') ~= 2
    fprintf(fid, 'BLOCKED missing readiness file: %s\n', path);
    error('Missing readiness file: %s', path);
end
tbl = readtable(path, 'TextType', 'string');
if ~ismember(field_name, tbl.Properties.VariableNames) || ~logical(tbl.(field_name)(1))
    fprintf(fid, 'BLOCKED %s is not 1 in %s\n', field_name, path);
    error('%s != 1; refusing to run full-event formal VaR pilot.', field_name);
end
fprintf(fid, 'READY %s\n', path);
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
    string(cfg.chain_transition_probability_mode), string(cfg.paper_line_parameter_calibration_status), ...
    "full-event formal scenario-aligned VaR pilot config snapshot; not final benchmark", ...
    'VariableNames', {'scenario_id','parameter_set_id','wind_injection_mode','wind_buses', ...
    'wind_capacity_total_mw','paper_wind_penetration','load_based_wind_penetration', ...
    'wind_penetration_basis','wind_speed_mps','branch_count','slack_bus', ...
    'wind_power_curve_profile','wind_cut_in_speed','wind_rated_speed','wind_cut_out_speed', ...
    'expected_wind_power_total_mw','actual_wind_pg_total_mw_in_case','wind_curve_source_status', ...
    'markov_trials_per_initial_fault','random_seed','stage_probability_mode', ...
    'calibration_status','note'});
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

function export_transition_trace_if_possible(scenario_dir)
mat_path = fullfile(scenario_dir, 'chains', 'markov_chain_records.mat');
if exist(mat_path, 'file') ~= 2
    return;
end
S = load(mat_path, 'chain_records');
chain_records = S.chain_records;
stage_tbl = flatten_stage_transition_probability_records_local(chain_records);
candidate_tbl = build_candidate_probability_trace_local(chain_records);
writetable(stage_tbl, fullfile(scenario_dir, 'tables', 'stage_transition_probability_details.csv'));
writetable(candidate_tbl, fullfile(scenario_dir, 'tables', 'candidate_probability_trace.csv'));
end

function tbl = flatten_stage_transition_probability_records_local(chain_records)
rows = {};
for i = 1:numel(chain_records)
    c = chain_records(i);
    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        if ~isfield(st, 'transition_probability_detail'), continue; end
        d = st.transition_probability_detail;
        rows{end+1,1} = table(c.initial_branch, c.trial_id, st.stage_id, ...
            string(get_stage_field(st, 'terminated_reason', "")), string(d.stage_probability_mode), ...
            d.candidate_count, d.selected_candidate_count, d.unselected_candidate_count, ...
            d.selected_probability_product, d.unselected_probability_product, d.stage_transition_probability, ...
            string(d.probability_status), logical(get_detail_field(d, 'terminal_stage_flag', false)), ...
            logical(get_detail_field(d, 'should_multiply_candidate_complements', true)), ...
            string(get_detail_field(d, 'missing_reason', "")), string(get_detail_field(d, 'selected_branch_ids', "")), ...
            string(get_detail_field(d, 'random_u_selected', "")), string(get_detail_field(d, 'candidate_probability_basis', "")), ...
            string(d.note), ...
            'VariableNames', {'initial_branch','trial_id','stage_id','terminated_reason', ...
            'stage_probability_mode','candidate_count','selected_candidate_count','unselected_candidate_count', ...
            'selected_probability_product','unselected_probability_product','stage_transition_probability', ...
            'probability_status','terminal_stage_flag','should_multiply_candidate_complements', ...
            'missing_reason','selected_branch_ids','random_u_selected','candidate_probability_basis','note'}); %#ok<AGROW>
    end
end
if isempty(rows), tbl = table(); else, tbl = vertcat(rows{:}); end
end

function candidate_trace = build_candidate_probability_trace_local(chain_records)
candidate_trace = flatten_candidate_tables(chain_records);
if isempty(candidate_trace), return; end
candidate_trace.Properties.VariableNames{'outage_probability'} = 'candidate_probability';
candidate_trace.selected = candidate_trace.trip_selected;
candidate_trace = candidate_trace(:, {'initial_branch','trial_id','stage_id','candidate_branch', ...
    'loading_pu','candidate_probability','prob_model','engineering_probability','paper_formula_probability', ...
    'paper_formula_status','paper_formula_missing_parameters','paper_formula_used_fallback','random_u','selected'});
end

function write_failure_log(scenario_dir, ME)
ensure_dir(fullfile(scenario_dir, 'logs'));
fid = fopen(fullfile(scenario_dir, 'logs', 'scenario_run_log.txt'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'FAILED full-event formal pilot scenario\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
end

function value = get_stage_field(s, name, default_value)
if isfield(s, name), value = s.(name); else, value = default_value; end
end

function value = get_detail_field(s, name, default_value)
if isstruct(s) && isfield(s, name), value = s.(name); else, value = default_value; end
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
