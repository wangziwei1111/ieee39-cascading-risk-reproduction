function main_run_full_event_formal_var_pilot_after_curve_fix()
%MAIN_RUN_FULL_EVENT_FORMAL_VAR_PILOT_AFTER_CURVE_FIX Run post-curve-fix full-event pilot.
% No local search, parameter tuning, final_summary, OLS benchmark, or actual
% wind/generator trip transition is performed.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
ensure_dir(out_root);
log_path = fullfile(out_root, 'full_event_formal_var_pilot_after_curve_fix_run_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'curve-fix full-event formal scenario-aligned VaR pilot run log\n');

curve_ready = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot', 'post_wind_curve_fix_readiness.csv');
transition_ready = fullfile(project_root, 'results', 'calibration', 'transition_probability', 'full_event_formal_var_pilot_readiness.csv');
assert_ready(curve_ready, 'ready_for_full_event_formal_pilot_rerun', fid);
assert_ready(transition_ready, 'ready_for_full_event_formal_var_pilot', fid);

parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];

for p = 1:numel(parameter_sets)
    parameter_set_id = parameter_sets(p);
    cfg_seed = load_benchmark_calibration_parameter_set(base_config(), parameter_set_id);
    cfg_seed.wind_power_curve_profile = 'paper_2_12_20';
    cfg_seed.markov_num_trials_per_initial_fault = 10;
    cfg_seed.markov_random_seed = cfg_seed.seed;
    cfg_seed.chain_transition_probability_mode = 'bernoulli_full_event';
    cfg_seed.var_use_chain_weights = false;
    scenario_root_rel = fullfile('results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix', char(parameter_set_id));
    for s = 1:numel(scenario_ids)
        scenario_id = scenario_ids(s);
        scenario_dir = fullfile(project_root, scenario_root_rel, char(scenario_id));
        ensure_dir(scenario_dir);
        try
            write_scenario_config_snapshot_after_curve_fix(project_root, scenario_id, parameter_set_id, cfg_seed, scenario_dir);
            chain_path = fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv');
            if exist(chain_path, 'file') == 2
                fprintf(fid, 'SKIP existing after-curve-fix result: %s / %s\n', parameter_set_id, scenario_id);
                export_transition_trace_if_possible(scenario_dir);
                continue;
            end
            fprintf(fid, 'RUN parameter_set=%s scenario=%s trials=10 mode=bernoulli_full_event curve=paper_2_12_20\n', parameter_set_id, scenario_id);
            run_options = struct();
            run_options.markov_num_trials_per_initial_fault = 10;
            run_options.scenario_results_root = scenario_root_rel;
            run_options.cfg_overrides = cfg_seed;
            run_options.smoke_note = "curve-fix full-event formal scenario-aligned VaR pilot; not final benchmark; no local search";
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
T = readtable(path, 'TextType', 'string', 'Delimiter', ',');
if ~ismember(field_name, T.Properties.VariableNames) || ~logical(T.(field_name)(1))
    fprintf(fid, 'BLOCKED %s is not 1 in %s\n', field_name, path);
    error('%s != 1; refusing to run after-curve-fix pilot.', field_name);
end
fprintf(fid, 'READY %s\n', path);
end

function write_scenario_config_snapshot_after_curve_fix(project_root, scenario_id, parameter_set_id, cfg, scenario_dir)
require_matpower(cfg);
base_mpc = build_case39_base(cfg);
base_load = sum(base_mpc.bus(:, 3));
scenario = get_scenario_by_id(char(scenario_id), cfg, base_load);
scenario.wind_power_curve_profile = 'paper_2_12_20';
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
wind_rows = renewable_info.wind_gen_rows(:);
actual_wind_pg = sum(mpc.gen(wind_rows, 2));
[expected_wind_power, curve_detail] = compute_paper_wind_power_curve(scenario.wind_speed_mps, scenario.total_wind_capacity_mw, cfg);
mode = "distributed";
if numel(scenario.wind_buses) == 1, mode = "concentrated"; end
T = table(string(scenario_id), string(parameter_set_id), mode, join(string(scenario.wind_buses), ":"), ...
    scenario.total_wind_capacity_mw, scenario.paper_wind_penetration, scenario.load_based_wind_penetration, ...
    string(scenario.wind_penetration_basis), scenario.wind_speed_mps, size(mpc.branch,1), scenario.slack_bus, ...
    string(curve_detail.curve_profile), curve_detail.cut_in_speed, curve_detail.rated_speed, curve_detail.cut_out_speed, ...
    expected_wind_power, actual_wind_pg, string(curve_detail.source_status), string(cfg.chain_transition_probability_mode), ...
    cfg.markov_num_trials_per_initial_fault, cfg.markov_random_seed, string(cfg.paper_line_parameter_calibration_status), ...
    "after-curve-fix full-event formal pilot config snapshot; not final benchmark", ...
    'VariableNames', {'scenario_id','parameter_set_id','wind_injection_mode','wind_buses', ...
    'wind_capacity_total_mw','paper_wind_penetration','load_based_wind_penetration', ...
    'wind_penetration_basis','wind_speed_mps','branch_count','slack_bus', ...
    'wind_power_curve_profile','wind_cut_in_speed','wind_rated_speed','wind_cut_out_speed', ...
    'expected_wind_power_total_mw','actual_wind_pg_total_mw_in_case','wind_curve_source_status', ...
    'chain_transition_probability_mode','markov_trials_per_initial_fault','random_seed','calibration_status','note'});
writetable(T, fullfile(scenario_dir, 'scenario_config_snapshot.csv'));
end

function export_transition_trace_if_possible(scenario_dir)
mat_path = fullfile(scenario_dir, 'chains', 'markov_chain_records.mat');
if exist(mat_path, 'file') ~= 2, return; end
S = load(mat_path, 'chain_records');
stage_tbl = flatten_stage_transition_probability_records_local(S.chain_records);
candidate_tbl = build_candidate_probability_trace_local(S.chain_records);
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
fprintf(fid, 'FAILED after-curve-fix full-event formal pilot scenario\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
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
