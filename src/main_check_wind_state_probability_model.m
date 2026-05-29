function main_check_wind_state_probability_model()
%MAIN_CHECK_WIND_STATE_PROBABILITY_MODEL Validate diagnostic P_WT/P_wt outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

log_path = fullfile(project_root, 'results', 'renewable', 'wind_state_probability_model_check_log.txt');
if ~exist(fileparts(log_path), 'dir'), mkdir(fileparts(log_path)); end
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

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
fprintf(fid, 'required parameter sets: %s\n', strjoin(required_sets, ', '));
fprintf(fid, 'note: P_wt(E_k) remains diagnostic only and is not integrated into formal paper_formula.\n');
fprintf('wind state probability model check passed: %s\n', log_path);
end

function must_exist(path)
if exist(path, 'file') ~= 2
    error('Required file missing: %s', path);
end
end
