function main_update_PL_event_probability_audit_after_manual_confirmation()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
R = readtable(fullfile(out_dir, 'PL_formula_manual_confirmation_record.csv'), 'TextType','string', 'Delimiter', ',');
confirmed = logical(R.confirmed_by_user(1)) && logical(R.union_formula_rejected(1));
if confirmed
    status = "simple_sum_confirmed_by_user";
    go = "inspect_stage_probability_aggregation";
    next = "audit Markov stage probability aggregation and severity response before any parameter refinement";
    note = "Paper formula (3-6) confirmed as P_L=P1+P2+P3; union is no longer a formula-fix direction.";
else
    status = "manual_confirmation_missing";
    go = "need_manual_paper_confirmation_for_PL_formula";
    next = "do not change formula";
    note = "Manual confirmation record is missing or incomplete.";
end
T = table(true, "PL_simple_sum_confirmed_not_root_cause", status, go, next, note, ...
    'VariableNames', {'selected','dominant_root_cause','paper_formula_status','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_dir, 'post_PL_event_probability_audit_action_v2.csv'));
end
