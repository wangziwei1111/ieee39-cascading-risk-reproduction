function main_build_wind_trip_probability_dry_run_table()
%MAIN_BUILD_WIND_TRIP_PROBABILITY_DRY_RUN_TABLE Validate P_WT formula points.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_dir = fullfile(project_root, 'results', 'calibration', 'renewable_trip');
ensure_dir(out_dir);
cfg = base_config();
cfg.wind_trip_interval_probability_mode = 'linear';

cases = {
    "normal", 1.0, 50.0, "P_WT=0";
    "forced_low_voltage", 0.1, 50.0, "P_WT=1";
    "low_voltage_interval", 0.55, 50.0, "0<P_WT<1";
    "high_voltage_interval", 1.2, 50.0, "0<P_WT<1";
    "low_frequency_interval", 1.0, 47.5, "0<P_WT<1";
    "high_frequency_interval", 1.0, 51.0, "0<P_WT<1";
    "forced_high_voltage_frequency", 1.35, 52.0, "P_WT=1";
    };

rows = cell(size(cases, 1), 1);
for i = 1:size(cases, 1)
    [p, d] = compute_wind_trip_probability_paper(cases{i,2}, cases{i,3}, cfg);
    pass = expected_pass(p, string(cases{i,4}));
    rows{i} = table(string(cases{i,1}), cases{i,2}, cases{i,3}, d.P_U_low, d.P_U_high, ...
        d.P_f_low, d.P_f_high, p, string(d.voltage_trip_region), string(d.frequency_trip_region), ...
        string(d.source_status), string(cases{i,4}), pass, string(d.note), ...
        'VariableNames', {'test_case', 'U_pu', 'f_hz', 'P_U_low', 'P_U_high', ...
        'P_f_low', 'P_f_high', 'P_wt', 'voltage_trip_region', 'frequency_trip_region', ...
        'source_status', 'expected_behavior', 'pass_fail', 'note'});
end
writetable(vertcat(rows{:}), fullfile(out_dir, 'wind_trip_probability_dry_run_table.csv'));
end

function pass = expected_pass(p, expected)
if expected == "P_WT=0"
    pass = abs(p) < 1e-12;
elseif expected == "P_WT=1"
    pass = abs(p - 1) < 1e-12;
else
    pass = p > 0 && p < 1;
end
end

function ensure_dir(path)
if ~exist(path, 'dir'), mkdir(path); end
end
