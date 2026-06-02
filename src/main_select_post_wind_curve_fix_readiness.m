function main_select_post_wind_curve_fix_readiness()
%MAIN_SELECT_POST_WIND_CURVE_FIX_READINESS Decide readiness after dry-run curve fix.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
curve = readtable(fullfile(out_root, 'wind_power_curve_speed_scan_audit.csv'), 'TextType','string', 'Delimiter', ',');
snap = readtable(fullfile(out_root, 'wind_speed_case_power_snapshot.csv'), 'TextType','string', 'Delimiter', ',');
cfg_audit = readtable(fullfile(out_root, 'wind_speed_scenario_config_audit.csv'), 'TextType','string', 'Delimiter', ',');
trip = readtable(fullfile(out_root, 'wind_trip_probability_speed_scan_audit.csv'), 'TextType','string', 'Delimiter', ',');

blocking = 0;
warning = 0;
if all(curve.match_status == "match")
    wind_curve_status = "pass";
else
    wind_curve_status = "mismatch";
    blocking = blocking + 1;
end

pg11 = value_for(snap, "wind_speed_11_28", "actual_wind_pg_total_mw_in_case");
pg12 = value_for(snap, "wind_speed_12_00", "actual_wind_pg_total_mw_in_case");
case_pg_ok = abs(pg11 - 2489.38805581395) <= 1e-3 && abs(pg12 - 3000) <= 1e-6 && pg11 < pg12;
if case_pg_ok
    case_pg_status = "pass";
else
    case_pg_status = "mismatch";
    blocking = blocking + 1;
end

if all(cfg_audit.config_match_status == "match")
    scenario_config_status = "pass";
else
    scenario_config_status = "blocking";
    blocking = blocking + 1;
end

if any(logical(trip.wind_trip_probability_available))
    wind_trip_probability_status = "available";
else
    wind_trip_probability_status = "missing_warning";
    warning = warning + 1;
end

if blocking > 0
    ready = false;
    if wind_curve_status ~= "pass"
        next = "fix_wind_power_curve";
    elseif case_pg_status ~= "pass"
        next = "fix_wind_speed_case_builder";
    else
        next = "fix_wind_speed_scenario_config";
    end
else
    ready = true;
    if warning > 0
        next = "rerun_full_event_formal_pilot_after_curve_fix_with_wind_trip_warning";
    else
        next = "rerun_full_event_formal_pilot_after_curve_fix";
    end
end

note = "Readiness only; this script does not rerun formal pilot, local search, Markov, or final_summary.";
T = table(ready, wind_curve_status, case_pg_status, scenario_config_status, wind_trip_probability_status, ...
    blocking, warning, next, note, ...
    'VariableNames', {'ready_for_full_event_formal_pilot_rerun','wind_curve_status','case_pg_status', ...
    'scenario_config_status','wind_trip_probability_status','blocking_issue_count','warning_issue_count', ...
    'recommended_next_step','note'});
writetable(T, fullfile(out_root, 'post_wind_curve_fix_readiness.csv'));
end

function v = value_for(T, scenario_id, field_name)
idx = find(string(T.scenario_id) == scenario_id, 1);
if isempty(idx) || ~ismember(field_name, T.Properties.VariableNames)
    v = NaN;
else
    v = str2double(string(T.(field_name)(idx)));
end
end
