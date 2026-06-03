function main_build_wind_speed_scenario_next_step_branch_plan()
%MAIN_BUILD_WIND_SPEED_SCENARIO_NEXT_STEP_BRANCH_PLAN Write decision branch plan.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
ensure_dir(out_dir);
rows = {};
rows = add(rows, 'user_confirms_current_dispatch_assumption', 'Current model wind-speed scenario assumption matches the paper, but direction remains opposite.', 'increase wind-speed-only trials with confirmed formulas, then document diagnostic divergence if still opposite', 'local search before trend issue is addressed', 'none', 'wind-speed-only diagnostic rerun with more trials after confirmation', 'Still not a full formal pilot until trend and uncertainty are documented.');
rows = add(rows, 'user_confirms_specific_conventional_generator_redispatch', 'Current engineering dispatch assumption differs from paper.', 'implement paper-confirmed redispatch mode and run wind-speed-only diagnostic rerun', 'parameter tuning to mask dispatch mismatch', 'scenario builder redispatch policy', 'compare base PG/line loading before Markov', 'Keep the new mode named paper-confirmed or diagnostic depending source strength.');
rows = add(rows, 'user_confirms_wind_curtailment_or_fixed_wind_absorption', 'Paper limits absorbed wind or curtails at one or more wind speeds.', 'implement paper-confirmed wind curtailment/absorption mode and run wind-speed-only diagnostic rerun', 'using current no-curtailment result as Table 4-6 reproduction', 'wind scenario construction and wind PG application', 'case power snapshot and base-flow comparison', 'Do not alter public wind curve; only absorption/curtailment policy changes if confirmed.');
rows = add(rows, 'user_confirms_slack_bus_policy_different', 'Paper power-balance policy differs from current slack/redispatch setup.', 'implement paper-confirmed slack/power-balance policy and run wind-speed-only diagnostic rerun', 'continuing with unconfirmed slack behavior', 'scenario builder balance policy', 'slack PG and conventional PG audit', 'May require exact PG table or OPF setting.');
rows = add(rows, 'user_says_paper_does_not_state_dispatch_assumption', 'Public paper information is insufficient to identify dispatch/absorption assumption.', 'keep current assumption as diagnostic assumption; document uncertainty; optionally run sensitivity cases but not claim strict reproduction', 'strict reproduction claim or local search framed as paper parameters', 'none unless sensitivity is explicitly requested', 'dispatch sensitivity pack only after user approval', 'Use conservative language in reports.');
rows = add(rows, 'user_provides_base_case_power_flow_or_generator_PG_table', 'Exact paper operating point can be reconstructed or matched.', 'implement exact base case PG / dispatch and rerun wind-speed-only diagnostic', 'guessing redispatch rule despite exact table', 'case builder PG initialization and validation table', 'base-flow validation before any cascade run', 'This is the cleanest path to resolve the trend.');
T = cell2table(rows, 'VariableNames', {'confirmation_outcome','interpretation','allowed_next_step','forbidden_next_step','required_code_change','required_diagnostic','note'});
writetable(T, fullfile(out_dir, 'wind_speed_scenario_next_step_branch_plan.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'wind_speed_scenario_next_step_branch_plan.csv'));
end

function rows = add(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir')
    mkdir(pathname);
end
end
