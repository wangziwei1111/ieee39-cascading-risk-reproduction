function main_run_wind_trip_probability_record_smoke()
%MAIN_RUN_WIND_TRIP_PROBABILITY_RECORD_SMOKE Tiny record-only P_WT smoke.
% Runs only first 3 initial branches x 2 trials for two wind-speed scenarios.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_root = fullfile(project_root, 'results', 'calibration', 'renewable_trip', 'wind_trip_record_smoke');
ensure_dir(out_root);

scenario_ids = ["wind_speed_11_28", "wind_speed_12_00"];
for s = 1:numel(scenario_ids)
    scenario_id = scenario_ids(s);
    scenario_dir = fullfile(out_root, char(scenario_id));
    ensure_dir(scenario_dir);
    ensure_dir(fullfile(scenario_dir, 'tables'));
    ensure_dir(fullfile(scenario_dir, 'logs'));
    log_path = fullfile(scenario_dir, 'wind_trip_record_smoke_log.txt');
    fid = fopen(log_path, 'w');
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, 'wind trip probability record smoke\nscenario_id=%s\n', scenario_id);
    fprintf(fid, 'scope=first 3 initial branches x 2 trials; no formal pilot rerun; no local search\n');
    try
        chain_records = run_one_scenario(project_root, scenario_id, fid);
        write_outputs(chain_records, scenario_dir, scenario_id, project_root);
        fprintf(fid, 'status=done\n');
    catch ME
        fprintf(fid, 'status=failed\n%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
        rethrow(ME);
    end
    clear cleanup;
end
end

function chain_records = run_one_scenario(project_root, scenario_id, fid)
cfg = load_benchmark_calibration_parameter_set(base_config(), "low_hidden_failure");
cfg.project_root = project_root;
cfg.wind_power_curve_profile = 'paper_2_12_20';
cfg.markov_num_trials_per_initial_fault = 2;
cfg.markov_random_seed = cfg.seed;
cfg.chain_transition_probability_mode = 'bernoulli_full_event';
cfg.enable_wind_voltage_trip_sampling = true;
cfg.record_wind_trip_probability_enable = true;
cfg.wind_trip_record_only = true;
cfg.wind_trip_interval_probability_mode = 'linear';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
require_matpower(cfg);
rng(cfg.markov_random_seed);
base_mpc = build_case39_base(cfg);
base_load = sum(base_mpc.bus(:, 3));
scenario = get_scenario_by_id(char(scenario_id), cfg, base_load);
scenario.wind_power_curve_profile = 'paper_2_12_20';
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
faults = enumerate_initial_faults(mpc);
fault_ids = faults.branch_index(1:min(3, height(faults)));
idx = 0;
chain_cells = cell(numel(fault_ids) * cfg.markov_num_trials_per_initial_fault, 1);
for f = 1:numel(fault_ids)
    for trial_id = 1:cfg.markov_num_trials_per_initial_fault
        idx = idx + 1;
        fprintf(fid, 'run initial_branch=%d trial_id=%d\n', fault_ids(f), trial_id);
        chain_cells{idx} = search_cascade_markov_line(mpc, fault_ids(f), cfg, scenario, renewable_info, trial_id);
    end
end
chain_records = vertcat(chain_cells{:});
end

function write_outputs(chain_records, scenario_dir, scenario_id, project_root)
cfg = base_config();
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
[chain_summary, ~] = flatten_chain_records(chain_records, cfg);
candidate_trace = build_candidate_probability_trace_local(chain_records);
stage_transition = flatten_stage_transition_probability_records_local(chain_records);
wind_trace = build_wind_trip_probability_trace(chain_records, scenario_id);
writetable(chain_summary, fullfile(scenario_dir, 'markov_chain_summary.csv'));
writetable(stage_transition, fullfile(scenario_dir, 'stage_transition_probability_details.csv'));
writetable(candidate_trace, fullfile(scenario_dir, 'candidate_probability_trace.csv'));
writetable(wind_trace, fullfile(scenario_dir, 'wind_trip_probability_trace.csv'));
end

function wind_trace = build_wind_trip_probability_trace(chain_records, scenario_id)
T = flatten_wind_trip_records(chain_records);
if isempty(T) || height(T) == 0
    wind_trace = table();
    return;
end
scenario_id_col = repmat(string(scenario_id), height(T), 1);
input_status = repmat("available_voltage_nominal_frequency", height(T), 1);
missing_mask = isnan(T.voltage_pu) | isnan(T.frequency_hz);
input_status(missing_mask) = "missing_voltage_frequency_inputs";
note = repmat("record-only; no wind unit was tripped and Markov line sampling was unchanged", height(T), 1);
wind_trace = table(scenario_id_col, T.initial_branch, T.trial_id, T.stage_id, T.wind_bus, ...
    T.voltage_pu, T.frequency_hz, T.P_U_low, T.P_U_high, T.P_f_low, T.P_f_high, T.p_wt_h, ...
    string(T.trip_region), input_status, string(T.wind_trip_source_status), ...
    note, ...
    'VariableNames', {'scenario_id', 'initial_branch', 'trial_id', 'stage_id', 'wind_bus', ...
    'U_pu', 'f_hz', 'P_U_low', 'P_U_high', 'P_f_low', 'P_f_high', 'P_wt', ...
    'wind_trip_region', 'input_status', 'source_status', 'note'});
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
            string(st.terminated_reason), string(d.stage_probability_mode), ...
            d.candidate_count, d.selected_candidate_count, d.unselected_candidate_count, ...
            d.selected_probability_product, d.unselected_probability_product, d.stage_transition_probability, ...
            string(d.probability_status), string(d.selected_outage_ids), string(d.note), ...
            'VariableNames', {'initial_branch','trial_id','stage_id','terminated_reason', ...
            'stage_probability_mode','candidate_count','selected_candidate_count','unselected_candidate_count', ...
            'selected_probability_product','unselected_probability_product','stage_transition_probability', ...
            'probability_status','selected_outage_ids','note'}); %#ok<AGROW>
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

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
