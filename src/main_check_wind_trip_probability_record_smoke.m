function main_check_wind_trip_probability_record_smoke()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'renewable_trip');
log_path = fullfile(out_dir, 'wind_trip_probability_record_smoke_check_log.txt');
ensure_dir(out_dir);
ok = true;
messages = strings(0, 1);

required = {
    fullfile(project_root, 'paper_inputs', 'filled', 'wind_trip_probability_formula.csv')
    fullfile(project_root, 'src', 'renewable', 'compute_wind_trip_probability_paper.m')
    fullfile(out_dir, 'wind_trip_probability_input_source_audit.csv')
    fullfile(out_dir, 'wind_trip_probability_dry_run_table.csv')
    fullfile(out_dir, 'wind_trip_record_smoke', 'wind_speed_11_28', 'wind_trip_probability_trace.csv')
    fullfile(out_dir, 'wind_trip_record_smoke', 'wind_speed_12_00', 'wind_trip_probability_trace.csv')
    fullfile(out_dir, 'wind_speed_wt_probability_smoke_summary.csv')
    fullfile(out_dir, 'wind_speed_wt_probability_delta.csv')
    fullfile(out_dir, 'post_wind_trip_probability_action.csv')
    };
for i = 1:numel(required)
    [ok, messages] = require_file(ok, messages, required{i});
end

dry_path = fullfile(out_dir, 'wind_trip_probability_dry_run_table.csv');
if exist(dry_path, 'file') == 2
    D = readtable(dry_path, 'TextType', 'string');
    if ~all(logical(D.pass_fail))
        ok = false;
        messages(end+1) = "dry_run_contains_failed_cases"; %#ok<AGROW>
    else
        messages(end+1) = "dry_run_all_passed"; %#ok<AGROW>
    end
    if any(string(D.source_status) == "original_paper_formula_extracted")
        ok = false;
        messages(end+1) = "interval_probability_mislabelled_as_original_paper_formula"; %#ok<AGROW>
    end
end

summary_path = fullfile(out_dir, 'wind_speed_wt_probability_smoke_summary.csv');
if exist(summary_path, 'file') == 2
    S = readtable(summary_path, 'TextType', 'string');
    if any(S.missing_input_count > 0)
        messages(end+1) = "warning_missing_voltage_frequency_inputs_present"; %#ok<AGROW>
    end
    if all(S.max_P_wt == 0)
        messages(end+1) = "P_WT_all_zero_in_current_wind_speed_smoke; model still valid by dry-run"; %#ok<AGROW>
    end
end

after_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
if exist(fullfile(after_root, 'local_search_results'), 'dir') == 7
    ok = false;
    messages(end+1) = "local_search_results_found_under_after_curve_fix_root"; %#ok<AGROW>
else
    messages(end+1) = "local_search_not_run_by_this_check"; %#ok<AGROW>
end
messages(end+1) = "final_summary_not_written_by_this_check=1"; %#ok<AGROW>
messages(end+1) = "after_curve_fix_formal_pilot_main_results_not_overwritten=1"; %#ok<AGROW>

fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'wind_trip_probability_record_smoke_check\ncheck_status=%s\n', ternary(ok, 'pass', 'fail'));
for i = 1:numel(messages)
    fprintf(fid, '%s\n', messages(i));
end
if ~ok
    error('wind trip probability record smoke check failed; see %s', log_path);
end
fprintf('wind trip probability record smoke check passed: %s\n', log_path);
end

function [ok, messages] = require_file(ok, messages, path)
if exist(path, 'file') ~= 2
    ok = false;
    messages(end+1) = "missing file: " + string(path);
else
    messages(end+1) = "found file: " + string(path);
end
end

function v = ternary(cond, a, b)
if cond, v = a; else, v = b; end
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
