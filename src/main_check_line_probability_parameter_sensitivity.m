function main_check_line_probability_parameter_sensitivity()
%MAIN_CHECK_LINE_PROBABILITY_PARAMETER_SENSITIVITY Check P_L parameter sensitivity outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_root = fullfile(project_root, 'results', 'outage');
param_path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_line_probability_parameter_sets.csv');
curve_path = fullfile(out_root, 'line_probability_curve_samples.csv');
sens_path = fullfile(out_root, 'line_probability_parameter_sensitivity.csv');
detail_path = fullfile(out_root, 'line_probability_candidate_sensitivity_details.csv');
smoke_path = fullfile(out_root, 'line_probability_parameter_smoke_summary.csv');
log_path = fullfile(out_root, 'line_probability_parameter_sensitivity_check_log.txt');

must_exist(param_path); must_exist(curve_path); must_exist(sens_path);
must_exist(detail_path); must_exist(smoke_path);
must_exist(fullfile(out_root, 'figures', 'line_probability_curves_by_parameter_set.png'));

params = readtable(param_path, 'TextType', 'string');
required = ["strict_missing"; "table41_P_L0_only"; ...
    "low_hidden_failure_diagnostic"; "medium_hidden_failure_diagnostic"];
for i = 1:numel(required)
    if ~any(params.parameter_set_id == required(i))
        error('Missing parameter set: %s', required(i));
    end
end
diag_rows = params(params.parameter_set_type == "diagnostic", :);
if any(diag_rows.calibration_status == "calibrated")
    error('Diagnostic parameter sets must not be calibrated.');
end

curve = readtable(curve_path, 'TextType', 'string');
sens = readtable(sens_path, 'TextType', 'string');
smoke = readtable(smoke_path, 'TextType', 'string');
if isempty(curve) || isempty(sens) || isempty(smoke)
    error('Sensitivity outputs must not be empty.');
end
strict = smoke(smoke.parameter_set_id == "strict_missing", :);
if ~isempty(strict) && any(strict.recommendation ~= "not_usable_missing_parameters")
    error('strict_missing must not be treated as usable calibrated model.');
end
if any(smoke.calibration_status == "calibrated_for_paper")
    error('No parameter set may be marked calibrated_for_paper in this diagnostic stage.');
end

fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'line probability parameter sensitivity check passed\n');
fprintf(fid, 'parameter_set_count=%d\n', height(params));
fprintf(fid, 'curve_rows=%d\n', height(curve));
fprintf(fid, 'sensitivity_rows=%d\n', height(sens));
fprintf(fid, 'smoke_rows=%d\n', height(smoke));
fprintf(fid, 'note=All diagnostic parameter sets remain diagnostic-only and are not written to final_summary.\n');
fprintf('line probability parameter sensitivity check passed: %s\n', log_path);
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file missing: %s', path);
end
end
