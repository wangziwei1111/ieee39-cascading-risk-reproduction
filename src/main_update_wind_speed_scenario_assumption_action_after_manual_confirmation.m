function main_update_wind_speed_scenario_assumption_action_after_manual_confirmation()
%MAIN_UPDATE_WIND_SPEED_SCENARIO_ASSUMPTION_ACTION_AFTER_MANUAL_CONFIRMATION Write next action.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
ensure_dir(out_dir);

record_path = fullfile(out_dir, 'wind_speed_scenario_manual_confirmation_record.csv');
if isfile(record_path)
    R = readtable(record_path, 'TextType', 'string', 'Delimiter', ',');
    status = string(R.paper_dispatch_assumption_status(1));
else
    status = "not_stated_in_paper";
end

T = table( ...
    true, ...
    status, ...
    "baseflow_driven_probability_tail_under_current_wind_plus_redispatch", ...
    "run_baseflow_only_operating_point_sensitivity", ...
    "compare wind-speed base-case line loading and P_L under multiple plausible dispatch/absorption policies before any Markov rerun", ...
    "Paper confirms 12mps risk is lower than 11.28mps, but it does not state dispatch/absorption/curtailment/slack strategy. Current results only show the current engineering wind_plus_redispatch behavior; do not claim strict reproduction failure and do not tune parameters directly.", ...
    'VariableNames', {'selected','paper_dispatch_assumption_status','dominant_current_model_mechanism','go_no_go','recommended_next_action','note'});

writetable(T, fullfile(out_dir, 'post_wind_speed_scenario_assumption_action_v2.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'post_wind_speed_scenario_assumption_action_v2.csv'));
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir')
    mkdir(pathname);
end
end
