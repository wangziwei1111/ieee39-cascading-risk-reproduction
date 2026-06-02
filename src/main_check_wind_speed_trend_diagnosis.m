function main_check_wind_speed_trend_diagnosis()
%MAIN_CHECK_WIND_SPEED_TREND_DIAGNOSIS Check wind-speed trend diagnostic outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
files = ["wind_speed_scenario_config_audit.csv","wind_power_curve_speed_scan_audit.csv", ...
    "wind_speed_case_power_snapshot.csv","wind_trip_probability_speed_scan_audit.csv", ...
    "wind_speed_chain_risk_distribution_summary.csv","wind_speed_11_28_vs_12_00_distribution_delta.csv", ...
    "wind_speed_candidate_probability_summary.csv","wind_speed_branch_probability_delta.csv", ...
    "wind_speed_trend_root_cause_diagnosis.csv","post_wind_speed_diagnosis_action.csv", ...
    "post_wind_curve_fix_readiness.csv"];
log = strings(0,1); ok = true;
for f = files
    exists = isfile(fullfile(out_root, f));
    ok = ok && exists;
    log(end+1) = sprintf('%s exists=%d', f, exists); %#ok<AGROW>
end
if ok
    curve = readtable(fullfile(out_root, 'wind_power_curve_speed_scan_audit.csv'), 'TextType','string', 'Delimiter', ',');
    curve_ok = all(curve.match_status == "match");
    ok = ok && curve_ok;
    log(end+1) = sprintf('paper_2_12_20_curve_all_match=%d', curve_ok); %#ok<AGROW>

    snap = readtable(fullfile(out_root, 'wind_speed_case_power_snapshot.csv'), 'TextType','string', 'Delimiter', ',');
    pg11 = value_for(snap, "wind_speed_11_28", "actual_wind_pg_total_mw_in_case");
    pg12 = value_for(snap, "wind_speed_12_00", "actual_wind_pg_total_mw_in_case");
    pg_ok = abs(pg11 - 2489.38805581395) <= 1e-3 && abs(pg12 - 3000) <= 1e-6;
    ok = ok && pg_ok;
    log(end+1) = sprintf('paper_curve_case_pg_ok=%d; pg11=%.12g; pg12=%.12g', pg_ok, pg11, pg12); %#ok<AGROW>

    cfg_audit = readtable(fullfile(out_root, 'wind_speed_scenario_config_audit.csv'), 'TextType','string', 'Delimiter', ',');
    cfg_ok = all(cfg_audit.config_match_status == "match") && all(cfg_audit.wind_power_curve_profile == "paper_2_12_20");
    ok = ok && cfg_ok;
    log(end+1) = sprintf('scenario_config_paper_curve_profile_ok=%d', cfg_ok); %#ok<AGROW>

    readiness = readtable(fullfile(out_root, 'post_wind_curve_fix_readiness.csv'), 'TextType','string', 'Delimiter', ',');
    log(end+1) = sprintf('curve_fix_readiness_ready=%d; recommended_next_step=%s', ...
        logical(readiness.ready_for_full_event_formal_pilot_rerun(1)), string(readiness.recommended_next_step(1))); %#ok<AGROW>
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

function v = value_for(T, scenario_id, field_name)
idx = find(string(T.scenario_id) == scenario_id, 1);
if isempty(idx) || ~ismember(field_name, T.Properties.VariableNames)
    v = NaN;
else
    v = str2double(string(T.(field_name)(idx)));
end
end
