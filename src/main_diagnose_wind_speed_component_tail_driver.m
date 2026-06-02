function main_diagnose_wind_speed_component_tail_driver()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
V = readtable(fullfile(out_root, 'wind_speed_component_diagnostic_var_metrics.csv'), 'TextType', 'string');
P = readtable(fullfile(out_root, 'wind_speed_component_probability_delta.csv'), 'TextType', 'string');
S = readtable(fullfile(out_root, 'wind_speed_component_severity_delta.csv'), 'TextType', 'string');
psets = unique(V.parameter_set_id);
metrics = unique(V.metric_name);
sigmas = unique(V.sigma);
rows = {};
for p = 1:numel(psets)
    for m = 1:numel(metrics)
        for si = 1:numel(sigmas)
            a = V(V.parameter_set_id==psets(p) & V.metric_name==metrics(m) & V.sigma==sigmas(si) & V.scenario_id=="wind_speed_11_28", :);
            b = V(V.parameter_set_id==psets(p) & V.metric_name==metrics(m) & V.sigma==sigmas(si) & V.scenario_id=="wind_speed_12_00", :);
            if isempty(a) || isempty(b), continue; end
            sim_direction = direction(b.var_value(1)-a.var_value(1));
            prob_driver = mode_or(P(P.parameter_set_id==psets(p), :), "probability_driver");
            sev_driver = mode_or(S(S.parameter_set_id==psets(p), :), "severity_driver");
            root_cause = choose_root(sim_direction, prob_driver, sev_driver);
            rows{end+1,1} = table(psets(p), metrics(m), sigmas(si), a.var_value(1), b.var_value(1), sim_direction, ...
                "12mps_expected_lower_or_not_higher", sim_direction=="matches_paper_direction", "", "", NaN, NaN, ...
                prob_driver, sev_driver, root_cause, recommended(root_cause), ...
                "Tail branch sets are not recomputed from per-sigma samples in this diagnostic summary.", ...
                'VariableNames', {'parameter_set_id','metric_name','sigma','wind_speed_11_28_var','wind_speed_12_00_var', ...
                'sim_direction','paper_expected_direction','direction_match','tail_initial_branch_set_11_28','tail_initial_branch_set_12_00', ...
                'dominant_tail_branch_11_28','dominant_tail_branch_12_00','dominant_probability_driver','dominant_severity_driver', ...
                'dominant_root_cause','recommended_fix','note'}); %#ok<AGROW>
        end
    end
end
writetable(vertcat(rows{:}), fullfile(out_root, 'wind_speed_component_tail_driver_summary.csv'));
end

function s = direction(delta)
if delta < 0
    s = "matches_paper_direction";
elseif delta > 0
    s = "12mps_higher_than_11p28";
else
    s = "flat";
end
end

function s = mode_or(T, name)
if isempty(T), s="missing"; else, s=string(mode(categorical(string(T.(char(name)))))); end
end

function r = choose_root(sim_direction, pdriver, sdriver)
if sim_direction == "matches_paper_direction"
    r = "trend_matches_paper";
elseif pdriver ~= "no_probability_increase" && pdriver ~= "missing"
    r = "line_probability_formula_response";
elseif sdriver ~= "no_severity_increase" && sdriver ~= "missing"
    r = "severity_formula_response";
else
    r = "stochastic_tail_instability";
end
end

function s = recommended(root)
switch root
    case "line_probability_formula_response", s = "inspect_line_outage_probability_formula";
    case "severity_formula_response", s = "inspect_severity_formula";
    case "trend_matches_paper", s = "hold_parameter_refinement_until_full_pilot_review";
    otherwise, s = "increase_wind_speed_trials_further";
end
end
