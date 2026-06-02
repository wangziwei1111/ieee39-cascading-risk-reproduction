function main_build_pilot_scenario_config_snapshots()
%MAIN_BUILD_PILOT_SCENARIO_CONFIG_SNAPSHOTS Build dry-run pilot scenario snapshots.
% The snapshot is assembled from public fixed inputs and build_scenario_library
% only. It does not call power flow, renewable dispatch mutation, Markov search,
% or calibration search.

out_dir = fullfile('results', 'calibration', 'diagnostics');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

public = read_public_fixed_parameters();
cfg = base_config();
base_load_mw = public.total_load_mw;
scenarios = build_scenario_library(cfg, base_load_mw);
scenario_ids = pilot_scenario_ids();

rows = {};
for i = 1:numel(scenario_ids)
    scenario_id = scenario_ids{i};
    s = find_scenario(scenarios, scenario_id);
    if isempty(s)
        rows(end + 1, :) = {scenario_id, 'missing_in_scenario_library', ...
            'dry_run_build_scenario_library_only', public.total_load_mw, ...
            public.total_generation_capacity_mw, public.branch_count, ...
            public.generator_bus_list, public.slack_bus, false, '', '', NaN, NaN, ...
            NaN, NaN, NaN, NaN, '', NaN, '', '', cfg.scenario_penetration_definition, '', '', ...
            '', NaN, NaN, NaN, NaN, NaN, '', ...
            public.generator_bus_list, 'Scenario id not found in build_scenario_library.'}; %#ok<AGROW>
        continue;
    end

    wind_buses = s.wind_buses;
    wind_total = s.total_wind_capacity_mw;
    if isempty(wind_buses) || wind_total <= 0
        wind_enabled = false;
        mode = 'none';
        per_bus = NaN;
        concentrated_bus = '';
        distributed_buses = '';
        allocation = 'none';
    else
        wind_enabled = true;
        per_bus = wind_total / numel(wind_buses);
        if numel(wind_buses) == 1
            mode = 'concentrated';
            concentrated_bus = numeric_list(wind_buses);
            distributed_buses = '';
            allocation = 'single_bus_total_capacity';
        else
            mode = 'distributed';
            concentrated_bus = '';
            distributed_buses = numeric_list(wind_buses);
            allocation = 'equal_capacity_per_wind_bus_from_total_wind_capacity_mw';
        end
    end
    replaced = numeric_list(intersect(public.generator_buses_numeric, wind_buses));
    kept = numeric_list(setdiff(public.generator_buses_numeric, wind_buses));
    paper_penetration = safe_numeric_field(s, 'paper_wind_penetration', wind_total / public.total_generation_capacity_mw);
    load_penetration = safe_numeric_field(s, 'load_based_wind_penetration', wind_total / public.total_load_mw);
    penetration_basis = safe_char_field(s, 'wind_penetration_basis', cfg.wind_penetration_basis);
    if strcmp(penetration_basis, 'total_generation_capacity')
        penetration_definition = 'wind_capacity_divided_by_total_generation_capacity';
    elseif strcmp(penetration_basis, 'base_load')
        penetration_definition = 'wind_capacity_divided_by_base_load';
    else
        penetration_definition = char(string(penetration_basis));
    end
    expected_capacity = safe_numeric_field(s, 'paper_aligned_wind_capacity_expected_mw', wind_total);
    basis_match = safe_char_field(s, 'wind_capacity_basis_match_status', 'unknown');
    curve_profile = safe_char_field(s, 'wind_power_curve_profile', cfg.wind_power_curve_profile);
    curve_cfg = cfg;
    curve_cfg.wind_power_curve_profile = curve_profile;
    [expected_wind_power, curve_detail] = compute_paper_wind_power_curve(s.wind_speed_mps, wind_total, curve_cfg);

    rows(end + 1, :) = {scenario_id, 'built_from_scenario_library_no_powerflow', ...
        'dry_run_build_scenario_library_only', public.total_load_mw, ...
        public.total_generation_capacity_mw, public.branch_count, ...
        public.generator_bus_list, public.slack_bus, wind_enabled, mode, ...
        numeric_list(wind_buses), wind_total, per_bus, s.penetration_ratio, ...
        public.total_generation_capacity_mw, paper_penetration, load_penetration, ...
        penetration_basis, expected_capacity, basis_match, s.wind_speed_mps, ...
        concentrated_bus, distributed_buses, penetration_definition, allocation, replaced, kept, ...
        curve_profile, curve_detail.cut_in_speed, curve_detail.rated_speed, curve_detail.cut_out_speed, ...
        expected_wind_power, expected_wind_power, curve_detail.source_status, ...
        'Snapshot from scenario struct only; no PF, Markov, dispatch, or final summary was run.'}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', {'scenario_id', 'snapshot_status', ...
    'case_name', 'base_total_load_mw', 'base_total_generation_capacity_mw', ...
    'branch_count', 'generator_bus_list', 'slack_bus', 'wind_model_enabled', ...
    'wind_injection_mode', 'wind_buses', 'wind_capacity_total_mw', ...
    'wind_capacity_per_bus_mw', 'wind_penetration', 'paper_total_generation_capacity_mw', ...
    'paper_wind_penetration', 'load_based_wind_penetration', 'wind_penetration_basis', ...
    'paper_aligned_wind_capacity_expected_mw', 'wind_capacity_basis_match_status', ...
    'wind_speed_mps', 'concentrated_bus', 'distributed_buses', 'penetration_definition', ...
    'capacity_allocation_rule', 'replaced_generator_buses', ...
    'kept_traditional_generator_buses', 'wind_power_curve_profile', 'wind_cut_in_speed', ...
    'wind_rated_speed', 'wind_cut_out_speed', 'expected_wind_power_total_mw', ...
    'actual_wind_pg_total_mw_in_case', 'wind_curve_source_status', 'note'});
writetable(T, fullfile(out_dir, 'pilot_scenario_config_snapshot.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'pilot_scenario_config_snapshot.csv'));
end

function value = safe_numeric_field(s, field_name, fallback)
if isfield(s, field_name) && ~isempty(s.(field_name)) && ~isnan(s.(field_name))
    value = s.(field_name);
else
    value = fallback;
end
end

function value = safe_char_field(s, field_name, fallback)
if isfield(s, field_name) && ~isempty(s.(field_name))
    value = char(string(s.(field_name)));
else
    value = fallback;
end
end

function ids = pilot_scenario_ids()
ids = {'concentrated_bus34', 'distributed_30_39', 'wind_speed_11_28', ...
    'wind_speed_12_00', 'penetration_40pct', 'penetration_60pct', 'penetration_80pct'};
end

function public = read_public_fixed_parameters()
public = struct('total_load_mw', 6254.23, 'total_generation_capacity_mw', 7500, ...
    'branch_count', 46, 'generator_bus_list', '30:39', 'generator_buses_numeric', 30:39, ...
    'slack_bus', 31);
path_name = fullfile('paper_inputs', 'filled', 'public_fixed_parameters.csv');
if ~exist(path_name, 'file')
    return;
end
T = readtable(path_name, 'TextType', 'string');
public.total_load_mw = read_value(T, 'total_load_mw', public.total_load_mw);
public.total_generation_capacity_mw = read_value(T, 'total_generation_capacity_mw', public.total_generation_capacity_mw);
public.branch_count = read_value(T, 'branch_count', public.branch_count);
public.slack_bus = read_value(T, 'slack_bus', public.slack_bus);
public.generator_bus_list = read_string_value(T, 'generator_bus_range', public.generator_bus_list);
public.generator_buses_numeric = parse_bus_list(public.generator_bus_list);
end

function v = read_value(T, name, fallback)
v = fallback;
idx = strcmp(T.parameter_name, name);
if any(idx)
    parsed = str2double(T.value(find(idx, 1)));
    if ~isnan(parsed)
        v = parsed;
    end
end
end

function v = read_string_value(T, name, fallback)
v = fallback;
idx = strcmp(T.parameter_name, name);
if any(idx)
    raw = T.value(find(idx, 1));
    if ismissing(raw) || (isnumeric(raw) && isnan(raw))
        return;
    end
    raw_txt = char(string(raw));
    if isempty(raw_txt) || strcmpi(raw_txt, 'NaN') || any(raw_txt == char(0))
        return;
    end
    v = raw_txt;
end
end

function buses = parse_bus_list(txt)
txt = strrep(char(txt), '-', ':');
txt = strrep(txt, ',', ':');
parts = strsplit(txt, ':');
nums = str2double(parts);
if numel(nums) == 2 && all(~isnan(nums))
    buses = nums(1):nums(2);
else
    buses = nums(~isnan(nums));
end
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
