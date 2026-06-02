function main_select_post_PL_event_probability_audit_action()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
A = readtable(fullfile(out_dir, 'PL_event_probability_formula_implementation_audit.csv'), 'TextType','string');
U = readtable(fullfile(out_dir, 'PL_sum_vs_union_difference_audit.csv'), 'TextType','string');
E = readtable(fullfile(out_dir, 'wind_speed_P1_P2_P3_increase_explanation.csv'), 'TextType','string');
paper_union_confirmed = any(A.formula_item=="inclusion_exclusion_needed" & A.match_status=="match");
material = any(logical(U.difference_material));
if paper_union_confirmed && material
    go = "apply_PL_aggregation_fix_then_wind_speed_diagnostic_rerun";
    cause = "PL_union_confirmed_and_material";
    next = "Apply confirmed PL aggregation fix, then run wind-speed-only diagnostic rerun; full pilot still not allowed this turn.";
elseif material
    go = "need_manual_paper_confirmation_for_PL_formula";
    cause = dominant_effect(E);
    next = "Manual paper confirmation is needed before changing P_L from simple sum to union.";
elseif any(E.dominant_probability_term=="P2_dominant")
    go = "inspect_stage_probability_aggregation";
    cause = "P2_dominant_but_formula_matches";
    next = "P1/P2/P3 formulas match current extracted paper structure; inspect stage event aggregation or severity response next.";
else
    go = "inspect_severity_formula";
    cause = "PL_formula_matches_no_material_union_effect";
    next = "P_L formula and candidate probability path appear internally consistent; inspect severity response next.";
end
T = table(true, cause, "simple_sum_current_union_not_confirmed", go, next, ...
    "No local search, no parameter tuning, no final_summary, no full formal pilot in this turn.", ...
    'VariableNames', {'selected','dominant_root_cause','paper_formula_status','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_dir, 'post_PL_event_probability_audit_action.csv'));
end

function s = dominant_effect(E)
if any(E.PL_aggregation_effect=="union_would_reduce_risk")
    s = "PL_sum_vs_union_material_needs_confirmation";
else
    s = "PL_sum_vs_union_material_but_direction_unclear";
end
end
