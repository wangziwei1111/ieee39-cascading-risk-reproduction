function main_select_wind_speed_probability_severity_root_cause_action()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
Driver = readtable(fullfile(out_root, 'wind_speed_tail_probability_severity_driver_summary.csv'), 'TextType', 'string');
dominant = string(mode(categorical(string(Driver.dominant_tail_driver))));
switch dominant
    case "line_probability_model"
        go = "inspect_line_outage_probability_formula";
        next = "review P_L component formula and candidate probability basis before any rerun";
    case "severity_model"
        go = "inspect_severity_formula";
        next = "review LLR/LFOR/NVOR/CRI severity basis before any rerun";
    case {"initial_branch_tail_composition","stochastic_tail_sample","insufficient_component_fields"}
        go = "run_wind_speed_only_more_trials_with_component_logging";
        next = "prepare small wind-speed-only diagnostic rerun with component logging, not formal benchmark";
    otherwise
        go = "fix_metric_definition_first";
        next = "clarify probability/severity metric basis before any parameter refinement";
end
T = table(true, dominant, go, next, ...
    "Local search and parameter refinement remain blocked; P_WT remains diagnostic-only.", ...
    'VariableNames', {'selected','dominant_root_cause','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_root, 'post_wind_speed_probability_severity_diagnosis_action.csv'));
end
