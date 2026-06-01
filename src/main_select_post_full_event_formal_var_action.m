function main_select_post_full_event_formal_var_action()
%MAIN_SELECT_POST_FULL_EVENT_FORMAL_VAR_ACTION Select next recommended action after full-event formal pilot.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
score = readtable(fullfile(out_root, 'full_event_formal_var_score_summary.csv'), 'TextType', 'string');
score = sortrows(score, {'score_rank'});
best = score(1, :);
switch string(best.recommendation(1))
    case "candidate_for_limited_parameter_refinement"
        go = "proceed_to_limited_parameter_refinement_plan";
    case "candidate_but_metric_scale_needs_review"
        go = "review_metric_scale_before_refinement";
    case "wrong_trend"
        go = "fix_cascade_transition_mechanism";
    case "wrong_scale"
        go = "fix_metric_or_scenario_first";
    otherwise
        go = "stop_calibration";
end
out = table(true, best.parameter_set_id(1), string(best.recommendation(1)), go, ...
    resolve_next_action(go), ...
    "Recommendation only; no local search or parameter tuning was run.", ...
    'VariableNames', {'selected','parameter_set_id','reason','go_no_go','recommended_next_action','note'});
writetable(out, fullfile(out_root, 'post_full_event_formal_var_action.csv'));
fprintf('post full-event action written: %s\n', out_root);
end

function action = resolve_next_action(go)
switch string(go)
    case "proceed_to_limited_parameter_refinement_plan"
        action = "prepare_limited_parameter_refinement_plan_without_running_search";
    case "review_metric_scale_before_refinement"
        action = "review_metric_scale_and_unit_convention_before_refinement";
    case "fix_cascade_transition_mechanism"
        action = "fix_cascade_transition_mechanism_before_parameter_refinement";
    case "fix_metric_or_scenario_first"
        action = "fix_metric_or_scenario_definition_first";
    otherwise
        action = "stop_and_review";
end
end
