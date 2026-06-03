function main_run_fig4_2_diagnostic_reproduction()
%MAIN_RUN_FIG4_2_DIAGNOSTIC_REPRODUCTION Build Fig.4-2 diagnostic runs.
% This script runs only the two small diagnostic scenarios requested for a
% public-information-constrained reproduction of paper Fig.4-2. It does not
% run local search, all_full, final_summary, OLS benchmark, or any parameter
% refinement.

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'figures', 'fig4_2_diagnostic_reproduction');
raw_root_rel = fullfile('results', 'figures', 'fig4_2_diagnostic_reproduction', '_raw');
ensure_dir(out_root);
log_path = fullfile(out_root, 'fig4_2_diagnostic_reproduction_run_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Fig.4-2 diagnostic reproduction run log\n');
fprintf(fid, 'No local search, parameter tuning, all_full, final_summary, OLS benchmark, or wind/generator actual trip transition is run.\n');

cfg_seed = load_benchmark_calibration_parameter_set(base_config(), 'benchmark_calibrated_seed');
cfg_seed.chain_transition_probability_mode = 'bernoulli_full_event';
cfg_seed.wind_power_curve_profile = 'paper_2_12_20';
cfg_seed.line_outage_flow_probability_mode = 'paper_piecewise_constant_below_rated';
cfg_seed.hidden_failure_loading_probability_mode = 'paper_piecewise_constant_below_Lmax';
cfg_seed.PL_event_aggregation_mode = 'paper_simple_sum';
cfg_seed.severity_formula_mode = 'paper_confirmed_exponential_sum';
cfg_seed.record_probability_components_enable = true;
cfg_seed.record_severity_components_enable = true;
cfg_seed.record_severity_vector_trace_enable = true;
cfg_seed.markov_num_trials_per_initial_fault = 20;
cfg_seed.markov_random_seed = cfg_seed.seed;
cfg_seed.enable_wind_voltage_trip_sampling = false;
cfg_seed.wind_trip_state_probability_enable = false;
cfg_seed.generator_state_probability_enable = false;

fprintf(fid, 'Requested nominal trials per initial fault = 30; using 20 to control desktop diagnostic runtime, not below 10.\n');
fprintf(fid, 'Parameter set = benchmark_calibrated_seed; status = benchmark_calibrated_not_original_paper.\n');

scenario_map = [ ...
    struct('source_id', 'no_renewable_base', 'target_id', 'fig4_2_no_renewable', ...
    'label', 'No renewable access', 'renewable_enabled', false, 'renewable_buses', "", 'renewable_capacity_total_mw', 0); ...
    struct('source_id', 'distributed_30_39', 'target_id', 'fig4_2_distributed_renewable_3000MW', ...
    'label', 'Distributed renewable 3000 MW at buses 30-39', 'renewable_enabled', true, 'renewable_buses', "30:39", 'renewable_capacity_total_mw', 3000) ...
    ];

for k = 1:numel(scenario_map)
    item = scenario_map(k);
    fprintf(fid, 'RUN source_scenario=%s target_scenario=%s trials=%d\n', item.source_id, item.target_id, cfg_seed.markov_num_trials_per_initial_fault);
    opts = struct();
    opts.markov_num_trials_per_initial_fault = cfg_seed.markov_num_trials_per_initial_fault;
    opts.scenario_results_root = raw_root_rel;
    opts.cfg_overrides = cfg_seed;
    opts.smoke_note = "Fig.4-2 diagnostic reproduction under public information constraints; not strict original reproduction.";
    result = main_run_single_scenario(item.source_id, opts);
    fprintf(fid, 'source_scenario=%s run_status=%s\n', item.source_id, string(result.run_status));
    raw_dir = fullfile(project_root, raw_root_rel, item.source_id);
    target_dir = fullfile(out_root, item.target_id);
    ensure_dir(target_dir);
    write_scenario_config_snapshot(target_dir, item, cfg_seed);
    copy_required_tables(raw_dir, target_dir);
    build_risk_samples_for_density(target_dir, item);
    build_severity_vector_trace(raw_dir, target_dir);
end

fprintf(fid, 'DONE\n');
fprintf('Wrote %s\n', log_path);
end

function write_scenario_config_snapshot(target_dir, item, cfg)
scenario_id = string(item.target_id);
renewable_enabled = logical(item.renewable_enabled);
renewable_buses = string(item.renewable_buses);
renewable_capacity_total_mw = item.renewable_capacity_total_mw;
wind_power_curve_profile = string(cfg.wind_power_curve_profile);
severity_formula_mode = string(cfg.severity_formula_mode);
chain_transition_probability_mode = string(cfg.chain_transition_probability_mode);
PL_event_aggregation_mode = string(get_cfg(cfg, 'PL_event_aggregation_mode', 'paper_simple_sum'));
formula_status = "public_formula_confirmed_with_benchmark_calibrated_statistics";
reproduction_status_note = "diagnostic_reproduction_not_strict_paper_original";
T = table(scenario_id, renewable_enabled, renewable_buses, renewable_capacity_total_mw, ...
    wind_power_curve_profile, severity_formula_mode, chain_transition_probability_mode, ...
    PL_event_aggregation_mode, formula_status, reproduction_status_note);
writetable(T, fullfile(target_dir, 'scenario_config_snapshot.csv'));
end

function copy_required_tables(raw_dir, target_dir)
tables_dir = fullfile(raw_dir, 'tables');
copy_if_exists(fullfile(tables_dir, 'markov_chain_summary.csv'), fullfile(target_dir, 'markov_chain_summary.csv'));
copy_if_exists(fullfile(tables_dir, 'markov_chain_stages.csv'), fullfile(target_dir, 'markov_chain_stages.csv'));
copy_if_exists(fullfile(tables_dir, 'markov_stage_probability_details.csv'), fullfile(target_dir, 'markov_stage_probability_details.csv'));
copy_if_exists(fullfile(tables_dir, 'markov_line_flow_details.csv'), fullfile(target_dir, 'markov_line_flow_details.csv'));
copy_if_exists(fullfile(tables_dir, 'markov_bus_voltage_details.csv'), fullfile(target_dir, 'markov_bus_voltage_details.csv'));
copy_if_exists(fullfile(raw_dir, 'logs', 'scenario_run_log.txt'), fullfile(target_dir, 'scenario_run_log.txt'));
end

function build_risk_samples_for_density(target_dir, item)
chain_path = fullfile(target_dir, 'markov_chain_summary.csv');
T = readtable(chain_path, 'TextType', 'string', 'Delimiter', ',');
n = height(T);
scenario_id = repmat(string(item.target_id), n, 1);
scenario_label = repmat(string(item.label), n, 1);
initial_line_probability = T.initial_line_probability;
chain_transition_probability = T.chain_transition_probability;
prob = initial_line_probability .* chain_transition_probability;
R_LLR = prob .* T.basic_LLR;
R_LFOR = prob .* T.basic_LFOR;
R_NVOR = prob .* T.basic_NVOR;
R_CRI_reference = prob .* T.basic_CRI;
R_LLR_display = R_LLR ./ 1e-4;
R_LFOR_display = R_LFOR ./ 1e-4;
R_NVOR_display = R_NVOR ./ 1e-4;
R_CRI_display_reference = 0.6 .* R_LLR_display + 0.2 .* R_LFOR_display + 0.2 .* R_NVOR_display;
severity_formula_mode = repmat("paper_confirmed_exponential_sum", n, 1);
risk_sample_status = repmat("diagnostic_public_information_constraints", n, 1);
note = repmat("Risk sample = initial_line_probability * full-event chain_transition_probability * chain severity; display values divided by 1e-4.", n, 1);
R = table(scenario_id, scenario_label, T.initial_branch, T.trial_id, R_LLR, R_LFOR, R_NVOR, ...
    R_CRI_reference, R_LLR_display, R_LFOR_display, R_NVOR_display, R_CRI_display_reference, ...
    initial_line_probability, chain_transition_probability, severity_formula_mode, risk_sample_status, note, ...
    'VariableNames', {'scenario_id','scenario_label','initial_branch','trial_id','R_LLR','R_LFOR','R_NVOR', ...
    'R_CRI_reference','R_LLR_display','R_LFOR_display','R_NVOR_display','R_CRI_display_reference', ...
    'initial_line_probability','chain_transition_probability','severity_formula_mode','risk_sample_status','note'});
writetable(R, fullfile(target_dir, 'risk_samples_for_density.csv'));
end

function build_severity_vector_trace(raw_dir, target_dir)
stage_path = fullfile(raw_dir, 'tables', 'markov_stage_probability_details.csv');
line_path = fullfile(raw_dir, 'tables', 'markov_line_flow_details.csv');
bus_path = fullfile(raw_dir, 'tables', 'markov_bus_voltage_details.csv');
if exist(stage_path, 'file') ~= 2 || exist(line_path, 'file') ~= 2 || exist(bus_path, 'file') ~= 2
    writetable(table(), fullfile(target_dir, 'severity_vector_trace.csv'));
    return;
end
stage = readtable(stage_path, 'TextType', 'string', 'Delimiter', ',');
line = readtable(line_path, 'TextType', 'string', 'Delimiter', ',');
bus = readtable(bus_path, 'TextType', 'string', 'Delimiter', ',');
keys = unique(stage(:, {'initial_branch','trial_id','stage_id'}), 'rows');
rows = cell(height(keys), 1);
for i = 1:height(keys)
    k = keys(i, :);
    st = stage(stage.initial_branch == k.initial_branch & stage.trial_id == k.trial_id & stage.stage_id == k.stage_id, :);
    if height(st) > 1, st = st(1, :); end
    lm = line.initial_branch == k.initial_branch & line.trial_id == k.trial_id & line.stage_id == k.stage_id;
    bm = bus.initial_branch == k.initial_branch & bus.trial_id == k.trial_id & bus.stage_id == k.stage_id;
    lvec = line.P_li_pu(lm);
    vvec = bus.voltage_pu(bm);
    LLR_paper = st.stage_load_shed_mw / st.base_load_mw;
    LFOR_paper = sum((exp(max(lvec(:) - 1, 0)) - 1) ./ (exp(1) - 1), 'omitnan');
    dev = max([0.9 - vvec(:), vvec(:) - 1.1, zeros(numel(vvec), 1)], [], 2);
    NVOR_paper = sum((exp(dev) - 1) ./ (exp(1) - 1), 'omitnan');
    branch_loading_pu_vector = join(string(lvec(:).'), ';');
    bus_voltage_pu_vector = join(string(vvec(:).'), ';');
    overloaded_branch_count = sum(max(lvec(:) - 1, 0) > 0, 'omitnan');
    voltage_violation_bus_count = sum(dev > 0, 'omitnan');
    severity_formula_mode = "paper_confirmed_exponential_sum";
    normalization_status = "diagnostic_stage_vector_reconstruction";
    rows{i} = table(k.initial_branch, k.trial_id, k.stage_id, LLR_paper, LFOR_paper, NVOR_paper, ...
        branch_loading_pu_vector, bus_voltage_pu_vector, st.stage_load_shed_mw, st.base_load_mw, ...
        overloaded_branch_count, voltage_violation_bus_count, severity_formula_mode, normalization_status, ...
        'VariableNames', {'initial_branch','trial_id','stage_id','LLR_paper','LFOR_paper','NVOR_paper', ...
        'branch_loading_pu_vector','bus_voltage_pu_vector','total_load_shed_mw','base_load_mw', ...
        'overloaded_branch_count','voltage_violation_bus_count','severity_formula_mode','normalization_status'});
end
V = vertcat(rows{:});
writetable(V, fullfile(target_dir, 'severity_vector_trace.csv'));
end

function copy_if_exists(src, dst)
if exist(src, 'file') == 2
    copyfile(src, dst);
end
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end

function ensure_dir(path)
if exist(path, 'dir') ~= 7
    mkdir(path);
end
end
