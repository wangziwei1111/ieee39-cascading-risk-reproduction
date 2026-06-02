function main_build_PL_formula_next_step_branch_plan()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
ensure_dir(out_dir);
rows = {
row("user_confirms_simple_sum", "P_L simple sum is paper-confirmed.", "inspect stage_probability_aggregation or severity_formula", "do not switch to union", "none", "document formula confirmation and continue next audit", "Current code can remain.")
row("user_confirms_independent_union", "P_L should use independent-union/inclusion-exclusion.", "implement PL_event_aggregation_mode=paper_independent_union then run wind-speed-only diagnostic rerun", "do not run full formal pilot immediately", "change P_L aggregation only under paper-confirmed mode", "formula smoke plus wind-speed-only diagnostic rerun", "Still not final reproduction.")
row("user_confirms_clipped_sum", "P_L is simple sum with clipping.", "ensure clipping and rerun wind-speed-only diagnostic if needed", "do not introduce union", "none if current clipping is accepted", "formula smoke; maybe no rerun if unchanged", "Current implementation already clips.")
row("user_says_formula_not_clear", "Paper does not resolve aggregation form.", "keep simple_sum as current extracted assumption; proceed to stage_probability_aggregation audit, mark uncertainty", "do not change formula", "none", "uncertainty note in docs/results", "Conservative path.")
row("user_provides_new_formula", "A different paper formula is provided.", "implement new formula after formula-specific smoke test", "do not run benchmark before smoke", "to be determined", "source audit, smoke, then wind-speed-only diagnostic", "Need exact formula text.")
};
writetable(vertcat(rows{:}), fullfile(out_dir, 'PL_formula_next_step_branch_plan.csv'));
end

function T = row(outcome, interp, allowed, forbidden, code, diag, note)
T = table(string(outcome), string(interp), string(allowed), string(forbidden), string(code), string(diag), string(note), ...
    'VariableNames', {'confirmation_outcome','interpretation','allowed_next_step','forbidden_next_step','required_code_change','required_diagnostic','note'});
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
