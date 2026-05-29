function [unified_detail, component_tables] = record_unified_state_probability(stage_context, cfg)
%RECORD_UNIFIED_STATE_PROBABILITY Record same-stage P_line/P_wt/P_ge/P_total diagnostics.
candidate_table = get_field(stage_context, 'candidate_table', table());
wind_trip_table = get_field(stage_context, 'wind_trip_table', table());
generator_trip_table = get_field(stage_context, 'generator_trip_table', table());

[p_line, line_status, line_probability_table] = extract_line_probability(candidate_table, stage_context);
[p_wt, wind_detail] = compute_wind_state_probability(wind_trip_table, cfg);
[p_ge, generator_detail] = compute_generator_state_probability(generator_trip_table, cfg);

cfg_comp = cfg;
cfg_comp.composite_probability_missing_policy = get_cfg(cfg, ...
    'unified_composite_probability_missing_policy', get_cfg(cfg, 'composite_probability_missing_policy', 'component_nan'));
line_detail = struct('P_line_Ek', p_line, 'status', line_status);
[p_total, composite_detail] = compute_composite_state_probability(line_detail, wind_detail, generator_detail, cfg_comp);

unified_detail = struct();
unified_detail.initial_branch = get_field(stage_context, 'initial_branch', NaN);
unified_detail.trial_id = get_field(stage_context, 'trial_id', NaN);
unified_detail.stage_id = get_field(stage_context, 'stage_id', NaN);
unified_detail.line_parameter_set_id = string(get_cfg(cfg, 'unified_line_probability_parameter_set', ...
    get_cfg(cfg, 'paper_line_parameter_set_id', 'unknown')));
unified_detail.wind_parameter_set_id = string(get_cfg(cfg, 'unified_wind_probability_parameter_set', ...
    get_cfg(cfg, 'wind_trip_parameter_set_id', 'unknown')));
unified_detail.generator_parameter_set_id = string(get_cfg(cfg, 'unified_generator_probability_parameter_set', ...
    get_cfg(cfg, 'generator_trip_parameter_set_id', 'unknown')));
unified_detail.P_line_Ek = p_line;
unified_detail.P_wt_Ek = p_wt;
unified_detail.P_ge_Ek = p_ge;
unified_detail.P_total_Ek = p_total;
unified_detail.P_line_status = string(line_status);
unified_detail.P_wt_status = string(wind_detail.status);
unified_detail.P_ge_status = string(generator_detail.status);
unified_detail.composite_status = string(composite_detail.composite_status);
unified_detail.missing_components = string(composite_detail.missing_components);
unified_detail.calibration_status = string(composite_detail.calibration_status);
unified_detail.diagnostic_only = true;
unified_detail.note = "Unified same-run diagnostic only; it does not affect Markov sampling, generator/wind states, or formal paper_formula.";

component_tables = struct();
component_tables.wind_trip_table = wind_trip_table;
component_tables.generator_trip_table = generator_trip_table;
component_tables.line_probability_table = line_probability_table;
end

function [p_line, status, line_probability_table] = extract_line_probability(candidate_table, stage_context)
line_probability_table = empty_line_probability_table();
if isempty(candidate_table) || ~istable(candidate_table) || height(candidate_table) == 0
    p_line = get_field(stage_context, 'line_cumulative_probability', 1);
    status = "no_candidate_lines_transition_probability_one";
    return;
end

p = candidate_table.outage_probability;
prob_source = repmat("outage_probability", height(candidate_table), 1);
if ismember('paper_formula_probability', candidate_table.Properties.VariableNames)
    paper_p = candidate_table.paper_formula_probability;
    use_paper = ~isnan(paper_p);
    p(use_paper) = paper_p(use_paper);
    prob_source(use_paper) = "paper_formula_probability";
end
p = min(max(p, 0), 1);
selected = logical(candidate_table.trip_selected);
transition_probability = prod(p(selected)) * prod(1 - p(~selected));
if isempty(transition_probability) || isnan(transition_probability)
    transition_probability = NaN;
end
cumulative_before = get_field(stage_context, 'line_cumulative_probability_before_stage', NaN);
if isnan(cumulative_before)
    p_line = transition_probability;
else
    p_line = cumulative_before * transition_probability;
end
status = "computed_from_candidate_table";

line_probability_table = table(candidate_table.branch_index, candidate_table.from_bus, candidate_table.to_bus, ...
    candidate_table.loading_pu, candidate_table.outage_probability, p, prob_source, selected, ...
    repmat(transition_probability, height(candidate_table), 1), repmat(p_line, height(candidate_table), 1), ...
    'VariableNames', {'candidate_branch', 'from_bus', 'to_bus', 'line_loading_pu', ...
    'engineering_or_main_probability', 'diagnostic_line_probability', 'probability_source', ...
    'trip_selected', 'stage_transition_probability', 'stage_cumulative_P_line_Ek'});
end

function tbl = empty_line_probability_table()
tbl = table([], [], [], [], [], [], strings(0, 1), false(0, 1), [], [], ...
    'VariableNames', {'candidate_branch', 'from_bus', 'to_bus', 'line_loading_pu', ...
    'engineering_or_main_probability', 'diagnostic_line_probability', 'probability_source', ...
    'trip_selected', 'stage_transition_probability', 'stage_cumulative_P_line_Ek'});
end

function value = get_field(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end

function value = get_cfg(cfg, name, default_value)
if isfield(cfg, name)
    value = cfg.(name);
else
    value = default_value;
end
end
