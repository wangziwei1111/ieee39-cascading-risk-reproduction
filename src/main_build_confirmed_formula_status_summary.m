function main_build_confirmed_formula_status_summary()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'reproduction_status');
ensure_dir(out_dir);
rows = {};
rows = f(rows, 'wind', 'wind power curve 2/12/20', true, true, 'paper_2_12_20', false, 'src/renewable/compute_paper_wind_power_curve.m', 'Dispatch/absorption policy still separate.', 'Public curve fixed; do not tune.');
rows = f(rows, 'line_probability', 'P_flow piecewise', true, true, 'paper_piecewise_constant_below_rated', true, 'results/calibration/line_probability_formula/post_line_probability_formula_audit_action.csv', 'Statistical parameters not original.', 'Formula confirmed.');
rows = f(rows, 'line_probability', 'P_HF_L piecewise', true, true, 'paper_piecewise_constant_below_Lmax', true, 'results/calibration/hidden_failure_formula/post_hidden_failure_formula_audit_action.csv', 'P_L_D/P_L_r not original.', 'Formula confirmed.');
rows = f(rows, 'line_probability', 'P_mis_r', true, true, 'P_HF_D + P_HF_L - P_HF_D*P_HF_L', false, 'src/outage/compute_paper_line_outage_probability.m', 'Needs hidden-distance parameter if enabled.', 'Implemented in formula structure.');
rows = f(rows, 'line_probability', 'P1', true, true, 'P_flow*(1-P_in_r)*(1-P_in_c)', false, 'src/outage/compute_paper_line_outage_probability.m', 'P_in_r/P_in_c not original.', 'Implemented.');
rows = f(rows, 'line_probability', 'P2', true, true, 'P_mis_c + P_mis_r*(1-P_in_c)', false, 'src/outage/compute_paper_line_outage_probability.m', 'P_mis_c not original.', 'Implemented.');
rows = f(rows, 'line_probability', 'P3', true, true, 'cfg/table value', false, 'src/outage/compute_paper_line_outage_probability.m', 'P3 value not original.', 'Implemented as parameter.');
rows = f(rows, 'line_probability', 'P_L simple sum', true, true, 'P1+P2+P3 clipped to [0,1]', true, 'results/calibration/event_probability_formula/PL_formula_manual_confirmation_record.csv', 'Parameter layer diagnostic.', 'Confirmed after manual fix.');
rows = f(rows, 'stage_probability', 'Bernoulli full-event stage probability', true, true, 'full_event_chain_probability', true, 'results/calibration/transition_probability/full_event_formal_var_pilot_readiness.csv', 'Paper sample protocol still unknown.', 'Infrastructure completed.');
rows = f(rows, 'stage_probability', 'terminal stage probability one', true, true, 'terminal-aware handling', false, 'results/calibration/transition_probability/terminal_aware_full_event_readiness_check_log.txt', 'No current formula blocker.', 'Readiness checked.');
rows = f(rows, 'severity', 'LLR', true, true, 'paper confirmed severity component', true, 'results/calibration/severity_formula/severity_formula_manual_confirmation_record.csv', 'Numerical scenario inputs still uncertain.', 'Implemented.');
rows = f(rows, 'severity', 'LFOR exponential sum', true, true, 'paper_confirmed_exponential_sum', true, 'docs/severity_formula_confirmation_and_fix_report.md', 'Line loading basis scenario-dependent.', 'Implemented.');
rows = f(rows, 'severity', 'NVOR exponential sum', true, true, 'paper_confirmed_exponential_sum', true, 'docs/severity_formula_confirmation_and_fix_report.md', 'Voltage basis scenario-dependent.', 'Implemented.');
rows = f(rows, 'severity', 'CRI weights 0.6/0.2/0.2', true, true, 'weighted_sum', false, 'config/base_config.m', 'No current formula blocker.', 'Implemented.');
rows = f(rows, 'VaR', 'VaR sigma=0.95', true, true, 'empirical quantile diagnostic', false, 'config/base_config.m; results/calibration/full_event_formal_var_pilot_after_curve_fix/full_event_var_score_summary_after_curve_fix.csv', 'Not final while scenario assumptions missing.', 'VaR construction exists.');
T = cell2table(rows, 'VariableNames', {'formula_group','formula_item','paper_confirmed','implemented','implementation_mode','legacy_mode_retained','evidence_source','remaining_uncertainty','note'});
writetable(T, fullfile(out_dir, 'confirmed_formula_status_summary.csv'));
fprintf('Wrote confirmed_formula_status_summary.csv\n');
end

function rows = f(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir'), mkdir(pathname); end
end
