function main_select_post_stage_probability_aggregation_action()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'stage_probability_aggregation');
A = readtable(fullfile(out_dir, 'stage_probability_aggregation_audit.csv'), 'TextType','string', 'Delimiter', ',');
D = readtable(fullfile(out_dir, 'wind_speed_stage_probability_delta.csv'), 'TextType','string', 'Delimiter', ',');
has_mismatch = any(A.aggregation_match_status=="mismatch");
if has_mismatch
    cause = "stage_probability_mismatch";
    go = "inspect_stage_probability_implementation";
    next = "Inspect stage probability implementation before any further calibration.";
elseif any(D.stage_probability_driver=="selected_probability_increase" | D.stage_probability_driver=="complement_product_decrease")
    cause = "stage_probability_response_explains_part_of_wind_speed_delta";
    go = "inspect_severity_formula";
    next = "Stage aggregation implementation matches; inspect severity formula response next.";
elseif isempty(D)
    cause = "insufficient_paired_stage_data";
    go = "increase_wind_speed_trials_with_stage_logging";
    next = "If needed later, run a targeted diagnostic with stage logging; do not run full formal pilot now.";
else
    cause = "stage_probability_matches_no_clear_driver";
    go = "inspect_severity_formula";
    next = "Stage aggregation matches; move to severity formula audit.";
end
T = table(true, cause, go, next, ...
    "P_L simple sum is user-confirmed; no local search, no parameter tuning, no final_summary, no full pilot.", ...
    'VariableNames', {'selected','dominant_root_cause','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_dir, 'post_stage_probability_aggregation_action.csv'));
end
