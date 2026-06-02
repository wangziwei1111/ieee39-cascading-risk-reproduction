function main_explain_wind_speed_probability_increase_by_formula_terms()
root = fileparts(fileparts(mfilename('fullpath')));
diag_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
Delta = readtable(fullfile(diag_root, 'wind_speed_component_probability_delta.csv'), 'TextType','string');
Audit = readtable(fullfile(out_dir, 'line_probability_component_recompute_audit.csv'), 'TextType','string');
Below = readtable(fullfile(out_dir, 'below_rated_Pflow_variation_audit.csv'), 'TextType','string');
rows = cell(height(Delta),1);
for i = 1:height(Delta)
    ps = Delta.parameter_set_id(i); br = Delta.candidate_branch(i);
    a = summarize(Audit(Audit.parameter_set_id==ps & Audit.candidate_branch==br & Audit.scenario_id=="wind_speed_11_28", :));
    b = summarize(Audit(Audit.parameter_set_id==ps & Audit.candidate_branch==br & Audit.scenario_id=="wind_speed_12_00", :));
    below_issue = any(Below.parameter_set_id==ps & Below.candidate_branch==br & Below.issue_confirmed);
    d_rec_flow = Delta.mean_P_flow_12_00(i)-Delta.mean_P_flow_11_28(i);
    d_re_flow = b.P_flow-a.P_flow;
    d_rec_PL = Delta.mean_P_L_12_00(i)-Delta.mean_P_L_11_28(i);
    d_re_PL = b.P_L-a.P_L;
    rows{i} = table(ps, br, Delta.delta_line_loading(i), d_rec_flow, d_re_flow, d_rec_PL, d_re_PL, ...
        string(Delta.probability_driver(i)), classify_recomputed(d_re_flow, d_re_PL), below_issue, effect(below_issue, d_re_PL), ...
        recommended(below_issue, d_re_PL), "Paper recompute uses current explicit paper_piecewise_constant_below_rated mode.", ...
        'VariableNames', {'parameter_set_id','candidate_branch','delta_line_loading','delta_recorded_P_flow', ...
        'delta_recomputed_P_flow_paper','delta_recorded_P_L','delta_recomputed_P_L_paper','recorded_probability_driver', ...
        'paper_recomputed_probability_driver','below_Lrated_issue_confirmed','effect_on_wind_speed_trend','recommended_fix','note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'wind_speed_probability_increase_formula_explanation.csv'));
end

function S = summarize(T)
if isempty(T)
    S = struct('P_flow',NaN,'P_L',NaN);
else
    S = struct('P_flow',mean(T.recomputed_P_flow_paper,'omitnan'),'P_L',mean(T.recomputed_P_L_paper,'omitnan'));
end
end

function s = classify_recomputed(dflow, dpl)
if dflow > 1e-9 && dpl > 1e-9
    s = "mixed_probability_increase";
elseif dflow > 1e-9
    s = "P_flow_increase";
elseif dpl > 1e-9
    s = "P_L_increase";
else
    s = "no_probability_increase";
end
end

function s = effect(issue, dpl)
if issue
    s = "formula_fix_likely_reduces_12mps_risk";
elseif dpl > 1e-9
    s = "paper_formula_still_increases_12mps_risk";
else
    s = "no_clear_effect";
end
end

function s = recommended(issue, dpl)
if issue
    s = "fix_P_flow_below_Lrated";
elseif dpl > 1e-9
    s = "inspect_hidden_failure_or_loading_response";
else
    s = "no_Pflow_fix_required";
end
end
