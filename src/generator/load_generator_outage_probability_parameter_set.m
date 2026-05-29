function cfg_out = load_generator_outage_probability_parameter_set(cfg_in, parameter_set_id)
%LOAD_GENERATOR_OUTAGE_PROBABILITY_PARAMETER_SET Load diagnostic P_G(q) parameter set.
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
param_path = fullfile(project_root, 'paper_inputs', 'filled', ...
    'paper_generator_outage_probability_parameter_sets.csv');
if exist(param_path, 'file') ~= 2
    error('Generator outage probability parameter set file missing: %s', param_path);
end

tbl = readtable(param_path, 'TextType', 'string');
mask = string(tbl.parameter_set_id) == string(parameter_set_id);
if ~any(mask)
    error('Unknown generator outage probability parameter_set_id: %s', parameter_set_id);
end
row = tbl(find(mask, 1), :);

cfg_out = cfg_in;
cfg_out.generator_trip_parameter_set_id = char(row.parameter_set_id(1));
cfg_out.gen_trip_parameter_calibration_status = char(row.calibration_status(1));
curve_type = string(row.probability_curve_type(1));
switch curve_type
    case "missing"
        cfg_out.generator_outage_probability_model = 'paper_formula';
    case "paper_formula_structure_only"
        cfg_out.generator_outage_probability_model = 'paper_threshold_record';
    case "diagnostic_linear_voltage_frequency"
        cfg_out.generator_outage_probability_model = 'diagnostic_voltage_frequency_piecewise';
    otherwise
        error('Unsupported generator probability_curve_type: %s', curve_type);
end

cfg_out.gen_trip_low_voltage_forced_pu = keep_or_nan(row.low_voltage_forced_pu(1));
cfg_out.gen_trip_low_voltage_start_pu = keep_or_nan(row.low_voltage_start_pu(1));
cfg_out.gen_trip_high_voltage_start_pu = keep_or_nan(row.high_voltage_start_pu(1));
cfg_out.gen_trip_high_voltage_forced_pu = keep_or_nan(row.high_voltage_forced_pu(1));
cfg_out.gen_trip_low_frequency_forced_hz = keep_or_nan(row.low_frequency_forced_hz(1));
cfg_out.gen_trip_low_frequency_start_hz = keep_or_nan(row.low_frequency_start_hz(1));
cfg_out.gen_trip_high_frequency_start_hz = keep_or_nan(row.high_frequency_start_hz(1));
cfg_out.gen_trip_high_frequency_forced_hz = keep_or_nan(row.high_frequency_forced_hz(1));

if contains(string(cfg_out.gen_trip_parameter_calibration_status), "calibrated") && ...
        contains(string(row.parameter_set_type(1)), "diagnostic")
    error('Diagnostic generator parameter set must not be marked calibrated.');
end
end

function value = keep_or_nan(value_in)
if ismissing(value_in) || (isstring(value_in) && strlength(strtrim(value_in)) == 0)
    value = NaN;
else
    value = double(value_in);
end
end
