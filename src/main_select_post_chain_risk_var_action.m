function main_select_post_chain_risk_var_action()
%MAIN_SELECT_POST_CHAIN_RISK_VAR_ACTION Select next action after chain-risk VaR reconstruction.

project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'formal_var_pilot');
S = readtable(fullfile(out_root, 'formal_chain_risk_var_score_summary.csv'), 'TextType', 'string', 'Delimiter', ',');
weighted = S(S.sample_variant ~= "severity_only", :);
display_weighted = S(S.sample_variant == "initial_probability_weighted_display", :);
if any(weighted.recommendation == "candidate_metric_for_calibration")
    row = weighted(find(weighted.recommendation == "candidate_metric_for_calibration", 1), :);
    go = "proceed_to_limited_parameter_refinement_plan";
    action = "draft limited parameter refinement plan; do not execute local search automatically";
elseif any(weighted.recommendation == "candidate_but_missing_transition_probability")
    row = weighted(find(weighted.recommendation == "candidate_but_missing_transition_probability", 1), :);
    go = "record_transition_probabilities_then_rerun_formal_pilot";
    action = "record chain transition probabilities in future pilot before calibration";
elseif ~isempty(display_weighted) && all(display_weighted.recommendation == "wrong_trend" | display_weighted.recommendation == "wrong_scale")
    row = display_weighted(1, :);
    go = "fix_cascade_transition_mechanism";
    action = "review accident-chain probability mechanism before parameter tuning";
else
    row = weighted(1, :);
    go = "fix_metric_definition_first";
    action = "review metric definition and probability weighting";
end
T = table(true, row.parameter_set_id(1), row.sample_variant(1), row.metric_name(1), ...
    "selected from chain-risk VaR score summary; no local search executed", go, action, ...
    "Do not fabricate missing chain transition probability; this is a diagnostic action only.", ...
    'VariableNames', {'selected','parameter_set_id','sample_variant','metric_name','reason', ...
    'go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_root, 'post_chain_risk_var_action.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'post_chain_risk_var_action.csv'));
end
