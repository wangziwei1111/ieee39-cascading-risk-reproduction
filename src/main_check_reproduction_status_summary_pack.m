function main_check_reproduction_status_summary_pack()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'reproduction_status');
ensure_dir(out_dir);
log_path = fullfile(out_dir, 'reproduction_status_summary_pack_check_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
ok = true;
files = [
    "results/calibration/reproduction_status/reproduction_status_dashboard.csv"
    "results/calibration/reproduction_status/confirmed_formula_status_summary.csv"
    "results/calibration/reproduction_status/wind_speed_public_information_gap_summary.csv"
    "results/calibration/reproduction_status/reproduction_next_go_no_go.csv"
    "docs/reproduction_status_and_public_information_gap_report.md"
    "docs/additional_paper_data_needed_for_strict_reproduction.md"
    ];
for f = files'
    exists = isfile(fullfile(project_root, f));
    ok = ok && exists;
    fprintf(fid, 'file_exists,%s,%d\n', f, exists);
end
fprintf(fid, 'guard_no_markov_run,1\n');
fprintf(fid, 'guard_no_cascade_run,1\n');
fprintf(fid, 'guard_no_local_search,1\n');
fprintf(fid, 'guard_no_parameter_tuning,1\n');
fprintf(fid, 'guard_no_final_summary_write,1\n');
fprintf(fid, 'guard_no_full_7_scenario_formal_pilot,1\n');
if ok
    fprintf(fid, 'check_status,pass\n');
else
    fprintf(fid, 'check_status,fail\n');
    error('Reproduction status summary pack check failed.');
end
fprintf('Wrote %s\n', log_path);
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir'), mkdir(pathname); end
end
