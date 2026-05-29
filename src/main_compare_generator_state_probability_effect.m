function main_compare_generator_state_probability_effect()
%MAIN_COMPARE_GENERATOR_STATE_PROBABILITY_EFFECT Offline diagnostic P_line * P_ge comparison.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

case_dir = fullfile(project_root, 'results', 'generator', 'generator_state_probability_diagnostic_smoke', ...
    'diagnostic_voltage_frequency_probability');
records_path = fullfile(case_dir, 'markov_chain_records.mat');
if exist(records_path, 'file') ~= 2
    error('Missing diagnostic chain records: %s', records_path);
end
loaded = load(records_path, 'chain_records', 'cfg', 'scenario', 'renewable_info', 'base_mpc');
cfg = loaded.cfg;
require_matpower(cfg);
cfg.initial_fault_probability_mode = 'paper_table_4_1';
cfg.initial_fault_probability_file = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
initial_probability_table = load_initial_line_probabilities(cfg, loaded.base_mpc);
initial_probability_table = initial_probability_table(ismember(initial_probability_table.branch_index, 1:5), :);

[line_flow_detail_table, bus_voltage_detail_table, stage_probability_table] = ...
    build_markov_paper_detail_tables(loaded.chain_records, loaded.base_mpc, cfg, loaded.scenario, ...
    loaded.renewable_info, initial_probability_table);
generator_state_table = readtable(fullfile(case_dir, 'generator_state_probability_stage_details.csv'), 'TextType', 'string');
comparison = build_comparison(stage_probability_table, line_flow_detail_table, bus_voltage_detail_table, generator_state_table, cfg);
summary = build_summary(comparison);

out_dir = fullfile(project_root, 'results', 'generator');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
writetable(comparison, fullfile(out_dir, 'generator_state_probability_effect_comparison.csv'));
writetable(summary, fullfile(out_dir, 'generator_state_probability_effect_summary.csv'));
fprintf('generator state probability effect comparison written.\n');
end

function comparison = build_comparison(stage_probability_table, line_flow_detail_table, bus_voltage_detail_table, generator_state_table, cfg)
rows = {};
for i = 1:height(stage_probability_table)
    key = stage_probability_table(i, {'initial_branch', 'trial_id', 'stage_id'});
    gmask = generator_state_table.initial_branch == key.initial_branch & ...
        generator_state_table.trial_id == key.trial_id & generator_state_table.stage_id == key.stage_id;
    if any(gmask)
        p_ge = generator_state_table.p_ge_Ek(find(gmask, 1));
    else
        p_ge = NaN;
    end
    p_line = stage_probability_table.stage_cumulative_probability(i);
    [lfor, nvor] = stage_lfor_nvor(line_flow_detail_table, bus_voltage_detail_table, key);
    llr = stage_probability_table.stage_load_shed_frac(i) * 100;
    if isnan(lfor) || isnan(nvor)
        cri = NaN;
    else
        cri = calc_cri(llr, lfor, nvor, cfg.risk_weights);
    end
    rows{end+1,1} = table(key.initial_branch, key.trial_id, key.stage_id, ...
        p_line, p_ge, p_line * p_ge, llr, lfor, nvor, cri, p_line - p_line * p_ge, ...
        "diagnostic only; P_ge not integrated into formal paper_formula", ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'P_line_Ek', ...
        'P_ge_Ek', 'P_line_times_P_ge', 'severity_LLR', 'severity_LFOR', ...
        'severity_NVOR', 'severity_CRI', 'delta_probability', 'note'}); %#ok<AGROW>
end
comparison = vertcat(rows{:});
end

function [lfor, nvor] = stage_lfor_nvor(line_flow_detail_table, bus_voltage_detail_table, key)
lmask = line_flow_detail_table.initial_branch == key.initial_branch & ...
    line_flow_detail_table.trial_id == key.trial_id & line_flow_detail_table.stage_id == key.stage_id;
bmask = bus_voltage_detail_table.initial_branch == key.initial_branch & ...
    bus_voltage_detail_table.trial_id == key.trial_id & bus_voltage_detail_table.stage_id == key.stage_id;
if any(lmask)
    lfor = sum(line_flow_detail_table.line_severity_component(lmask));
else
    lfor = NaN;
end
if any(bmask)
    nvor = sum(bus_voltage_detail_table.voltage_severity_component(bmask));
else
    nvor = NaN;
end
end

function summary = build_summary(comparison)
pge = comparison.P_ge_Ek;
delta = comparison.delta_probability;
summary = table(height(comparison), mean(pge, 'omitnan'), min(pge, [], 'omitnan'), ...
    mean(delta, 'omitnan'), max(delta, [], 'omitnan'), sum(delta > 0), ...
    "Offline diagnostic only; no formal paper_formula output was replaced.", ...
    'VariableNames', {'stage_count', 'mean_P_ge_Ek', 'min_P_ge_Ek', ...
    'mean_probability_reduction', 'max_probability_reduction', ...
    'num_stages_affected', 'note'});
end
