function main_select_post_wind_speed_operating_point_sensitivity_action()
project_root = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
summary = readtable(fullfile(root, 'wind_speed_operating_point_sensitivity_summary.csv'), 'TextType', 'string', 'Delimiter', ',');
tail = readtable(fullfile(root, 'tail_branch_operating_point_policy_comparison.csv'), 'TextType', 'string', 'Delimiter', ',');

tail_good = unique(tail.policy_id(tail.policy_candidate_status == "candidate_policy_for_user_confirmation"));
candidate = summary(summary.risk_direction_proxy == "12mps_likely_lower_risk" & ismember(summary.policy_id, tail_good), :);
selected_policy = "";
if ~isempty(candidate)
    selected_policy = string(candidate.policy_id(1));
    go = "need_user_confirmation_before_policy_rerun";
    rec = "ask user whether this policy is defensible before wind-speed-only diagnostic rerun";
    reason = "At least one baseflow sensitivity policy makes 12mps line-loading proxy lower than 11.28mps.";
elseif any(summary.policy_id == "wind_plus_redispatch_current" & summary.risk_direction_proxy ~= "12mps_likely_higher_risk")
    selected_policy = "wind_plus_redispatch_current";
    go = "keep_current_policy_and_increase_trials";
    rec = "increase wind-speed-only trials only after documenting paper dispatch ambiguity";
    reason = "Current policy is not clearly worse in baseflow proxy.";
else
    selected_policy = "none";
    go = "document_public_information_insufficient";
    rec = "document that public paper information is insufficient for wind-speed trend reproduction; do not tune parameters blindly";
    reason = "No tested policy simultaneously lowers the global baseflow proxy and the dominant tail-branch loading/P_L basis for 12mps.";
end

T = table(true, "not_stated_in_paper", selected_policy, reason, go, rec, ...
    "Sensitivity policies are diagnostic only, not paper-confirmed and not final reproduction.", ...
    'VariableNames', {'selected','paper_assumption_status','selected_policy_id','reason','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(root, 'post_wind_speed_operating_point_sensitivity_action.csv'));
fprintf('Wrote post wind-speed operating point sensitivity action.\n');
end
