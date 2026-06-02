function main_audit_wind_trip_probability_for_speed_scan()
%MAIN_AUDIT_WIND_TRIP_PROBABILITY_FOR_SPEED_SCAN Audit availability of wind-trip records.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
params = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenarios = ["wind_speed_11_28","wind_speed_12_00"];
rows = table();
for p = params
    for s = scenarios
        snap = read_if_exists(fullfile(out_root, p, s, 'scenario_config_snapshot.csv'));
        speed = getnum(snap, 'wind_speed_mps');
        [count, meanp, maxp, available, source] = find_wind_trip_rows(fullfile(out_root, p, s));
        if available
            note = "Wind trip probability records were found in scenario outputs.";
        else
            note = "missing_wind_trip_records; formal pilot is line-outage probability driven and did not record actual wind trip events.";
        end
        rows = [rows; table(p, s, speed, false, source, 0, 0, 0, meanp, maxp, available, note, ...
            'VariableNames', {'parameter_set_id','scenario_id','wind_speed_mps','wind_trip_model_enabled', ...
            'wind_trip_probability_source','wind_trip_event_count','generator_trip_event_count', ...
            'renewable_trip_event_count','mean_wind_trip_probability','max_wind_trip_probability', ...
            'wind_trip_probability_available','note'})]; %#ok<AGROW>
        %#ok<NASGU> count
    end
end
writetable(rows, fullfile(out_root, 'wind_trip_probability_speed_scan_audit.csv'));
end

function T = read_if_exists(path)
if isfile(path), T = readtable(path, 'TextType', 'string', 'Delimiter', ','); else, T = table(); end
end

function v = getnum(T, name)
if ~isempty(T) && ismember(name, T.Properties.VariableNames), v = str2double(string(T.(name)(1))); else, v = NaN; end
end

function [n, meanp, maxp, available, source] = find_wind_trip_rows(root)
patterns = ["wind_trip_probability_details.csv","wind_trip_records.csv","markov_wind_trip_details.csv"];
n = 0; meanp = NaN; maxp = NaN; available = false; source = "missing_wind_trip_records";
for pat = patterns
    files = dir(fullfile(root, "**", pat));
    if ~isempty(files)
        T = readtable(fullfile(files(1).folder, files(1).name), 'TextType', 'string', 'Delimiter', ',');
        vars = T.Properties.VariableNames;
        idx = find(ismember(vars, {'p_wt_h','trip_probability','wind_trip_probability'}), 1);
        if ~isempty(idx)
            vals = str2double(string(T.(vars{idx})));
            n = height(T); meanp = mean(vals, 'omitnan'); maxp = max(vals, [], 'omitnan');
            available = true; source = string(fullfile(files(1).folder, files(1).name));
        end
        return;
    end
end
end
