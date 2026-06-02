function main_select_wind_speed_after_severity_fix_root_cause_action()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula');
tail=readtable(fullfile(out_dir,'wind_speed_after_severity_fix_tail_samples.csv'),'TextType','string','Delimiter',',');
init_delta=readtable(fullfile(out_dir,'wind_speed_after_severity_fix_tail_initial_branch_delta.csv'),'TextType','string','Delimiter',',');
cand_delta=readtable(fullfile(out_dir,'wind_speed_after_severity_fix_tail_candidate_branch_delta.csv'),'TextType','string','Delimiter',',');
base_delta=readtable(fullfile(out_dir,'wind_speed_after_severity_fix_baseflow_delta_summary.csv'),'TextType','string','Delimiter',',');
sample_count = height(unique(tail(:,{'parameter_set_id','scenario_id','initial_branch','trial_id'}),'rows'));
few_branches = sum(init_delta.dominant_change=="initial_branch_enters_tail_only_at_12mps" | init_delta.dominant_change=="both_probability_and_severity") > 0;
candidate_driven = sum(cand_delta.candidate_tail_driver=="only_appears_in_12mps_tail" | cand_delta.candidate_tail_driver=="selected_more_often_at_12mps" | cand_delta.candidate_tail_driver=="P_L_increase") > 0;
baseflow_driven = any(base_delta.interpretation=="higher_wind_output_increases_loading_and_tail_risk");
if sample_count < 500
    cause="insufficient_samples"; go="increase_wind_speed_trials_with_confirmed_formulas"; next="Generate readiness for higher-trial wind-speed-only diagnostic; do not tune parameters.";
elseif baseflow_driven
    cause="baseflow_driven_probability_tail"; go="inspect_wind_speed_scenario_assumption_in_paper"; next="Confirm paper wind-speed dispatch/absorption/power-flow redistribution assumptions before formal pilot.";
elseif few_branches
    cause="initial_branch_tail_composition"; go="increase_wind_speed_trials_with_confirmed_formulas"; next="Increase wind-speed-only trials with confirmed formulas to test tail stability.";
elseif candidate_driven
    cause="candidate_branch_tail_composition"; go="increase_wind_speed_trials_with_confirmed_formulas"; next="Increase wind-speed-only trials and inspect high-contribution candidate branches.";
else
    cause="confirmed_model_predicts_12mps_higher"; go="accept_diagnostic_divergence_and_document"; next="Document that current confirmed-formula diagnostic still diverges from paper wind-speed trend.";
end
T=table(true,cause,"12mps_higher_after_severity_fix",go,next, ...
    "No local search, no tuning, no final_summary. Tail diagnosis is diagnostic-only, not final reproduction.", ...
    'VariableNames',{'selected','dominant_root_cause','wind_speed_direction_status','go_no_go','recommended_next_action','note'});
writetable(T,fullfile(out_dir,'post_wind_speed_after_severity_fix_tail_action.csv'));
end
