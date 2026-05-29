function main_run_wind_trip_voltage_stress_diagnostic()
%MAIN_RUN_WIND_TRIP_VOLTAGE_STRESS_DIAGNOSTIC Artificial voltage stress test.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'renewable');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

cfg = load_wind_trip_probability_parameter_set(base_config(), 'diagnostic_linear_voltage_probability');
wind_buses = (30:39)';
cases = build_stress_cases(wind_buses);
rows = {};
for c = 1:numel(cases)
    v = cases(c).voltage;
    [p, detail] = compute_wind_trip_probability(v, repmat(50.0, size(v)), cfg);
    wind_trip_table = table((1:numel(wind_buses))', wind_buses, v, p, p, ...
        strings(numel(wind_buses),1), strings(numel(wind_buses),1), false(numel(wind_buses),1), ...
        'VariableNames', {'wind_index', 'wind_bus', 'voltage_pu', 'p_wt_h', ...
        'trip_probability', 'trip_region', 'probability_status', 'record_only'});
    for i = 1:numel(wind_buses)
        wind_trip_table.trip_region(i) = string(detail(i).voltage_region);
        wind_trip_table.probability_status(i) = string(detail(i).status);
    end
    [p_wt_Ek, state_detail] = compute_wind_state_probability(wind_trip_table, cfg);
    [expected, case_pass] = expected_case(cases(c).name, p_wt_Ek);
    for i = 1:numel(wind_buses)
        test_status = "pass";
        if ~case_pass
            test_status = "fail";
        end
        rows{end+1,1} = table(string(cases(c).name), wind_buses(i), v(i), p(i), ...
            string(detail(i).voltage_region), string(detail(i).status), ...
            p_wt_Ek, state_detail.num_probability_positive, state_detail.max_p_wt_h, ...
            state_detail.mean_p_wt_h, string(expected), test_status, ...
            'VariableNames', {'stress_case', 'wind_bus', 'wind_voltage_pu', ...
            'p_wt_h', 'voltage_region', 'probability_status', 'p_wt_Ek', ...
            'num_probability_positive', 'max_p_wt_h', 'mean_p_wt_h', ...
            'expected_behavior', 'test_status'}); %#ok<AGROW>
    end
end
tbl = vertcat(rows{:});
writetable(tbl, fullfile(out_dir, 'wind_trip_voltage_stress_diagnostic.csv'));
if any(tbl.test_status == "fail")
    error('Wind trip voltage stress diagnostic failed.');
end
fprintf('wind trip voltage stress diagnostic written.\n');
end

function cases = build_stress_cases(wind_buses)
n = numel(wind_buses);
base = ones(n, 1);
cases = struct('name', {}, 'voltage', {});
cases(end+1) = struct('name', "normal_all", 'voltage', base);
v = base; v(1) = 0.55; cases(end+1) = struct('name', "one_low_voltage", 'voltage', v);
v = base; v(1) = 0.15; cases(end+1) = struct('name', "one_forced_low_voltage", 'voltage', v);
v = base; v(1:3) = [0.55; 0.70; 0.85]; cases(end+1) = struct('name', "multi_low_voltage", 'voltage', v);
v = base; v(1) = 1.20; cases(end+1) = struct('name', "one_high_voltage", 'voltage', v);
v = base; v(1) = 1.35; cases(end+1) = struct('name', "one_forced_high_voltage", 'voltage', v);
v = base; v(1:3) = [0.55; 1.20; 1.35]; cases(end+1) = struct('name', "mixed_low_high", 'voltage', v);
end

function [expected, pass] = expected_case(name, p_wt_Ek)
tol = 1e-9;
switch string(name)
    case "normal_all"
        expected = "P_wt_Ek must equal 1";
        pass = abs(p_wt_Ek - 1) <= tol;
    case {"one_forced_low_voltage", "one_forced_high_voltage", "mixed_low_high"}
        expected = "forced voltage trip probability makes P_wt_Ek equal 0";
        pass = abs(p_wt_Ek) <= tol;
    case "multi_low_voltage"
        expected = "multiple non-forced low voltages make 0 <= P_wt_Ek < 1";
        pass = p_wt_Ek >= -tol && p_wt_Ek < 1 - tol;
    otherwise
        expected = "single non-forced risk voltage makes 0 < P_wt_Ek < 1";
        pass = p_wt_Ek > tol && p_wt_Ek < 1 - tol;
end
end
