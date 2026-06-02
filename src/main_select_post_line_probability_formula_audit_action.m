function main_select_post_line_probability_formula_audit_action()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
A = readtable(fullfile(out_dir, 'below_rated_Pflow_variation_audit.csv'), 'TextType','string');
C = readtable(fullfile(out_dir, 'wind_speed_before_after_Pflow_fix_comparison.csv'), 'TextType','string');
issue = any(logical(A.issue_confirmed));
formula_fixed = ~issue;
if ~issue
    go = "inspect_hidden_failure_probability_formula";
    next = "P_flow below-rated implementation matches paper; inspect P_HF_L/P_mis_r/P1/P2 response next.";
    dir_after = "skipped_no_issue_confirmed";
elseif any(C.after_match)
    go = "rerun_full_event_formal_pilot_after_Pflow_fix";
    next = "recommend full-event formal pilot rerun next turn only; not run now.";
    dir_after = "matches_paper_direction";
else
    go = "inspect_hidden_failure_probability_formula";
    next = "Pflow fix did not correct direction; inspect hidden failure terms.";
    dir_after = "not_matched";
end
T = table(true, issue, formula_fixed, dir_after, go, next, ...
    "No local search, no parameter tuning, no final_summary, no full formal pilot in this turn.", ...
    'VariableNames', {'selected','issue_confirmed','formula_fixed','wind_speed_direction_after_fix','go_no_go', ...
    'recommended_next_action','note'});
writetable(T, fullfile(out_dir, 'post_line_probability_formula_audit_action.csv'));
end
