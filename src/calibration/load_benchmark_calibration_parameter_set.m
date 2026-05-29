function cfg_out = load_benchmark_calibration_parameter_set(cfg_in, parameter_set_id)
%LOAD_BENCHMARK_CALIBRATION_PARAMETER_SET Load benchmark-calibration line probability parameters.
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
path = fullfile(project_root, 'paper_inputs', 'filled', 'benchmark_calibration_parameter_sets.csv');
if exist(path, 'file') ~= 2
    error('Missing benchmark calibration parameter set file: %s', path);
end

tbl = readtable(path, 'TextType', 'string');
row = tbl(tbl.parameter_set_id == string(parameter_set_id), :);
if isempty(row)
    error('Unknown benchmark calibration parameter_set_id: %s', string(parameter_set_id));
end

calibration_status = string(row.calibration_status(1));
if contains(calibration_status, "benchmark_calibrated") && ~contains(calibration_status, "not_original_paper")
    error('benchmark_calibrated parameter sets must include not_original_paper in calibration_status.');
end
if calibration_status == "original_paper_extracted"
    error('Reverse-calibration parameter sets must not be marked original_paper_extracted.');
end

cfg_out = cfg_in;
cfg_out.line_outage_probability_model = 'paper_formula';
cfg_out.paper_line_parameter_set_id = char(row.parameter_set_id(1));
cfg_out.paper_line_parameter_calibration_status = char(calibration_status);
cfg_out.paper_line_missing_param_policy = 'return_nan';
cfg_out.paper_line_P_L0_source = 'table4_1_initial_probability';
cfg_out.paper_line_P_L0_by_branch = load_table41_initial_probabilities(project_root);

cfg_out.paper_line_P_W_D = get_numeric(row, 'P_W_D');
cfg_out.paper_line_P_L_D = get_numeric(row, 'P_L_D');
cfg_out.paper_line_P_L_r = get_numeric(row, 'P_L_r');
cfg_out.paper_line_P_in_r = get_numeric(row, 'P_in_r');
cfg_out.paper_line_P_in_c = get_numeric(row, 'P_in_c');
cfg_out.paper_line_P_mis_c = get_numeric(row, 'P_mis_c');
cfg_out.paper_line_P3 = get_numeric(row, 'P3');
cfg_out.paper_line_L_rated_factor = get_numeric(row, 'L_rated_factor');
cfg_out.paper_line_L_max_factor = get_numeric(row, 'L_max_factor');
cfg_out.paper_line_ZIII_factor = get_numeric(row, 'ZIII_factor');
cfg_out.calibration_distance_hidden_failure_mode = char(row.distance_hidden_failure_mode(1));
end

function value = get_numeric(row, field_name)
if ~ismember(field_name, row.Properties.VariableNames)
    value = NaN;
    return;
end
value = row.(field_name)(1);
if ismissing(value)
    value = NaN;
end
end

function values = load_table41_initial_probabilities(project_root)
path = fullfile(project_root, 'data', 'line_initial_outage_probability_paper_table_4_1.csv');
tbl = readtable(path);
values = NaN(max(tbl.branch_index), 1);
values(tbl.branch_index) = tbl.initial_outage_probability;
end
