function main_build_wind_speed_public_information_gap_summary()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'reproduction_status');
ensure_dir(out_dir);
rows = {};
rows = g(rows, 'conventional_generator_dispatch_between_11p28_and_12mps', 'not_stated_in_paper', 'wind_plus_redispatch_current plus sensitivity policies; none paper-confirmed', 'Can flip baseflow and P_L tail direction.', true, 'Provide conventional generator PG or dispatch rule for Table 4-6.', 'Primary blocker.');
rows = g(rows, 'slack_bus_policy', 'not_stated_in_paper', 'bus31 slack in current model; slack_only_balance sensitivity tested', 'Slack behavior changes flow distribution.', true, 'Confirm slack/power-balance rule.', 'Do not infer from case39 alone.');
rows = g(rows, 'wind_curtailment_policy', 'not_stated_in_paper', 'No curtailment in current implementation; constant absorbed power sensitivity tested', 'Curtailment could suppress 12mps stress.', true, 'Confirm whether 12mps wind is curtailed or fully absorbed.', 'Current no-curtailment is not paper-confirmed.');
rows = g(rows, 'wind_absorbed_power_at_each_speed', 'partially_known_from_current_curve_not_paper_dispatch', '2489.388 MW at 11.28 and 3000 MW at 12.00 under current curve/full absorption', 'Actual absorption determines conventional redispatch amount.', true, 'Provide actual absorbed wind PG values if paper/model has them.', 'Curve output is known; absorbed output is not explicitly stated.');
rows = g(rows, 'base_power_flow_at_each_speed', 'not_stated_in_paper', 'Computed under diagnostic policies only', 'Strict reproduction needs the same operating point.', true, 'Provide base power-flow snapshot for Table 4-6.', 'Current sensitivity is not final evidence.');
rows = g(rows, 'branch_loading_at_each_speed', 'not_stated_in_paper', 'Derived from current/sensitivity PF only', 'P_L and LFOR depend on loading.', true, 'Provide branch loading table or CloudPSS case.', 'Dominant tail branch mismatch remains unresolved.');
rows = g(rows, 'generator_PG_table_at_each_speed', 'not_stated_in_paper', 'Generated for sensitivity policies only', 'Dispatch directly changes line loading.', true, 'Provide generator PG table for 11.28 and 12.00 m/s.', 'Most actionable missing table.');
rows = g(rows, 'whether_wind_speed_scan_uses_fixed_random_chains', 'not_stated_in_paper', 'Current diagnostics used pairable/common comparison where available', 'Sampling uncertainty affects trend confidence.', false, 'Confirm Monte Carlo sample policy if stated.', 'Less important than baseflow, but needed for strict reproducibility.');
rows = g(rows, 'whether_wind_trip_probability_changes_with_wind_speed', 'not_stated_in_paper', 'P_wt diagnostic exists but current Markov wind voltages do not trigger trip probability', 'Could explain decreasing risk if used differently in paper.', true, 'Provide P_WT wind-speed/state transition assumptions.', 'Do not assert P_wt explains the trend.');
rows = g(rows, 'whether Table 4-6 uses same parameter set as other tables', 'not_stated_in_paper', 'Current diagnostics keep formula/parameters consistent', 'Different table-specific parameters could change risk.', true, 'Confirm whether Table 4-6 shares outage/protection parameters.', 'Do not tune parameters table-by-table without evidence.');
T = cell2table(rows, 'VariableNames', {'information_item','paper_status','current_implementation','effect_on_reproduction','required_to_strictly_reproduce','recommended_user_action','note'});
writetable(T, fullfile(out_dir, 'wind_speed_public_information_gap_summary.csv'));
fprintf('Wrote wind_speed_public_information_gap_summary.csv\n');
end

function rows = g(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir'), mkdir(pathname); end
end
