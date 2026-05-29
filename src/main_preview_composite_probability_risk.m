function main_preview_composite_probability_risk()
%MAIN_PREVIEW_COMPOSITE_PROBABILITY_RISK Offline diagnostic weighted-risk preview.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
composite = readtable(fullfile(project_root, 'results', 'composite', ...
    'composite_state_probability_diagnostic.csv'), 'TextType', 'string');
sets = unique(composite.line_parameter_set_id, 'stable');
rows = {};
for i = 1:numel(sets)
    set_id = sets(i);
    severity = build_stage_severity(project_root, set_id);
    comp = composite(composite.line_parameter_set_id == set_id, :);
    joined = innerjoin(comp, severity, 'Keys', {'initial_branch', 'trial_id', 'stage_id'});
    metrics = ["LLR", "LFOR", "NVOR", "CRI"];
    columns = ["severity_LLR", "severity_LFOR", "severity_NVOR", "severity_CRI"];
    for m = 1:numel(metrics)
        sev = joined.(columns(m));
        risk_line = sum(joined.P_line_Ek .* sev, 'omitnan');
        risk_comp = sum(joined.P_total_Ek .* sev, 'omitnan');
        rel = NaN;
        if risk_line ~= 0
            rel = (risk_comp - risk_line) / abs(risk_line);
        end
        rows{end+1,1} = table(set_id, metrics(m), risk_line, risk_comp, ...
            risk_comp - risk_line, rel, height(joined), sum(~isnan(joined.P_total_Ek) & ~isnan(sev)), ...
            "Offline diagnostic only; not VaR and not a formal paper_formula replacement.", ...
            'VariableNames', {'line_parameter_set_id', 'metric_name', 'risk_line_only', ...
            'risk_composite_diag', 'delta_risk', 'relative_delta', 'stage_count', ...
            'valid_stage_count', 'note'}); %#ok<AGROW>
    end
end
preview = vertcat(rows{:});
writetable(preview, fullfile(project_root, 'results', 'composite', 'composite_probability_risk_preview.csv'));
fprintf('composite probability risk preview written.\n');
end

function severity = build_stage_severity(project_root, parameter_set_id)
case_dir = fullfile(project_root, 'results', 'outage', 'line_probability_parameter_smoke', char(parameter_set_id));
loaded = load(fullfile(case_dir, 'chains', 'markov_chain_records.mat'));
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
[line_flow, bus_voltage, stage_prob] = build_markov_paper_detail_tables(loaded.chain_records, base_mpc, ...
    cfg, loaded.scenario, renewable_info, initial_probability_table);
rows = {};
for i = 1:height(stage_prob)
    key = stage_prob(i, {'initial_branch', 'trial_id', 'stage_id'});
    lmask = line_flow.initial_branch == key.initial_branch & line_flow.trial_id == key.trial_id & line_flow.stage_id == key.stage_id;
    bmask = bus_voltage.initial_branch == key.initial_branch & bus_voltage.trial_id == key.trial_id & bus_voltage.stage_id == key.stage_id;
    lfor = sum(line_flow.line_severity_component(lmask), 'omitnan');
    nvor = sum(bus_voltage.voltage_severity_component(bmask), 'omitnan');
    llr = stage_prob.stage_load_shed_frac(i) * 100;
    cri = calc_cri(llr, lfor, nvor, cfg.risk_weights);
    rows{end+1,1} = table(key.initial_branch, key.trial_id, key.stage_id, llr, lfor, nvor, cri, ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', ...
        'severity_LLR', 'severity_LFOR', 'severity_NVOR', 'severity_CRI'}); %#ok<AGROW>
end
severity = vertcat(rows{:});
end
