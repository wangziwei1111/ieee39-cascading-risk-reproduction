function main_trace_pilot_scenario_config_sources()
%MAIN_TRACE_PILOT_SCENARIO_CONFIG_SOURCES Trace pilot scenario config provenance.
% This diagnostic only reads source/config/result files. It does not run
% power flow, Markov cascade, calibration search, or final summary logic.

out_dir = fullfile('results', 'calibration', 'diagnostics');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

scenario_ids = pilot_scenario_ids();
cfg = base_config();
base_load_mw = read_public_numeric('total_load_mw', 6254.23);
scenarios = build_scenario_library(cfg, base_load_mw);

rows = {};
for i = 1:numel(scenario_ids)
    scenario_id = scenario_ids{i};
    s = find_scenario(scenarios, scenario_id);
    if isempty(s)
        rows(end + 1, :) = {scenario_id, 'src/scenarios/build_scenario_library.m', ...
            'build_scenario_library', 'scenario_id', '', 'scenario_lookup', ...
            'missing', 'Pilot scenario is not present in the dry-run scenario library.'}; %#ok<AGROW>
        continue;
    end

    rows(end + 1, :) = {scenario_id, 'src/main_run_benchmark_calibration_pilot.m', ...
        'main_run_benchmark_calibration_pilot', 'pilot_scenario_list', scenario_id, ...
        'script_scenario_list', file_status('src/main_run_benchmark_calibration_pilot.m'), ...
        'Pilot target scenario is listed by the calibration pilot entry script; no pilot was run.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'src/scenarios/build_scenario_library.m', ...
        'build_scenario_library', 'scenario_group', safe_field(s, 'scenario_group'), ...
        'scenario_struct_field', 'found', 'Dry-run scenario struct was read without applying renewable dispatch.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'src/scenarios/build_scenario_library.m', ...
        'build_scenario_library', 'wind_buses', numeric_list(s.wind_buses), ...
        'scenario_struct_field', 'found', 'Actual calibration alias wind buses from scenario library.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'src/scenarios/build_scenario_library.m', ...
        'build_scenario_library', 'total_wind_capacity_mw', num2str(s.total_wind_capacity_mw, '%.12g'), ...
        'scenario_struct_field', 'found', 'Actual total wind capacity from scenario library.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'src/scenarios/build_scenario_library.m', ...
        'build_scenario_library', 'wind_speed_mps', num2str(s.wind_speed_mps, '%.12g'), ...
        'scenario_struct_field', 'found', 'Actual wind speed from scenario library.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'src/scenarios/build_scenario_library.m', ...
        'build_scenario_library', 'penetration_ratio', num2str(s.penetration_ratio, '%.12g'), ...
        'scenario_struct_field', 'found', 'Scenario penetration ratio as currently stored.'}; %#ok<AGROW>

    rows(end + 1, :) = {scenario_id, 'config/base_config.m', 'base_config', ...
        'scenario_penetration_definition', cfg.scenario_penetration_definition, ...
        'config_default', 'found', 'Penetration scenario aliases currently use build_scenario_library capacity logic.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'config/base_config.m', 'base_config', ...
        'wind_penetration_basis', cfg.wind_penetration_basis, ...
        'config_default', 'found', 'Paper-aligned benchmark/calibration scenarios use total_generation_capacity basis.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'src/cases/compute_wind_capacity_from_penetration.m', ...
        'compute_wind_capacity_from_penetration', 'capacity_basis_function', ...
        'penetration * selected basis MW', 'helper_function', file_status('src/cases/compute_wind_capacity_from_penetration.m'), ...
        'Centralized helper prevents duplicated 7500/base-load conversion logic.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'config/base_config.m', 'base_config', ...
        'scenario_centralized_wind_bus', num2str(cfg.scenario_centralized_wind_bus), ...
        'config_default', 'warning_alias_override', ...
        'Default centralized bus is 39, but calibration alias concentrated_bus34 explicitly overrides to bus 34.'}; %#ok<AGROW>
    rows(end + 1, :) = {scenario_id, 'config/scenario_config.m', 'scenario_config', ...
        'distributed_defaults', 'wind_buses=30:39;total_wind_capacity_mw=3000;wind_speed_mps=12', ...
        'config_default', file_status('config/scenario_config.m'), ...
        'Default scenario config is reference context only; pilot aliases are read from scenario library.'}; %#ok<AGROW>

    log_file = fullfile('results', 'calibration', 'pilot', 'benchmark_calibrated_seed', scenario_id, 'scenario_run_log.txt');
    if exist(log_file, 'file')
        log_status = 'log_exists_not_used_for_snapshot';
        log_note = 'Existing pilot run log is present, but snapshot confirmation uses source/config dry-run fields.';
    else
        log_status = 'missing_in_log';
        log_note = 'No scenario run log found for this scenario; dry-run source trace is used instead.';
    end
    rows(end + 1, :) = {scenario_id, strrep(log_file, '\', '/'), 'scenario_run_log', ...
        'runtime_config_evidence', '', 'existing_result_log', log_status, log_note}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'scenario_id', 'source_file', ...
    'source_function_or_script', 'config_key', 'config_value', 'evidence_type', ...
    'evidence_status', 'note'});
writetable(T, fullfile(out_dir, 'pilot_scenario_config_source_trace.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'pilot_scenario_config_source_trace.csv'));
end

function ids = pilot_scenario_ids()
ids = {'concentrated_bus34', 'distributed_30_39', 'wind_speed_11_28', ...
    'wind_speed_12_00', 'penetration_40pct', 'penetration_60pct', 'penetration_80pct'};
end

function s = find_scenario(scenarios, scenario_id)
s = [];
for k = 1:numel(scenarios)
    if strcmp(scenarios(k).scenario_id, scenario_id)
        s = scenarios(k);
        return;
    end
end
end

function value = safe_field(s, field_name)
if isfield(s, field_name)
    v = s.(field_name);
    if isnumeric(v)
        value = numeric_list(v);
    elseif islogical(v)
        value = string(v);
    else
        value = char(string(v));
    end
else
    value = '';
end
end

function txt = numeric_list(v)
if isempty(v)
    txt = '';
elseif numel(v) == 1
    txt = num2str(v, '%.12g');
elseif all(abs(diff(v) - 1) < 1e-12) && all(abs(v - round(v)) < 1e-12)
    txt = sprintf('%d:%d', round(v(1)), round(v(end)));
else
    txt = strjoin(arrayfun(@(x) num2str(x, '%.12g'), v, 'UniformOutput', false), ':');
end
end

function status = file_status(path_name)
if exist(path_name, 'file')
    status = 'found';
else
    status = 'missing';
end
end

function value = read_public_numeric(parameter_name, fallback)
value = fallback;
path_name = fullfile('paper_inputs', 'filled', 'public_fixed_parameters.csv');
if ~exist(path_name, 'file')
    return;
end
T = readtable(path_name, 'TextType', 'string');
idx = strcmp(T.parameter_name, parameter_name);
if any(idx)
    parsed = str2double(T.value(find(idx, 1)));
    if ~isnan(parsed)
        value = parsed;
    end
end
end
