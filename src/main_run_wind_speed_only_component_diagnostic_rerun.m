function main_run_wind_speed_only_component_diagnostic_rerun()
% Diagnostic-only wind-speed component rerun. No local search, no final_summary.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(genpath(fullfile(root, 'src')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
ensure_dir(out_root);
psets = ["high_hidden_failure","benchmark_calibrated_seed"];
scens = ["wind_speed_11_28","wind_speed_12_00"];
for p = 1:numel(psets)
    cfg_seed = load_benchmark_calibration_parameter_set(base_config(), psets(p));
    cfg_seed.seed = 202405;
    cfg_seed.markov_random_seed = cfg_seed.seed;
    cfg_seed.markov_num_trials_per_initial_fault = 30;
    cfg_seed.chain_transition_probability_mode = 'bernoulli_full_event';
    cfg_seed.wind_power_curve_profile = 'paper_2_12_20';
    cfg_seed.record_probability_components_enable = true;
    cfg_seed.record_severity_components_enable = true;
    cfg_seed.record_candidate_probability_trace_enable = true;
    cfg_seed.record_wind_trip_probability_enable = true;
    cfg_seed.wind_trip_probability_record_only = true;
    cfg_seed.enable_wind_voltage_trip_sampling = true;
    cfg_seed.var_use_chain_weights = false;
    scenario_root_rel = fullfile('results', 'calibration', 'wind_speed_component_diagnostic_rerun', char(psets(p)));
    for s = 1:numel(scens)
        scenario_id = scens(s);
        scenario_dir = fullfile(root, scenario_root_rel, char(scenario_id));
        ensure_dir(scenario_dir);
        write_snapshot(root, scenario_id, psets(p), cfg_seed, scenario_dir);
        chain_path = fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv');
        if exist(chain_path, 'file') ~= 2
            opts = struct();
            opts.markov_num_trials_per_initial_fault = 30;
            opts.scenario_results_root = scenario_root_rel;
            opts.cfg_overrides = cfg_seed;
            opts.smoke_note = "wind-speed-only component diagnostic rerun; not formal benchmark; no local search";
            main_run_single_scenario(char(scenario_id), opts);
        end
        export_component_traces(root, scenario_dir, psets(p), scenario_id, cfg_seed);
    end
end
end

function write_snapshot(root, scenario_id, parameter_set_id, cfg, scenario_dir)
require_matpower(cfg);
base_mpc = build_case39_base(cfg);
base_load = sum(base_mpc.bus(:, 3));
scenario = get_scenario_by_id(char(scenario_id), cfg, base_load);
scenario.wind_power_curve_profile = 'paper_2_12_20';
[mpc, renewable_info] = apply_renewable_scenario(base_mpc, scenario);
[expected_wind_power, curve_detail] = compute_paper_wind_power_curve(scenario.wind_speed_mps, scenario.total_wind_capacity_mw, cfg);
actual_wind_pg = sum(mpc.gen(renewable_info.wind_gen_rows(:), 2));
T = table(string(scenario_id), string(parameter_set_id), scenario.wind_speed_mps, scenario.total_wind_capacity_mw, ...
    join(string(scenario.wind_buses), ":"), expected_wind_power, actual_wind_pg, string(curve_detail.curve_profile), ...
    cfg.markov_num_trials_per_initial_fault, cfg.markov_random_seed, ...
    "common_random_numbers_by_initial_branch_trial", string(cfg.chain_transition_probability_mode), ...
    string(cfg.paper_line_parameter_calibration_status), ...
    "diagnostic rerun only; P_WT record-only; not final benchmark", ...
    'VariableNames', {'scenario_id','parameter_set_id','wind_speed_mps','wind_capacity_total_mw','wind_buses', ...
    'expected_wind_power_total_mw','actual_wind_pg_total_mw_in_case','wind_power_curve_profile', ...
    'markov_trials_per_initial_fault','random_seed','random_seed_policy','chain_transition_probability_mode', ...
    'calibration_status','note'});
writetable(T, fullfile(scenario_dir, 'scenario_config_snapshot.csv'));
end

function export_component_traces(root, scenario_dir, parameter_set_id, scenario_id, cfg)
mat_path = fullfile(scenario_dir, 'chains', 'markov_chain_records.mat');
if exist(mat_path, 'file') == 2
    S = load(mat_path, 'chain_records');
    stage_tbl = flatten_stage_transition_probability_records_local(S.chain_records);
    cand_tbl = build_candidate_probability_trace_local(S.chain_records);
    wind_tbl = flatten_wind_trip_records(S.chain_records);
    writetable(stage_tbl, fullfile(scenario_dir, 'tables', 'stage_transition_probability_details.csv'));
    writetable(cand_tbl, fullfile(scenario_dir, 'tables', 'candidate_probability_trace.csv'));
    writetable(wind_tbl, fullfile(scenario_dir, 'tables', 'wind_trip_probability_trace.csv'));
end
build_line_component_trace(root, scenario_dir, parameter_set_id, scenario_id, cfg);
build_severity_component_trace(scenario_dir, parameter_set_id, scenario_id);
write_log(scenario_dir);
end

function build_line_component_trace(root, scenario_dir, parameter_set_id, scenario_id, cfg)
C = readtable(fullfile(scenario_dir, 'tables', 'candidate_probability_trace.csv'), 'TextType', 'string');
S = readtable(fullfile(scenario_dir, 'tables', 'stage_transition_probability_details.csv'), 'TextType', 'string');
M = readtable(fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv'), 'TextType', 'string');
base_mpc = build_case39_base(cfg);
if ~ismember("line_loading_pu", string(C.Properties.VariableNames)) && ismember("loading_pu", string(C.Properties.VariableNames))
    C.line_loading_pu = C.loading_pu;
end
rows = cell(height(C), 1);
for i = 1:height(C)
    branch = C.candidate_branch(i);
    [p_line, d] = compute_paper_line_outage_probability(C.line_loading_pu(i), base_mpc.branch(branch, :), cfg, ...
        'branch_index', branch, 'fallback_probability', C.candidate_probability(i));
    st = S(S.initial_branch == C.initial_branch(i) & S.trial_id == C.trial_id(i) & S.stage_id == C.stage_id(i), :);
    ch = M(M.initial_branch == C.initial_branch(i) & M.trial_id == C.trial_id(i), :);
    rows{i} = table(string(parameter_set_id), string(scenario_id), C.initial_branch(i), C.trial_id(i), C.stage_id(i), branch, ...
        C.line_loading_pu(i), C.line_loading_pu(i), d.L_rated_pu, d.L_max_pu, d.L_rated_factor, d.L_max_factor, ...
        d.P_flow, d.P_HF_D, d.P_HF_L, d.P_mis_r, d.P1, d.P2, d.P3, d.P_L, p_line, logical(C.selected(i)), C.random_u(i), ...
        pick(st, "stage_transition_probability"), pick(ch, "chain_transition_probability"), string(d.formula_status), ...
        string(d.parameter_status), string(d.calibration_status), string(d.distance_hidden_failure_status), ...
        "component trace recomputed from candidate loading and current parameter set; diagnostic only", ...
        'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','candidate_branch', ...
        'line_loading_pu','L','L_rated','L_max','L_rated_factor','L_max_factor','P_flow','P_HF_D','P_HF_L', ...
        'P_mis_r','P1','P2','P3','P_L','candidate_probability','selected','random_u','stage_transition_probability', ...
        'chain_transition_probability','formula_status','parameter_status','calibration_status','distance_hidden_failure_mode','note'});
end
writetable(vertcat(rows{:}), fullfile(scenario_dir, 'tables', 'line_probability_component_trace.csv'));
end

function build_severity_component_trace(scenario_dir, parameter_set_id, scenario_id)
Stages = readtable(fullfile(scenario_dir, 'tables', 'markov_chain_stages.csv'), 'TextType', 'string');
M = readtable(fullfile(scenario_dir, 'tables', 'markov_chain_summary.csv'), 'TextType', 'string');
rows = cell(height(Stages), 1);
for i = 1:height(Stages)
    ch = M(M.initial_branch == Stages.initial_branch(i) & M.trial_id == Stages.trial_id(i), :);
    rows{i} = table(string(parameter_set_id), string(scenario_id), Stages.initial_branch(i), Stages.trial_id(i), Stages.stage_id(i), ...
        pick(ch, "basic_LLR"), pick(ch, "basic_LFOR"), pick(ch, "basic_NVOR"), pick(ch, "basic_CRI"), ...
        pick(ch, "total_load_shed_mw"), pick(ch, "total_load_shed_frac"), Stages.max_line_loading_pu(i), Stages.max_voltage_deviation_pu(i), ...
        Stages.num_overloaded_lines(i), Stages.num_voltage_violations(i), "chain_basic_and_stage_operating_state", ...
        "counts_from_markov_chain_stages", "Diagnostic severity component trace; not formal VaR.", ...
        'VariableNames', {'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','basic_LLR','basic_LFOR', ...
        'basic_NVOR','basic_CRI','total_load_shed_mw','total_load_shed_frac','max_line_loading_pu', ...
        'max_voltage_deviation_pu','overloaded_branch_count','voltage_violation_bus_count','severity_formula_status', ...
        'normalization_status','note'});
end
writetable(vertcat(rows{:}), fullfile(scenario_dir, 'tables', 'severity_component_trace.csv'));
end

function v = pick(T, name)
if isempty(T) || ~ismember(name, string(T.Properties.VariableNames)), v = NaN; else, v = T.(char(name))(1); end
end

function tbl = flatten_stage_transition_probability_records_local(chain_records)
rows = {};
for i = 1:numel(chain_records)
    c = chain_records(i);
    for s = 1:numel(c.stage_records)
        st = c.stage_records(s);
        if ~isfield(st, 'transition_probability_detail'), continue; end
        d = st.transition_probability_detail;
        rows{end+1,1} = table(c.initial_branch, c.trial_id, st.stage_id, string(get_stage(st,'terminated_reason',"")), ...
            string(d.stage_probability_mode), d.candidate_count, d.selected_candidate_count, d.unselected_candidate_count, ...
            d.selected_probability_product, d.unselected_probability_product, d.stage_transition_probability, string(d.probability_status), ...
            logical(get_detail(d,'terminal_stage_flag',false)), logical(get_detail(d,'should_multiply_candidate_complements',true)), ...
            string(get_detail(d,'missing_reason',"")), string(get_detail(d,'selected_branch_ids',"")), ...
            string(get_detail(d,'random_u_selected',"")), string(get_detail(d,'candidate_probability_basis',"")), string(d.note), ...
            'VariableNames', {'initial_branch','trial_id','stage_id','terminated_reason','stage_probability_mode','candidate_count', ...
            'selected_candidate_count','unselected_candidate_count','selected_probability_product','unselected_probability_product', ...
            'stage_transition_probability','probability_status','terminal_stage_flag','should_multiply_candidate_complements', ...
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
candidate_trace = candidate_trace(:, {'initial_branch','trial_id','stage_id','candidate_branch','loading_pu', ...
    'candidate_probability','prob_model','engineering_probability','paper_formula_probability','paper_formula_status', ...
    'paper_formula_missing_parameters','paper_formula_used_fallback','random_u','selected'});
end

function x = get_stage(s, name, default_value)
if isfield(s, name), x = s.(name); else, x = default_value; end
end

function x = get_detail(s, name, default_value)
if isstruct(s) && isfield(s, name), x = s.(name); else, x = default_value; end
end

function write_log(scenario_dir)
ensure_dir(fullfile(scenario_dir, 'logs'));
writelines(["wind-speed-only component diagnostic rerun"; "No local search, no parameter refinement, no final_summary."], ...
    fullfile(scenario_dir, 'logs', 'scenario_run_log.txt'));
end

function ensure_dir(path)
if exist(path, 'dir') ~= 7, mkdir(path); end
end
