function main_check_wind_state_probability_model()
%MAIN_CHECK_WIND_STATE_PROBABILITY_MODEL Validate diagnostic P_WT/P_wt outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

log_path = fullfile(project_root, 'results', 'renewable', 'wind_state_probability_model_check_log.txt');
if ~exist(fileparts(log_path), 'dir'), mkdir(fileparts(log_path)); end
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

tracked_table = build_git_tracked_check(project_root);
tracked_path = fullfile(project_root, 'results', 'renewable', 'wind_state_git_tracked_check.csv');
writetable(tracked_table, tracked_path);
bad_tracked = ~logical(tracked_table.exists_on_disk) | ~logical(tracked_table.tracked_by_git);
tracked_check_status = "passed";
if any(bad_tracked)
    tracked_check_status = "failed";
end

must_exist(fullfile(project_root, 'src', 'renewable', 'compute_wind_trip_probability.m'));
must_exist(fullfile(project_root, 'src', 'renewable', 'compute_wind_state_probability.m'));
param_path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_wind_trip_probability_parameter_sets.csv');
must_exist(param_path);
params = readtable(param_path, 'TextType', 'string');
required_sets = ["strict_missing", "lvrt_hvrt_threshold_record", "diagnostic_linear_voltage_probability"];
for i = 1:numel(required_sets)
    if ~any(string(params.parameter_set_id) == required_sets(i))
        error('Missing wind trip parameter set: %s', required_sets(i));
    end
end
if any(string(params.parameter_set_id) == "strict_missing" & contains(string(params.calibration_status), "calibrated"))
    error('strict_missing must not be calibrated.');
end
if ~any(string(params.parameter_set_id) == "diagnostic_linear_voltage_probability" & ...
        string(params.calibration_status) == "diagnostic_assumption_not_paper")
    error('diagnostic_linear_voltage_probability must be diagnostic_assumption_not_paper.');
end

root = fullfile(project_root, 'results', 'renewable', 'wind_state_probability_diagnostic_smoke');
for i = 1:numel(required_sets)
    case_dir = fullfile(root, char(required_sets(i)));
    must_exist(fullfile(case_dir, 'markov_chain_summary.csv'));
    must_exist(fullfile(case_dir, 'wind_trip_probability_details.csv'));
    must_exist(fullfile(case_dir, 'wind_state_probability_stage_details.csv'));
    must_exist(fullfile(case_dir, 'wind_state_probability_summary.csv'));
end
must_exist(fullfile(project_root, 'results', 'renewable', 'wind_state_probability_effect_summary.csv'));

final_summary_dir = fullfile(project_root, 'results', 'final_summary');
if exist(fullfile(final_summary_dir, 'tables', 'wind_state_probability_effect_summary.csv'), 'file')
    error('Wind state diagnostic output must not be written to final_summary.');
end

fprintf(fid, 'wind_state_probability_model_check passed.\n');
fprintf(fid, 'tracked_check_status=%s\n', tracked_check_status);
fprintf(fid, 'tracked_check_table=%s\n', tracked_path);
fprintf(fid, 'required parameter sets: %s\n', strjoin(required_sets, ', '));
fprintf(fid, 'note: P_wt(E_k) remains diagnostic only and is not integrated into formal paper_formula.\n');
if tracked_check_status == "failed"
    missing = tracked_table.file_path(bad_tracked);
    fprintf(fid, 'untracked_or_missing_files=%s\n', strjoin(string(missing), '; '));
    error('Wind state probability tracked check failed; see %s', tracked_path);
end
fprintf('wind state probability model check passed: %s\n', log_path);
end

function must_exist(path)
if exist(path, 'file') ~= 2
    error('Required file missing: %s', path);
end
end

function tbl = build_git_tracked_check(project_root)
required_files = [
    "src/renewable/load_wind_trip_probability_parameter_set.m"
    "src/renewable/compute_wind_trip_probability.m"
    "src/renewable/compute_wind_state_probability.m"
    "src/renewable/record_wind_trip_probability.m"
    "src/renewable/flatten_wind_state_probability_records.m"
    "src/renewable/summarize_wind_state_probability_records.m"
    "src/main_run_wind_state_probability_diagnostic_smoke.m"
    "src/main_compare_wind_state_probability_effect.m"
    "src/main_check_wind_state_probability_model.m"
    "paper_inputs/filled/paper_wind_trip_probability_parameter_sets.csv"
    "paper_inputs/filled/paper_wind_frequency_ride_through_rules.csv"
    "docs/wind_state_probability_notes.md"
    ];
n = numel(required_files);
exists_on_disk = false(n, 1);
tracked_by_git = false(n, 1);
status = strings(n, 1);
note = strings(n, 1);
for i = 1:n
    rel = char(required_files(i));
    exists_on_disk(i) = exist(fullfile(project_root, rel), 'file') == 2;
    tracked_by_git(i) = is_git_tracked(project_root, rel);
    if exists_on_disk(i) && tracked_by_git(i)
        status(i) = "ok";
        note(i) = "file exists and is tracked by git";
    elseif exists_on_disk(i)
        status(i) = "untracked";
        note(i) = "file exists on disk but git ls-files did not return it";
    else
        status(i) = "missing";
        note(i) = "file is missing on disk";
    end
end
tbl = table(required_files, exists_on_disk, tracked_by_git, status, note, ...
    'VariableNames', {'file_path', 'exists_on_disk', 'tracked_by_git', 'status', 'note'});
end

function tracked = is_git_tracked(project_root, rel_path)
git = find_git_executable();
cmd = sprintf('"%s" -C "%s" ls-files -- "%s"', git, project_root, rel_path);
[status_code, output] = system(cmd);
tracked = status_code == 0 && strlength(strtrim(string(output))) > 0;
end

function git = find_git_executable()
candidates = ["E:\WPS\Git\cmd\git.exe", "git"];
for i = 1:numel(candidates)
    candidate = char(candidates(i));
    if strcmp(candidate, 'git') || exist(candidate, 'file') == 2
        git = candidate;
        return;
    end
end
git = 'git';
end
