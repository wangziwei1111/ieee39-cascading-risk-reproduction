function main_select_post_wind_speed_diagnosis_action()
%MAIN_SELECT_POST_WIND_SPEED_DIAGNOSIS_ACTION Select go/no-go after diagnosis.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
D = readtable(fullfile(out_root, 'wind_speed_trend_root_cause_diagnosis.csv'), 'TextType','string', 'Delimiter', ',');
root = D(D.diagnosis_item=="likely_root_cause", :);
cause = string(root.note(1));
if cause == "wind_speed_not_applied_to_case"
    go = "fix_wind_speed_case_builder";
elseif cause == "wind_power_curve_mismatch"
    go = "fix_wind_power_curve";
elseif cause == "wind_trip_model_missing"
    go = "implement_or_record_wind_trip_model";
elseif cause == "unknown_need_formal_rerun_with_more_trials"
    go = "rerun_full_event_formal_pilot_with_more_trials";
elseif cause == "paper_metric_definition_still_mismatched" || contains(cause, "severity")
    go = "fix_metric_definition_first";
else
    go = "fix_metric_definition_first";
end
if go == "rerun_full_event_formal_pilot_with_more_trials"
    action = "Only consider more trials after confirming the scenario and wind power curve are correct.";
elseif go == "fix_wind_power_curve"
    action = "Audit and decide whether calibration wind-speed aliases must use paper 2/12/20 wind curve before any parameter refinement.";
elseif go == "implement_or_record_wind_trip_model"
    action = "Record or implement calibrated wind-trip diagnostic before treating wind-speed trend as parameter-calibration issue.";
else
    action = "Fix the diagnosed mechanism before parameter refinement.";
end
T = table(true, "Wind-speed trend root cause diagnosis completed.", go, action, ...
    "No local search or parameter tuning should start until the wind-speed trend issue is explained.", ...
    'VariableNames', {'selected','reason','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_root, 'post_wind_speed_diagnosis_action.csv'));
end
