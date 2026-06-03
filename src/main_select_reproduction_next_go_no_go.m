function main_select_reproduction_next_go_no_go()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'reproduction_status');
ensure_dir(out_dir);
action_path = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption', 'post_wind_speed_operating_point_sensitivity_action.csv');
go = "pause_strict_reproduction_until_paper_operating_point_details_available";
reason = "Wind-speed scan remains opposite or unresolved while paper operating-point assumptions are not stated.";
if isfile(action_path)
    A = readtable(action_path, 'TextType', 'string', 'Delimiter', ',');
    if ~isempty(A) && string(A.go_no_go(1)) == "document_public_information_insufficient"
        go = "pause_strict_reproduction_until_paper_operating_point_details_available";
        reason = string(A.reason(1));
    end
end
T = table(true, go, reason, ...
    "Write staged reproduction report; organize confirmed formulas; document public information gap; optionally run non-strict sensitivity only with clear labels.", ...
    "local search; blind parameter tuning; treating sensitivity policy as paper-confirmed; directly rerunning full formal pilot as final benchmark", ...
    "Need Table 4-6 operating point details: generator PG, slack policy, curtailment, absorbed wind, baseflow/line loading, sample policy, and parameter-set sharing.", ...
    "Current results are diagnostic reproduction under public information constraints, not strict final reproduction.", ...
    'VariableNames', {'selected','go_no_go','reason','allowed_next_action','forbidden_next_action','required_user_input','note'});
writetable(T, fullfile(out_dir, 'reproduction_next_go_no_go.csv'));
fprintf('Wrote reproduction_next_go_no_go.csv\n');
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir'), mkdir(pathname); end
end
