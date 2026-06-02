function main_diagnose_wind_speed_tail_probability_severity_drivers()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
Branch = readtable(fullfile(out_root, 'wind_speed_tail_branch_delta_11_28_vs_12_00.csv'), 'TextType', 'string');
Line = readtable(fullfile(out_root, 'wind_speed_line_probability_component_delta.csv'), 'TextType', 'string');
Severity = readtable(fullfile(out_root, 'wind_speed_severity_component_delta.csv'), 'TextType', 'string');
Candidate = readtable(fullfile(out_root, 'wind_speed_tail_candidate_probability_delta.csv'), 'TextType', 'string');
rows = {};
for i = 1:height(Branch)
    ps = Branch.parameter_set_id(i);
    metric = Branch.metric_name(i);
    ib = Branch.initial_branch(i);
    line_rows = Line(Line.parameter_set_id == ps & Line.candidate_branch == ib, :);
    sev_rows = Severity(Severity.parameter_set_id == ps & Severity.initial_branch == ib, :);
    cand_rows = Candidate(Candidate.parameter_set_id == ps & Candidate.metric_name == metric & Candidate.candidate_branch == ib, :);
    d_cand = mean_or_nan(cand_rows, "delta_probability_12_minus_11");
    d_line_loading = mean_or_nan(line_rows, "delta_line_loading");
    prob_driver = mode_or_missing(line_rows, "probability_driver");
    sev_driver = mode_or_missing(sev_rows, "severity_driver");
    dominant = choose_dominant(Branch.likely_driver(i), prob_driver, sev_driver);
    rows{end+1,1} = table(ps, metric, ib, Branch.tail_count_11_28(i), Branch.tail_count_12_00(i), ...
        Branch.delta_tail_risk_mean(i), Branch.delta_chain_probability(i), Branch.delta_severity(i), d_cand, d_line_loading, ...
        prob_driver, sev_driver, dominant, recommended_fix(dominant), ...
        "Tail probability/severity driver attribution from existing after-curve-fix outputs; diagnostic only.", ...
        'VariableNames', {'parameter_set_id','metric_name','initial_branch','tail_count_11_28','tail_count_12_00', ...
        'delta_tail_risk_mean','delta_chain_probability','delta_severity','delta_candidate_probability','delta_line_loading', ...
        'probability_component_driver','severity_component_driver','dominant_tail_driver','recommended_fix','note'}); %#ok<AGROW>
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_tail_probability_severity_driver_summary.csv'));
end

function v = mean_or_nan(T, name)
if isempty(T) || ~ismember(name, string(T.Properties.VariableNames))
    v = NaN;
else
    v = mean(T.(char(name)), 'omitnan');
end
end

function s = mode_or_missing(T, name)
if isempty(T) || ~ismember(name, string(T.Properties.VariableNames))
    s = "missing";
else
    s = string(mode(categorical(string(T.(char(name))))));
end
end

function d = choose_dominant(branch_driver, prob_driver, sev_driver)
if prob_driver == "component_fields_missing"
    d = "insufficient_component_fields";
elseif prob_driver == "loading_driven" || prob_driver == "hidden_failure_driven" || prob_driver == "base_probability_driven"
    d = "line_probability_model";
elseif sev_driver ~= "no_severity_increase" && sev_driver ~= "missing"
    d = "severity_model";
elseif contains(string(branch_driver), "composition")
    d = "initial_branch_tail_composition";
elseif contains(string(branch_driver), "stochastic")
    d = "stochastic_tail_sample";
else
    d = "mixed_probability_and_severity";
end
end

function s = recommended_fix(driver)
switch string(driver)
    case "line_probability_model"
        s = "inspect_line_outage_probability_formula";
    case "severity_model"
        s = "inspect_severity_formula";
    case "insufficient_component_fields"
        s = "run_wind_speed_only_more_trials_with_component_logging";
    case {"initial_branch_tail_composition","stochastic_tail_sample"}
        s = "run_wind_speed_only_more_trials_with_component_logging";
    otherwise
        s = "keep_diagnostic_and_review_probability_severity_basis";
end
end
