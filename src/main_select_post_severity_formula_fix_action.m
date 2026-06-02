function main_select_post_severity_formula_fix_action()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
C = readtable(fullfile(out_dir,'wind_speed_before_after_severity_fix_comparison.csv'), 'TextType','string', 'Delimiter', ',');
cri = C(C.metric_name=="CRI" & abs(C.sigma-0.95)<1e-9, :);
after_match = any(cri.after_match);
reduced = any(cri.interpretation=="severity_fix_reduced_but_not_corrected");
if after_match
    go = "rerun_full_event_formal_pilot_after_severity_fix";
    next = "Next step may be full-event formal pilot after severity fix, but not in this run.";
    dir = "matches_or_partly_matches_paper_direction";
elseif reduced
    go = "increase_wind_speed_trials_after_formula_fix";
    next = "Increase wind-speed-only trials after formula fix before full pilot.";
    dir = "reduced_but_not_corrected";
else
    go = "inspect_remaining_probability_tail_composition";
    next = "Inspect probability tail composition before any formal pilot.";
    dir = "not_corrected";
end
T = table(true, true, dir, go, next, ...
    "Paper-confirmed severity mode implemented; no local search, no tuning, no final_summary, no full formal pilot.", ...
    'VariableNames', {'selected','formula_fixed','wind_speed_direction_after_fix','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_dir,'post_severity_formula_fix_action.csv'));
end
