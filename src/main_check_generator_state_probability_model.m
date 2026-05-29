function main_check_generator_state_probability_model()
%MAIN_CHECK_GENERATOR_STATE_PROBABILITY_MODEL Validate diagnostic P_G/P_ge outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

log_path = fullfile(project_root, 'results', 'generator', 'generator_state_probability_model_check_log.txt');
if ~exist(fileparts(log_path), 'dir'), mkdir(fileparts(log_path)); end
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

required_sources = [
    "src/generator/load_generator_outage_probability_parameter_set.m"
    "src/generator/compute_generator_outage_probability.m"
    "src/generator/identify_traditional_generators.m"
    "src/generator/compute_generator_state_probability.m"
    "src/generator/record_generator_outage_probability.m"
    "src/generator/flatten_generator_state_probability_records.m"
    "src/generator/summarize_generator_state_probability_records.m"
    "src/main_test_generator_outage_probability_model.m"
    "src/main_run_generator_voltage_frequency_stress_diagnostic.m"
    "src/main_run_generator_state_probability_diagnostic_smoke.m"
    "src/main_scan_markov_generator_voltage_ranges.m"
    "src/main_compare_generator_state_probability_effect.m"
    "src/main_check_generator_state_probability_model.m"
    ];
for i = 1:numel(required_sources)
    must_exist(fullfile(project_root, required_sources(i)));
end

param_path = fullfile(project_root, 'paper_inputs', 'filled', ...
    'paper_generator_outage_probability_parameter_sets.csv');
must_exist(param_path);
params = readtable(param_path, 'TextType', 'string');
required_sets = ["strict_missing", "paper_formula_structure_only", "diagnostic_voltage_frequency_probability"];
for i = 1:numel(required_sets)
    if ~any(string(params.parameter_set_id) == required_sets(i))
        error('Missing generator outage parameter set: %s', required_sets(i));
    end
end
if any(string(params.parameter_set_id) == "strict_missing" & contains(string(params.calibration_status), "calibrated"))
    error('strict_missing must not be calibrated.');
end
if ~any(string(params.parameter_set_id) == "diagnostic_voltage_frequency_probability" & ...
        string(params.calibration_status) == "diagnostic_assumption_not_paper")
    error('diagnostic_voltage_frequency_probability must be diagnostic_assumption_not_paper.');
end

root = fullfile(project_root, 'results', 'generator', 'generator_state_probability_diagnostic_smoke');
for i = 1:numel(required_sets)
    case_dir = fullfile(root, char(required_sets(i)));
    must_exist(fullfile(case_dir, 'markov_chain_summary.csv'));
    must_exist(fullfile(case_dir, 'generator_trip_probability_details.csv'));
    must_exist(fullfile(case_dir, 'generator_state_probability_stage_details.csv'));
    must_exist(fullfile(case_dir, 'generator_state_probability_summary.csv'));
end
must_exist(fullfile(project_root, 'results', 'generator', 'generator_outage_probability_unit_test.csv'));
must_exist(fullfile(project_root, 'results', 'generator', 'generator_voltage_frequency_stress_diagnostic.csv'));
must_exist(fullfile(project_root, 'results', 'generator', 'markov_generator_voltage_frequency_range_summary.csv'));
must_exist(fullfile(project_root, 'results', 'generator', 'markov_generator_threshold_hits.csv'));
must_exist(fullfile(project_root, 'results', 'generator', 'generator_state_probability_effect_summary.csv'));

final_summary_probe = fullfile(project_root, 'results', 'final_summary', 'tables', ...
    'generator_state_probability_effect_summary.csv');
if exist(final_summary_probe, 'file') == 2
    error('Generator state diagnostic output must not be written to final_summary.');
end

unit_tbl = readtable(fullfile(project_root, 'results', 'generator', 'generator_outage_probability_unit_test.csv'), ...
    'TextType', 'string');
stress_tbl = readtable(fullfile(project_root, 'results', 'generator', 'generator_voltage_frequency_stress_diagnostic.csv'), ...
    'TextType', 'string');
if any(unit_tbl.test_status == "fail")
    error('Generator outage probability unit test contains failures.');
end
missing_mask = ismember(unit_tbl.parameter_set_id, ["strict_missing", "paper_formula_structure_only"]);
bad_region = missing_mask & (contains(unit_tbl.voltage_region, "forced_") | contains(unit_tbl.frequency_region, "forced_"));
if any(bad_region)
    error('Missing generator parameter sets must not report forced voltage/frequency regions.');
end
if any(stress_tbl.test_status == "fail")
    error('Generator voltage/frequency stress diagnostic contains failures.');
end

fprintf(fid, 'generator_state_probability_model_check passed.\n');
fprintf(fid, 'required parameter sets: %s\n', strjoin(required_sets, ', '));
fprintf(fid, 'note: P_ge(E_k) remains diagnostic only and is not integrated into formal paper_formula.\n');
fprintf(fid, 'missing_region_check=passed\n');
fprintf(fid, 'note: static power flow has no dynamic frequency; nominal frequency is used for diagnostics only.\n');
fprintf('generator state probability model check passed: %s\n', log_path);
end

function must_exist(path)
if exist(path, 'file') ~= 2
    error('Required file missing: %s', path);
end
end
