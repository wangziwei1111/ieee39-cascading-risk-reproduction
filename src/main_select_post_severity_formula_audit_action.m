function main_select_post_severity_formula_audit_action()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula');
S=readtable(fullfile(out_dir,'severity_formula_source_audit.csv'),'TextType','string','Delimiter',',');
R=readtable(fullfile(out_dir,'severity_metric_recompute_audit.csv'),'TextType','string','Delimiter',',');
D=readtable(fullfile(out_dir,'wind_speed_severity_response_delta.csv'),'TextType','string','Delimiter',',');
has_mismatch=any(R.issue_type~="no_issue");
formula_missing=any(S.formula_status=="code_implementation_only" | S.formula_status=="missing");
material=any(D.delta_recorded_12_minus_11>0 & D.metric_name=="CRI");
if has_mismatch && formula_missing
    go="need_manual_paper_confirmation_for_severity_formula"; cause="severity_trace_formula_mismatch_and_paper_formula_unconfirmed"; next="Confirm LLR/LFOR/NVOR formulas and whether severity trace should be stage-level or chain-level before any fix.";
elseif has_mismatch
    go="fix_severity_formula_then_wind_speed_diagnostic_rerun"; cause="severity_recompute_mismatch"; next="Fix confirmed implementation mismatch, then run wind-speed-only diagnostic rerun.";
elseif formula_missing && material
    go="need_manual_paper_confirmation_for_severity_formula"; cause="severity_formula_unconfirmed_material_effect"; next="Ask user to confirm LLR/LFOR/NVOR formulas and normalization before parameter refinement.";
else
    go="increase_wind_speed_trials_with_confirmed_formulas"; cause="severity_recompute_matches_no_formula_fix"; next="If severity formulas are confirmed, consider targeted increased wind-speed diagnostic with existing formulas before any full pilot.";
end
T=table(true,cause,"current_basic_formula_recomputed_from_trace",go,next, ...
 "No local search, no parameter tuning, no final_summary, no full formal pilot.", ...
 'VariableNames',{'selected','dominant_root_cause','formula_status','go_no_go','recommended_next_action','note'});
writetable(T,fullfile(out_dir,'post_severity_formula_audit_action.csv'));
end
