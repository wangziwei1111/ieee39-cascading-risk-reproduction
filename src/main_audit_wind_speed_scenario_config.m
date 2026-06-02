function main_audit_wind_speed_scenario_config()
%MAIN_AUDIT_WIND_SPEED_SCENARIO_CONFIG Audit wind-speed pilot snapshots.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
params = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenarios = ["wind_speed_11_28","wind_speed_12_00"];
expected_speed = containers.Map(cellstr(scenarios), {11.28, 12.00});

rows = table();
for p = params
    for s = scenarios
        snap_path = fullfile(out_root, p, s, 'scenario_config_snapshot.csv');
        if isfile(snap_path)
            T = readtable(snap_path, 'TextType', 'string', 'Delimiter', ',');
            r = T(1,:);
            wind_buses = value_as_string(r, 'wind_buses');
            wind_capacity = value_as_double(r, 'wind_capacity_total_mw');
            speed = value_as_double(r, 'wind_speed_mps');
            penetration = value_as_double(r, 'paper_wind_penetration');
            mode = value_as_string(r, 'wind_injection_mode');
            basis = value_as_string(r, 'wind_penetration_basis');
            buses = parse_bus_list(wind_buses);
            per_bus = wind_capacity / max(numel(buses), 1);
            expected_capacity = 3000;
            ok = abs(speed - expected_speed(char(s))) < 1e-9 && abs(wind_capacity - expected_capacity) < 1e-6 && ...
                all(buses(:)' == 30:39) && mode == "distributed";
            if ok
                status = "match";
                issue = "none";
                note = "Scenario snapshot matches expected wind-speed scan label, capacity, and distributed buses.";
            else
                status = "mismatch";
                issue = "scenario_config_mismatch";
                note = "At least one expected wind-speed scenario field differs from 11.28/12.00, 3000 MW, or buses 30:39.";
            end
        else
            speed = NaN; wind_capacity = NaN; penetration = NaN; wind_buses = ""; mode = ""; basis = ""; per_bus = NaN;
            status = "missing_snapshot"; issue = "missing_file"; note = "scenario_config_snapshot.csv is missing.";
        end
        rows = [rows; table(p, s, speed, wind_capacity, penetration, wind_buses, mode, per_bus, basis, ...
            "30:39", "", expected_speed(char(s)), 3000, status, issue, note, ...
            'VariableNames', {'parameter_set_id','scenario_id','wind_speed_mps','wind_capacity_total_mw', ...
            'paper_wind_penetration','wind_buses','wind_injection_mode','wind_capacity_per_bus_mw', ...
            'wind_penetration_basis','distributed_buses','concentrated_bus','expected_wind_speed_mps', ...
            'expected_wind_capacity_total_mw','config_match_status','issue_type','note'})]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(out_root, 'wind_speed_scenario_config_audit.csv'));
fprintf('Wrote wind speed scenario config audit: %s\n', fullfile(out_root, 'wind_speed_scenario_config_audit.csv'));
end

function v = value_as_double(T, name)
if ismember(name, T.Properties.VariableNames)
    raw = T.(name)(1);
    if isnumeric(raw), v = double(raw); else, v = str2double(string(raw)); end
else
    v = NaN;
end
end

function v = value_as_string(T, name)
if ismember(name, T.Properties.VariableNames)
    v = string(T.(name)(1));
else
    v = "";
end
end

function buses = parse_bus_list(s)
s = erase(string(s), " ");
if contains(s, ":")
    parts = split(s, ":");
    buses = str2double(parts(1)):str2double(parts(2));
elseif strlength(s) == 0
    buses = [];
else
    parts = split(s, {",",";"});
    buses = str2double(parts)';
end
end
