function main_audit_wind_speed_scenario_config()
%MAIN_AUDIT_WIND_SPEED_SCENARIO_CONFIG Audit current wind-speed scenario config.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
params = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenarios = ["wind_speed_11_28","wind_speed_12_00"];
expected_speed = containers.Map(cellstr(scenarios), {11.28, 12.00});

cfg = base_config();
require_matpower(cfg);
base = build_case39_base(cfg);
base_load = sum(base.bus(:, 3));
snap_path = fullfile(out_root, 'wind_speed_case_power_snapshot.csv');
if isfile(snap_path)
    snap = readtable(snap_path, 'TextType', 'string', 'Delimiter', ',');
else
    snap = table();
end

rows = table();
for p = params
    for s = scenarios
        scenario = get_scenario_by_id(char(s), cfg, base_load);
        wind_buses = join(string(scenario.wind_buses), ":");
        wind_capacity = scenario.total_wind_capacity_mw;
        speed = scenario.wind_speed_mps;
        penetration = scenario.paper_wind_penetration;
        mode = "distributed";
        if numel(scenario.wind_buses) == 1
            mode = "concentrated";
        end
        basis = string(scenario.wind_penetration_basis);
        profile = string(get_field_or_default(scenario, 'wind_power_curve_profile', cfg.wind_power_curve_profile));
        cut_in = get_field_or_default(scenario, 'cut_in_speed_mps', NaN);
        rated = get_field_or_default(scenario, 'rated_speed_mps', NaN);
        cut_out = get_field_or_default(scenario, 'cut_out_speed_mps', NaN);
        per_bus = wind_capacity / max(numel(scenario.wind_buses), 1);

        expected_capacity = 3000;
        expected_profile = "paper_2_12_20";
        ok = abs(speed - expected_speed(char(s))) < 1e-9 && ...
            abs(wind_capacity - expected_capacity) < 1e-6 && ...
            all(scenario.wind_buses(:)' == 30:39) && mode == "distributed" && ...
            abs(penetration - 0.40) < 1e-9 && profile == expected_profile;
        if ok
            status = "match";
            issue = "none";
            note = "Current scenario builder uses paper-aligned wind-speed scan config and paper_2_12_20 curve profile.";
        else
            status = "blocking";
            issue = "scenario_or_curve_profile_mismatch";
            note = "Current scenario builder still differs from expected paper-aligned wind-speed config.";
        end

        actual_pg = lookup_snapshot(snap, s, 'actual_wind_pg_total_mw_in_case');
        expected_pg = lookup_snapshot(snap, s, 'expected_wind_power_total_mw');
        source_status = lookup_snapshot_string(snap, s, 'wind_curve_source_status');
        rows = [rows; table(p, s, speed, wind_capacity, penetration, wind_buses, mode, per_bus, basis, ...
            "30:39", "", expected_speed(char(s)), 3000, profile, cut_in, rated, cut_out, expected_pg, actual_pg, ...
            source_status, status, issue, note, ...
            'VariableNames', {'parameter_set_id','scenario_id','wind_speed_mps','wind_capacity_total_mw', ...
            'paper_wind_penetration','wind_buses','wind_injection_mode','wind_capacity_per_bus_mw', ...
            'wind_penetration_basis','distributed_buses','concentrated_bus','expected_wind_speed_mps', ...
            'expected_wind_capacity_total_mw','wind_power_curve_profile','wind_cut_in_speed','wind_rated_speed', ...
            'wind_cut_out_speed','expected_wind_power_total_mw','actual_wind_pg_total_mw_in_case', ...
            'wind_curve_source_status','config_match_status','issue_type','note'})]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(out_root, 'wind_speed_scenario_config_audit.csv'));
fprintf('Wrote wind speed scenario config audit: %s\n', fullfile(out_root, 'wind_speed_scenario_config_audit.csv'));
end

function value = get_field_or_default(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function value = lookup_snapshot(T, scenario_id, field_name)
if isempty(T) || ~ismember(field_name, T.Properties.VariableNames)
    value = NaN;
    return;
end
idx = find(string(T.scenario_id) == string(scenario_id), 1);
if isempty(idx)
    value = NaN;
else
    value = str2double(string(T.(field_name)(idx)));
end
end

function value = lookup_snapshot_string(T, scenario_id, field_name)
if isempty(T) || ~ismember(field_name, T.Properties.VariableNames)
    value = "";
    return;
end
idx = find(string(T.scenario_id) == string(scenario_id), 1);
if isempty(idx)
    value = "";
else
    value = string(T.(field_name)(idx));
end
end
