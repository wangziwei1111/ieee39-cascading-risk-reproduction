function main_test_wind_trip_probability_model()
%MAIN_TEST_WIND_TRIP_PROBABILITY_MODEL Unit test diagnostic P_WT(h) models.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'renewable');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

cfg0 = base_config();
parameter_sets = ["strict_missing", "lvrt_hvrt_threshold_record", "diagnostic_linear_voltage_probability"];
voltages = [0.10, 0.20, 0.55, 0.90, 1.00, 1.10, 1.20, 1.30, 1.40]';
frequency = 50.0;
rows = {};
for p = 1:numel(parameter_sets)
    cfg = load_wind_trip_probability_parameter_set(cfg0, parameter_sets(p));
    [prob, detail] = compute_wind_trip_probability(voltages, repmat(frequency, size(voltages)), cfg);
    for i = 1:numel(voltages)
        [expected, pass] = expected_behavior(parameter_sets(p), voltages(i), prob(i), string(detail(i).status), cfg);
        test_status = "pass";
        if ~pass
            test_status = "fail";
        end
        rows{end+1,1} = table(parameter_sets(p), voltages(i), frequency, prob(i), ...
            string(detail(i).voltage_region), string(detail(i).frequency_region), ...
            logical(detail(i).threshold_hit), string(detail(i).status), ...
            string(detail(i).calibration_status), string(expected), test_status, ...
            'VariableNames', {'parameter_set_id', 'wind_voltage_pu', 'wind_frequency_hz', ...
            'p_wt_h', 'voltage_region', 'frequency_region', 'threshold_hit', ...
            'probability_status', 'calibration_status', 'expected_behavior', 'test_status'}); %#ok<AGROW>
    end
end
tbl = vertcat(rows{:});
writetable(tbl, fullfile(out_dir, 'wind_trip_probability_unit_test.csv'));
if any(tbl.test_status == "fail")
    error('Wind trip probability unit test failed.');
end
fprintf('wind trip probability unit test written.\n');
end

function [text, pass] = expected_behavior(parameter_set_id, v, p, status, cfg)
tol = 1e-9;
parameter_set_id = string(parameter_set_id);
if parameter_set_id == "strict_missing"
    text = "strict missing returns NaN and is not calibrated";
    pass = isnan(p) && status == "missing_paper_probability_function" && ...
        string(cfg.wind_trip_parameter_calibration_status) ~= "calibrated";
elseif parameter_set_id == "lvrt_hvrt_threshold_record"
    if v < 0.90 || v > 1.10
        text = "threshold hit returns NaN because paper probability function is missing";
        pass = isnan(p) && status == "threshold_hit_probability_missing";
    else
        text = "normal voltage threshold record returns zero";
        pass = abs(p) <= tol && status == "threshold_not_hit";
    end
else
    expected = diagnostic_expected(v);
    text = sprintf('diagnostic piecewise expected %.12g', expected);
    pass = abs(p - expected) <= 1e-8 && status == "diagnostic_assumption_not_paper";
end
end

function p = diagnostic_expected(v)
if v <= 0.20
    p = 1;
elseif v < 0.90
    p = (0.90 - v) / (0.90 - 0.20);
elseif v <= 1.10
    p = 0;
elseif v < 1.30
    p = (v - 1.10) / (1.30 - 1.10);
else
    p = 1;
end
end
