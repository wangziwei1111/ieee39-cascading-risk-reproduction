function main_select_post_curve_fix_formal_pilot_action()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
score = readtable(fullfile(out_root, 'full_event_var_score_summary_after_curve_fix.csv'), 'TextType','string', 'Delimiter', ',');
ready = readtable(fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot', 'post_wind_curve_fix_readiness.csv'), 'TextType','string', 'Delimiter', ',');
score = sortrows(score, 'score_rank');
best = score(1,:);
if best.recommendation == "candidate_for_limited_parameter_refinement"
    go = "proceed_to_limited_parameter_refinement_plan";
elseif logical(ready.warning_issue_count(1) > 0) && best.overall_trend_match_rate >= 0.75
    go = "review_wind_trip_probability_before_refinement";
elseif best.recommendation == "candidate_but_metric_scale_needs_review"
    go = "review_metric_scale_before_refinement";
elseif best.wind_speed_direction_match == 0
    go = "fix_metric_or_scenario_first";
elseif best.recommendation == "wrong_trend"
    go = "fix_cascade_transition_mechanism";
else
    go = "review_metric_scale_before_refinement";
end
T = table(true, best.parameter_set_id, string(best.recommendation), go, ...
    "Post curve-fix pilot action only; no local search was run.", ...
    "benchmark_calibrated parameters are not original paper parameters; wind_trip warning must remain visible.", ...
    'VariableNames', {'selected','parameter_set_id','reason','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_root, 'post_curve_fix_formal_pilot_action.csv'));
end
