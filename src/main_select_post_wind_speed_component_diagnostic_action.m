function main_select_post_wind_speed_component_diagnostic_action()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'wind_speed_component_diagnostic_rerun');
Tail = readtable(fullfile(out_root, 'wind_speed_component_tail_driver_summary.csv'), 'TextType', 'string');
root_cause = string(mode(categorical(string(Tail.dominant_root_cause))));
switch root_cause
    case "line_probability_formula_response"
        go = "inspect_line_outage_probability_formula";
        next = "inspect P_flow/P_HF_L/P1/P2 response before any parameter refinement";
    case "severity_formula_response"
        go = "inspect_severity_formula";
        next = "inspect LLR/LFOR/NVOR/CRI severity formula before any parameter refinement";
    case {"tail_initial_branch_composition","stochastic_tail_instability"}
        go = "increase_wind_speed_trials_further";
        next = "increase wind-speed-only diagnostic trials if more stability is needed";
    case "trend_matches_paper"
        go = "proceed_to_limited_parameter_refinement_blocked";
        next = "do not start local search until full 7-scenario formal pilot is reviewed";
    otherwise
        go = "fix_metric_definition_first";
        next = "clarify metric basis before any rerun";
end
T = table(true, root_cause, go, next, ...
    "Diagnostic-only action. No local search, no parameter tuning, no final_summary, P_WT diagnostic-only.", ...
    'VariableNames', {'selected','dominant_root_cause','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_root, 'post_wind_speed_component_diagnostic_action.csv'));
end
