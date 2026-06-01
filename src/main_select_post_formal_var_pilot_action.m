function main_select_post_formal_var_pilot_action()
%MAIN_SELECT_POST_FORMAL_VAR_PILOT_ACTION Select next action from pilot score only.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
S = readtable(fullfile(out_root, 'formal_var_pilot_score_summary.csv'), 'TextType', 'string', 'Delimiter', ',');
[~, order] = sort(S.score_rank, 'ascend', 'MissingPlacement', 'last');
S = S(order, :);
selected_row = S(1, :);
if any(S.recommendation == "candidate_for_scale_aware_calibration")
    selected_row = S(find(S.recommendation == "candidate_for_scale_aware_calibration", 1), :);
    go = "proceed_to_scale_aware_calibration_plan";
    action = "draft scale-aware calibration plan only; do not run local search yet";
elseif any(S.recommendation == "candidate_but_needs_parameter_refinement")
    selected_row = S(find(S.recommendation == "candidate_but_needs_parameter_refinement", 1), :);
    go = "proceed_to_parameter_refinement_plan";
    action = "draft parameter refinement plan only; do not execute local search";
elseif all(S.recommendation == "wrong_trend" | S.recommendation == "wrong_scale")
    go = "fix_metric_or_scenario_first";
    action = "review metric definition or scenario implementation before calibration";
else
    go = "stop_calibration";
    action = "insufficient evidence for calibration";
end
T = table(true, selected_row.parameter_set_id(1), selected_row.metric_source(1), ...
    "selected from formal pilot score summary; no local search executed", go, action, ...
    "formal pilot is not final benchmark and benchmark_calibrated parameters are not original paper parameters", ...
    'VariableNames', {'selected','parameter_set_id','metric_source','reason','go_no_go', ...
    'recommended_next_action','note'});
writetable(T, fullfile(out_root, 'post_formal_var_pilot_action.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'post_formal_var_pilot_action.csv'));
end
