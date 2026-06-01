function main_compare_pilot_scenario_snapshot_to_paper_targets()
%MAIN_COMPARE_PILOT_SCENARIO_SNAPSHOT_TO_PAPER_TARGETS Compare dry-run snapshots to paper target intent.

out_dir = fullfile('results', 'calibration', 'diagnostics');
snapshot_file = fullfile(out_dir, 'pilot_scenario_config_snapshot.csv');
if ~exist(snapshot_file, 'file')
    error('Missing snapshot file: %s. Run main_build_pilot_scenario_config_snapshots first.', snapshot_file);
end

S = readtable(snapshot_file, 'TextType', 'string', 'Delimiter', ',');
public = read_public_fixed_parameters();
rows = {};
for i = 1:height(S)
    sid = char(S.scenario_id(i));
    expected = expected_scenario(sid, public);
    rows = append_check(rows, sid, 'snapshot_status', 'built_from_scenario_library_no_powerflow', S.snapshot_status(i), 'blocking');
    rows = append_check(rows, sid, 'branch_count', public.branch_count, S.branch_count(i), 'blocking');
    rows = append_check(rows, sid, 'slack_bus', public.slack_bus, S.slack_bus(i), 'blocking');
    rows = append_check(rows, sid, 'wind_injection_mode', expected.wind_injection_mode, S.wind_injection_mode(i), 'blocking');
    rows = append_check(rows, sid, 'wind_buses', expected.wind_buses, S.wind_buses(i), 'blocking');
    rows = append_check(rows, sid, 'wind_capacity_total_mw', expected.wind_capacity_total_mw, S.wind_capacity_total_mw(i), 'blocking');
    rows = append_check(rows, sid, 'wind_speed_mps', expected.wind_speed_mps, S.wind_speed_mps(i), 'blocking');
    rows = append_check(rows, sid, 'wind_penetration', expected.wind_penetration, S.wind_penetration(i), 'warning');
    rows = append_check(rows, sid, 'penetration_definition', expected.penetration_definition, S.penetration_definition(i), expected.penetration_severity);
    rows = append_check(rows, sid, 'capacity_allocation_rule', expected.capacity_allocation_rule, S.capacity_allocation_rule(i), 'warning');
end

T = cell2table(rows, 'VariableNames', {'scenario_id', 'check_item', ...
    'expected_value', 'actual_value', 'match_status', 'severity', 'diagnosis_note'});
writetable(T, fullfile(out_dir, 'pilot_scenario_snapshot_target_alignment.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'pilot_scenario_snapshot_target_alignment.csv'));
end

function rows = append_check(rows, scenario_id, check_item, expected, actual, severity_if_mismatch)
if isnumeric(expected)
    expected_txt = num2str(expected, '%.12g');
else
    expected_txt = char(string(expected));
end
if isnumeric(actual)
    actual_txt = num2str(actual, '%.12g');
else
    actual_txt = char(string(actual));
end
matched = values_match(expected, actual);
if matched
    if strcmp(check_item, 'capacity_allocation_rule')
        status = 'assumption_matched';
        severity = 'info';
        note = 'Allocation rule is confirmed from scenario struct, but remains an engineering convention unless the paper states per-bus allocation.';
    else
        status = 'matched';
        severity = 'info';
        note = 'Dry-run snapshot matches the intended paper target field.';
    end
else
    status = 'mismatched';
    severity = severity_if_mismatch;
    if strcmp(check_item, 'wind_capacity_total_mw') && startsWith(scenario_id, 'penetration_')
        note = 'Blocking mismatch: current scenario library uses base_load_mw for penetration capacity, while paper target audit expects 7500 MW total generation capacity convention.';
    elseif strcmp(check_item, 'penetration_definition') && startsWith(scenario_id, 'penetration_')
        note = 'Penetration basis mismatch: snapshot follows cfg/scenario library convention, not the 7500 MW target convention used by pilot mapping audit.';
    else
        note = 'Snapshot does not match intended target field; review scenario alias before formal VaR pilot.';
    end
end
rows(end + 1, :) = {scenario_id, check_item, expected_txt, actual_txt, status, severity, note}; %#ok<AGROW>
end

function tf = values_match(expected, actual)
if isnumeric(expected) || isnumeric(actual)
    e = str2double(string(expected));
    a = str2double(string(actual));
    if isnan(e) && isnan(a)
        tf = true;
    elseif isnan(e) || isnan(a)
        tf = false;
    else
        tf = abs(e - a) <= 1e-6 * max(1, abs(e));
    end
else
    tf = strcmp(strtrim(char(string(expected))), strtrim(char(string(actual))));
end
end

function expected = expected_scenario(sid, public)
expected = struct();
expected.wind_injection_mode = 'distributed';
expected.wind_buses = '30:39';
expected.wind_capacity_total_mw = 3000;
expected.wind_speed_mps = 12;
expected.wind_penetration = NaN;
expected.penetration_definition = 'paper_target_total_generation_capacity_basis';
expected.penetration_severity = 'warning';
expected.capacity_allocation_rule = 'equal_capacity_per_wind_bus_from_total_wind_capacity_mw';
switch sid
    case 'concentrated_bus34'
        expected.wind_injection_mode = 'concentrated';
        expected.wind_buses = '34';
        expected.wind_capacity_total_mw = 3000;
        expected.wind_speed_mps = 12;
        expected.wind_penetration = 3000 / public.total_generation_capacity_mw;
        expected.penetration_definition = 'not_a_penetration_scan_target';
        expected.capacity_allocation_rule = 'single_bus_total_capacity';
    case 'distributed_30_39'
        expected.wind_capacity_total_mw = 3000;
        expected.wind_speed_mps = 12;
        expected.wind_penetration = 3000 / public.total_generation_capacity_mw;
        expected.penetration_definition = 'not_a_penetration_scan_target';
    case 'wind_speed_11_28'
        expected.wind_speed_mps = 11.28;
        expected.wind_capacity_total_mw = 3000;
        expected.wind_penetration = 3000 / public.total_generation_capacity_mw;
        expected.penetration_definition = 'not_a_penetration_scan_target';
    case 'wind_speed_12_00'
        expected.wind_speed_mps = 12.00;
        expected.wind_capacity_total_mw = 3000;
        expected.wind_penetration = 3000 / public.total_generation_capacity_mw;
        expected.penetration_definition = 'not_a_penetration_scan_target';
    case 'penetration_40pct'
        expected.wind_capacity_total_mw = 0.40 * public.total_generation_capacity_mw;
        expected.wind_penetration = 0.40;
        expected.penetration_definition = 'wind_capacity_divided_by_total_generation_capacity';
        expected.penetration_severity = 'blocking';
    case 'penetration_60pct'
        expected.wind_capacity_total_mw = 0.60 * public.total_generation_capacity_mw;
        expected.wind_penetration = 0.60;
        expected.penetration_definition = 'wind_capacity_divided_by_total_generation_capacity';
        expected.penetration_severity = 'blocking';
    case 'penetration_80pct'
        expected.wind_capacity_total_mw = 0.80 * public.total_generation_capacity_mw;
        expected.wind_penetration = 0.80;
        expected.penetration_definition = 'wind_capacity_divided_by_total_generation_capacity';
        expected.penetration_severity = 'blocking';
end
end

function public = read_public_fixed_parameters()
public = struct('total_generation_capacity_mw', 7500, 'branch_count', 46, 'slack_bus', 31);
path_name = fullfile('paper_inputs', 'filled', 'public_fixed_parameters.csv');
if ~exist(path_name, 'file')
    return;
end
T = readtable(path_name, 'TextType', 'string', 'Delimiter', ',');
public.total_generation_capacity_mw = read_value(T, 'total_generation_capacity_mw', public.total_generation_capacity_mw);
public.branch_count = read_value(T, 'branch_count', public.branch_count);
public.slack_bus = read_value(T, 'slack_bus', public.slack_bus);
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
