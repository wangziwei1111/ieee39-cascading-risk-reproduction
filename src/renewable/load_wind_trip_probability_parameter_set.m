function cfg_out = load_wind_trip_probability_parameter_set(cfg_in, parameter_set_id)
%LOAD_WIND_TRIP_PROBABILITY_PARAMETER_SET Load diagnostic P_WT(h) parameter set.
% This loader copies only explicitly listed values from paper_inputs/filled.
% Missing values remain NaN or empty; no thesis parameter is invented here.
cfg_out = cfg_in;
project_root = find_project_root();
path = fullfile(project_root, 'paper_inputs', 'filled', 'paper_wind_trip_probability_parameter_sets.csv');
if ~exist(path, 'file')
    error('Wind trip parameter set file not found: %s', path);
end
tbl = readtable(path, 'TextType', 'string');
row = tbl(string(tbl.parameter_set_id) == string(parameter_set_id), :);
if height(row) ~= 1
    error('Expected exactly one wind trip parameter set "%s", found %d.', string(parameter_set_id), height(row));
end

cfg_out.wind_trip_parameter_set_id = char(row.parameter_set_id(1));
cfg_out.wind_trip_parameter_calibration_status = char(row.calibration_status(1));
cfg_out.wind_frequency_rule_file = char(row.frequency_rule_source(1));

curve_type = string(row.probability_curve_type(1));
switch curve_type
    case "missing"
        cfg_out.wind_trip_probability_model = 'paper_formula';
    case "threshold_record_only"
        cfg_out.wind_trip_probability_model = 'paper_threshold_record';
    case {"diagnostic_linear_voltage", "diagnostic_linear_voltage_probability"}
        cfg_out.wind_trip_probability_model = 'diagnostic_voltage_piecewise';
    otherwise
        error('Unknown wind probability curve type: %s', curve_type);
end

cfg_out.wind_trip_low_voltage_forced_pu = keep_or_nan(row.low_voltage_forced_pu(1));
cfg_out.wind_trip_low_voltage_start_pu = keep_or_nan(row.low_voltage_start_pu(1));
cfg_out.wind_trip_high_voltage_start_pu = keep_or_nan(row.high_voltage_start_pu(1));
cfg_out.wind_trip_high_voltage_forced_pu = keep_or_nan(row.high_voltage_forced_pu(1));
cfg_out.wind_trip_low_voltage_trip_pu = cfg_out.wind_trip_low_voltage_forced_pu;
cfg_out.wind_trip_high_voltage_trip_pu = cfg_out.wind_trip_high_voltage_forced_pu;
end

function value = keep_or_nan(raw)
if ismissing(raw)
    value = NaN;
else
    value = double(raw);
end
end

function project_root = find_project_root()
project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
