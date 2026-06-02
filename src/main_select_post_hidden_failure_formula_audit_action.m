function main_select_post_hidden_failure_formula_audit_action()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
A = readtable(fullfile(out_dir, 'below_Lmax_PHFL_variation_audit.csv'), 'TextType','string');
C = readtable(fullfile(out_dir, 'wind_speed_before_after_PHFL_fix_comparison.csv'), 'TextType','string');
issue = any(logical(A.issue_confirmed));
smoke = readtable(fullfile(out_dir, 'hidden_failure_formula_fix_smoke.csv'), 'TextType','string');
formula_fixed = all(string(smoke.pass_fail) == "pass");
if ~issue
    go = "continue_hidden_failure_formula_audit";
    next = "P_HF_L below-Lmax implementation matches paper; inspect P1/P2 weighting, event probability aggregation, or severity response next.";
    dir_after = "skipped_no_issue_confirmed";
elseif ~isempty(C) && any(C.after_match)
    go = "rerun_full_event_formal_pilot_after_PHFL_fix";
    next = "recommend full-event formal pilot rerun next turn only; not run now.";
    dir_after = "matches_paper_direction";
else
    go = "inspect_P1_P2_weighting_or_event_probability";
    next = "P_HF_L formula smoke passes but direction is not corrected; inspect probability weighting or severity formula.";
    dir_after = "not_matched";
end
T = table(true, issue, formula_fixed, dir_after, go, next, ...
    "No local search, no parameter tuning, no final_summary, no full formal pilot in this turn.", ...
    'VariableNames', {'selected','issue_confirmed','formula_fixed','wind_speed_direction_after_fix','go_no_go', ...
    'recommended_next_action','note'});
writetable(T, fullfile(out_dir, 'post_hidden_failure_formula_audit_action.csv'));
end
