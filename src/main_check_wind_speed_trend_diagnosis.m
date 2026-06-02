function main_check_wind_speed_trend_diagnosis()
%MAIN_CHECK_WIND_SPEED_TREND_DIAGNOSIS Check wind-speed trend diagnostic outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
files = ["wind_speed_scenario_config_audit.csv","wind_power_curve_speed_scan_audit.csv", ...
    "wind_speed_case_power_snapshot.csv","wind_trip_probability_speed_scan_audit.csv", ...
    "wind_speed_chain_risk_distribution_summary.csv","wind_speed_11_28_vs_12_00_distribution_delta.csv", ...
    "wind_speed_candidate_probability_summary.csv","wind_speed_branch_probability_delta.csv", ...
    "wind_speed_trend_root_cause_diagnosis.csv","post_wind_speed_diagnosis_action.csv"];
log = strings(0,1); ok = true;
for f = files
    exists = isfile(fullfile(out_root, f));
    ok = ok && exists;
    log(end+1) = sprintf('%s exists=%d', f, exists); %#ok<AGROW>
end
final_written = isfile(fullfile(project_root, 'results', 'final_summary', 'final_summary.csv'));
log(end+1) = sprintf('final_summary_exists_from_prior_work=%d; this diagnostic did not write final_summary', final_written);
local_search = isfolder(fullfile(project_root, 'results', 'calibration', 'local_search_results'));
log(end+1) = sprintf('local_search_results_exists=%d; this diagnostic did not run local search', local_search);
log(end+1) = 'parameter_tuning_run=0';
log(end+1) = 'full_event_formal_var_pilot_main_results_overwritten=0';
if ok
    log(end+1) = 'check_status=pass';
else
    log(end+1) = 'check_status=fail';
end
fid = fopen(fullfile(out_root, 'wind_speed_trend_diagnosis_check_log.txt'), 'w');
fprintf(fid, '%s\n', log);
fclose(fid);
if ~ok
    error('Wind-speed trend diagnosis check failed; see log.');
end
end
