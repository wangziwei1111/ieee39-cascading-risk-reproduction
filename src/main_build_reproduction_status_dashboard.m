function main_build_reproduction_status_dashboard()
%MAIN_BUILD_REPRODUCTION_STATUS_DASHBOARD Build reproduction status summary only.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'reproduction_status');
ensure_dir(out_dir);
rows = {};
rows = add(rows, 'IEEE39 base case construction', 'completed_with_diagnostic_assumption', 'medium', 'paper_inputs/filled/paper_case39_*.csv; src/cases/build_case39_base.m', 'Full original modified IEEE39 data not fully public.', 'Need original case file or author data for strict reproduction.', 'Framework uses MATPOWER/case inputs and records public-data caveat.');
rows = add(rows, 'wind power curve', 'completed', 'high', 'src/renewable/compute_paper_wind_power_curve.m; docs/wind_speed_operating_point_sensitivity_report.md', 'None for 2/12/20 curve shape currently.', 'Keep fixed; do not tune public wind curve.', '11.28 gives about 2489 MW and 12.00 gives 3000 MW for 3000 MW capacity.');
rows = add(rows, 'wind penetration basis', 'completed_with_diagnostic_assumption', 'medium', 'docs/scenario_definitions.md; paper_inputs/filled/public_fixed_parameters.csv', 'Paper denominator and scenario tables still partially ambiguous.', 'Confirm exact penetration denominator and scenario table.', 'Not the main current blocker for wind-speed trend.');
rows = add(rows, 'line outage probability P_flow', 'completed', 'high', 'results/calibration/line_probability_formula/post_line_probability_formula_audit_action.csv', 'Statistical parameters remain benchmark-calibrated/diagnostic.', 'Need original statistical parameters for strict numerical reproduction.', 'Formula structure is fixed; parameters are not original-paper extracted.');
rows = add(rows, 'hidden failure probability P_HF_L', 'completed', 'high', 'results/calibration/hidden_failure_formula/post_hidden_failure_formula_audit_action.csv', 'Hidden-failure statistical parameters not fully public.', 'Need P_L_D/P_L_r/P_W_D/ZIII details.', 'Formula branch confirmed; parameter layer remains diagnostic.');
rows = add(rows, 'P_L = P1+P2+P3', 'completed', 'high', 'results/calibration/event_probability_formula/PL_formula_manual_confirmation_record.csv', 'Parameter calibration not original-paper extracted.', 'Keep formula fixed and document parameter status.', 'Do not revert to union-style probability.');
rows = add(rows, 'Markov chain sampling', 'historical_diagnostic_only', 'medium', 'src/cascade/search_cascade_markov_line.m', 'Paper exact random sampling design not fully public.', 'Need sample count/common-random-chain policy if strict reproduction is required.', 'Do not change sampling logic in this summary stage.');
rows = add(rows, 'full-event chain transition probability', 'completed', 'high', 'results/calibration/transition_probability/full_event_formal_var_pilot_readiness.csv', 'Still line/probability parameter dependent.', 'Use only with confirmed operating point and parameter assumptions.', 'Full-event probability framework is implemented.');
rows = add(rows, 'terminal-aware probability handling', 'completed', 'high', 'results/calibration/transition_probability/terminal_aware_full_event_readiness_check_log.txt', 'No current blocker.', 'Retain as confirmed diagnostic infrastructure.', 'Terminal handling readiness passed earlier.');
rows = add(rows, 'severity formula LLR/LFOR/NVOR', 'completed', 'high', 'results/calibration/severity_formula/severity_formula_manual_confirmation_record.csv', 'Not enough to resolve wind-speed trend.', 'Keep confirmed formula fixed.', 'Legacy severity issue has been resolved.');
rows = add(rows, 'VaR metric construction', 'completed_with_diagnostic_assumption', 'medium', 'results/calibration/full_event_formal_var_pilot_after_curve_fix/full_event_var_score_summary_after_curve_fix.csv', 'Scenario operating point and parameters still block strict benchmark.', 'Do not call formal benchmark until scenario assumptions are available.', 'VaR machinery exists, but current outputs are not final reproduction.');
rows = add(rows, 'topology_compare', 'partially_completed', 'medium', 'results/paper_alignment/tables/paper_vs_reproduction_comparison.csv', 'Original parameters/operating point still not fully public.', 'Revisit only after parameter/operating-point gap is closed.', 'Useful diagnostic comparison, not strict reproduction.');
rows = add(rows, 'penetration_scan', 'partially_completed', 'medium', 'results/paper_alignment/tables/paper_vs_reproduction_comparison.csv', 'Penetration basis and dispatch assumptions remain uncertain.', 'Need exact scenario setup.', 'Do not rerun blindly.');
rows = add(rows, 'wind_speed_scan', 'blocked_by_public_information_gap', 'blocked', 'results/calibration/wind_speed_scenario_assumption/post_wind_speed_operating_point_sensitivity_action.csv', 'Paper does not state dispatch/absorption/slack/curtailment/baseflow policy.', 'Need additional paper/author data for operating-point construction.', 'Current go/no-go is document_public_information_insufficient.');
rows = add(rows, 'full 7-scenario formal pilot', 'not_allowed_yet', 'blocked', 'results/calibration/wind_speed_scenario_assumption/post_wind_speed_operating_point_sensitivity_action.csv', 'Wind-speed scenario trend unresolved and public info insufficient.', 'Pause strict pilot until operating-point details are available.', 'Do not run full formal pilot now.');
rows = add(rows, 'parameter calibration / local search', 'not_allowed_yet', 'blocked', 'results/calibration/wind_speed_scenario_assumption/post_wind_speed_operating_point_sensitivity_action.csv', 'Blind tuning would mask missing scenario assumptions.', 'Request additional paper data or write diagnostic-only report.', 'No local search or parameter refinement.');
T = cell2table(rows, 'VariableNames', {'module','status','completion_level','evidence_file','blocking_issue','next_requirement','note'});
writetable(T, fullfile(out_dir, 'reproduction_status_dashboard.csv'));
fprintf('Wrote reproduction_status_dashboard.csv\n');
end

function rows = add(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir'), mkdir(pathname); end
end
