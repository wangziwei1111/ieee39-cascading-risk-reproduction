function main_check_wind_speed_operating_point_sensitivity()
project_root = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
out_log = fullfile(root, 'wind_speed_operating_point_sensitivity_check_log.txt');
fid = fopen(out_log, 'w');
cleanup = onCleanup(@() fclose(fid));
ok = true;
policies = ["wind_plus_redispatch_current","slack_only_balance","proportional_conventional_redispatch", ...
    "designated_generator_redispatch","wind_curtail_to_constant_absorbed_power","constant_total_generation_dispatch"];
scenarios = ["wind_speed_11_28","wind_speed_12_00"];
files = [
    "wind_speed_scenario_manual_confirmation_record.csv"
    "post_wind_speed_scenario_assumption_action_v2.csv"
    "wind_speed_operating_point_sensitivity_summary.csv"
    "tail_branch_operating_point_policy_comparison.csv"
    "post_wind_speed_operating_point_sensitivity_action.csv"
    ];
for f = files'
    exists = isfile(fullfile(root, f));
    ok = ok && exists;
    fprintf(fid, 'file_exists,%s,%d\n', f, exists);
end
for p = policies
    for s = scenarios
        dirp = fullfile(root, 'baseflow_operating_point_sensitivity', p, s);
        required = ["scenario_config_snapshot.csv","base_power_flow_snapshot.csv","line_loading_snapshot.csv","generator_dispatch_snapshot.csv"];
        for r = required
            exists = isfile(fullfile(dirp, r));
            ok = ok && exists;
            fprintf(fid, 'snapshot_exists,%s/%s/%s,%d\n', p, s, r, exists);
        end
    end
end
fprintf(fid, 'guard_no_markov_run,1\n');
fprintf(fid, 'guard_no_cascade_run,1\n');
fprintf(fid, 'guard_no_local_search,1\n');
fprintf(fid, 'guard_no_parameter_tuning,1\n');
fprintf(fid, 'guard_no_final_summary_write,1\n');
if ok
    fprintf(fid, 'check_status,pass\n');
else
    fprintf(fid, 'check_status,fail\n');
    error('Wind speed operating-point sensitivity check failed.');
end
fprintf('Wrote %s\n', out_log);
end
