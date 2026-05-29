function main_build_composite_state_probability_diagnostic()
%MAIN_BUILD_COMPOSITE_STATE_PROBABILITY_DIAGNOSTIC Build offline P_line/P_wt/P_ge/P_total table.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_dir = fullfile(project_root, 'results', 'composite');
ensure_dir(out_dir);

cfg0 = base_config();
cfg0.composite_probability_missing_policy = 'component_nan';
line_sets = ["table41_P_L0_only", "low_hidden_failure_diagnostic", "medium_hidden_failure_diagnostic"];
wind_set = "diagnostic_linear_voltage_probability";
gen_set = "diagnostic_voltage_frequency_probability";
wind_table = readtable(fullfile(project_root, 'results', 'renewable', 'wind_state_probability_diagnostic_smoke', ...
    char(wind_set), 'wind_state_probability_stage_details.csv'), 'TextType', 'string');
gen_table = readtable(fullfile(project_root, 'results', 'generator', 'generator_state_probability_diagnostic_smoke', ...
    char(gen_set), 'generator_state_probability_stage_details.csv'), 'TextType', 'string');

rows = {};
for ls = line_sets
    stage_prob = build_line_stage_probability(project_root, ls);
    for i = 1:height(stage_prob)
        key = stage_prob(i, {'initial_branch', 'trial_id', 'stage_id'});
        wrow = select_matching(wind_table, key);
        grow = select_matching(gen_table, key);
        line_detail = table(stage_prob.stage_cumulative_probability(i), string(stage_prob.probability_source(i)), ...
            'VariableNames', {'P_line_Ek', 'status'});
        [p_total, d] = compute_composite_state_probability(line_detail, wrow, grow, cfg0);
        rows{end+1,1} = table(key.initial_branch, key.trial_id, key.stage_id, ...
            string(ls), wind_set, gen_set, d.P_line_Ek, d.P_wt_Ek, d.P_ge_Ek, p_total, ...
            string(d.line_status), string(d.wind_status), string(d.generator_status), ...
            string(d.missing_components), string(d.composite_status), string(d.calibration_status), string(d.note), ...
            'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
            'line_parameter_set_id', 'wind_parameter_set_id', 'generator_parameter_set_id', ...
            'P_line_Ek', 'P_wt_Ek', 'P_ge_Ek', 'P_total_Ek', ...
            'P_line_status', 'P_wt_status', 'P_ge_status', 'missing_components', ...
            'composite_status', 'calibration_status', 'note'}); %#ok<AGROW>
    end
end
composite = vertcat(rows{:});
writetable(composite, fullfile(out_dir, 'composite_state_probability_diagnostic.csv'));
fprintf('composite state probability diagnostic written.\n');
end

function stage_prob = build_line_stage_probability(project_root, parameter_set_id)
case_dir = fullfile(project_root, 'results', 'outage', 'line_probability_parameter_smoke', char(parameter_set_id));
records_path = fullfile(case_dir, 'chains', 'markov_chain_records.mat');
if exist(records_path, 'file') ~= 2
    error('Missing line probability chain records: %s', records_path);
end
loaded = load(records_path);
cfg = loaded.cfg;
require_matpower(cfg);
if isfield(loaded, 'base_mpc')
    base_mpc = loaded.base_mpc;
else
    base0 = build_case39_base(cfg);
    [base_mpc, renewable_info] = apply_renewable_scenario(base0, loaded.scenario);
end
if isfield(loaded, 'renewable_info')
    renewable_info = loaded.renewable_info;
elseif ~exist('renewable_info', 'var')
    base0 = build_case39_base(cfg);
    [base_mpc, renewable_info] = apply_renewable_scenario(base0, loaded.scenario);
end
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
initial_probability_table = load_initial_line_probabilities(cfg, base_mpc);
initial_probability_table = initial_probability_table(ismember(initial_probability_table.branch_index, 1:5), :);
[~, ~, stage_prob] = build_markov_paper_detail_tables(loaded.chain_records, base_mpc, cfg, ...
    loaded.scenario, renewable_info, initial_probability_table);
end

function row = select_matching(tbl, key)
mask = tbl.initial_branch == key.initial_branch & tbl.trial_id == key.trial_id & tbl.stage_id == key.stage_id;
if any(mask)
    row = tbl(find(mask, 1), :);
else
    row = table(NaN, "missing_stage", 'VariableNames', {'P_wt_Ek', 'status'});
end
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
