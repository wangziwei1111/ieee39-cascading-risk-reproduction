function main_audit_current_wind_speed_scenario_assumptions()
%MAIN_AUDIT_CURRENT_WIND_SPEED_SCENARIO_ASSUMPTIONS Build read-only wind-speed assumption audit.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
ensure_dir(out_dir);

snap11 = read_first_existing(project_root, {
    'results/calibration/wind_speed_component_diagnostic_rerun/benchmark_calibrated_seed/wind_speed_11_28/scenario_config_snapshot.csv'
    'results/calibration/severity_formula/wind_speed_after_severity_fix_diagnostic_rerun/benchmark_calibrated_seed/wind_speed_11_28/scenario_config_snapshot.csv'
    'results/calibration/full_event_formal_var_pilot/wind_speed_11_28/scenario_config_snapshot.csv'
    });
snap12 = read_first_existing(project_root, {
    'results/calibration/wind_speed_component_diagnostic_rerun/benchmark_calibrated_seed/wind_speed_12_00/scenario_config_snapshot.csv'
    'results/calibration/severity_formula/wind_speed_after_severity_fix_diagnostic_rerun/benchmark_calibrated_seed/wind_speed_12_00/scenario_config_snapshot.csv'
    'results/calibration/full_event_formal_var_pilot/wind_speed_12_00/scenario_config_snapshot.csv'
    });

source_file = 'results/calibration/wind_speed_component_diagnostic_rerun/*/wind_speed_*/scenario_config_snapshot.csv';
rows = {};
rows = add_row(rows, 'wind_buses', 'Current diagnostic snapshots use distributed wind buses 30:39.', source_file, 'wind_buses', ...
    get_text(snap11, 'wind_buses'), get_text(snap12, 'wind_buses'), same_text(get_text(snap11, 'wind_buses'), get_text(snap12, 'wind_buses')), ...
    'partially_confirmed_by_inputs', 'needs_manual_confirmation', 'Paper Table 4-6 wind buses are recorded as 30:39 in scenario definitions, but dispatch/absorption assumptions still need confirmation.');
rows = add_row(rows, 'wind_capacity_total_mw', 'Current snapshots keep total wind capacity at 3000 MW.', source_file, 'wind_capacity_total_mw', ...
    get_text(snap11, 'wind_capacity_total_mw'), get_text(snap12, 'wind_capacity_total_mw'), same_text(get_text(snap11, 'wind_capacity_total_mw'), get_text(snap12, 'wind_capacity_total_mw')), ...
    'partially_confirmed_by_inputs', 'not_blocking', 'Capacity is fixed; actual wind PG differs because the wind-speed curve changes.');
rows = add_row(rows, 'wind_capacity_per_bus_mw', 'Capacity is evenly distributed across 10 wind buses in current distributed scenario.', source_file, 'derived_from_total_capacity_and_wind_buses', ...
    per_bus_text(snap11), per_bus_text(snap12), same_text(per_bus_text(snap11), per_bus_text(snap12)), ...
    'not_directly_confirmed', 'needs_manual_confirmation', 'This is derived from current implementation; confirm whether paper distributed capacity is equal per bus.');
rows = add_row(rows, 'wind_speed_mps', 'Only the scenario wind_speed_mps field differs between these two wind-speed points.', source_file, 'wind_speed_mps', ...
    get_text(snap11, 'wind_speed_mps'), get_text(snap12, 'wind_speed_mps'), same_text(get_text(snap11, 'wind_speed_mps'), get_text(snap12, 'wind_speed_mps')), ...
    'confirmed_by_table46_mapping', 'not_blocking', 'The selected comparison points are 11.28 and 12.00 m/s.');
rows = add_row(rows, 'wind_power_curve_profile', 'Current snapshots use paper_2_12_20 wind power curve profile.', source_file, 'wind_power_curve_profile', ...
    get_text(snap11, 'wind_power_curve_profile'), get_text(snap12, 'wind_power_curve_profile'), same_text(get_text(snap11, 'wind_power_curve_profile'), get_text(snap12, 'wind_power_curve_profile')), ...
    'confirmed_after_prior_fix', 'not_blocking', 'Curve profile was already corrected before this assumption pack.');
rows = add_row(rows, 'expected_wind_power_total_mw', 'Expected wind power follows the current paper_2_12_20 curve.', source_file, 'expected_wind_power_total_mw', ...
    get_text(snap11, 'expected_wind_power_total_mw'), get_text(snap12, 'expected_wind_power_total_mw'), same_text(get_text(snap11, 'expected_wind_power_total_mw'), get_text(snap12, 'expected_wind_power_total_mw')), ...
    'implementation_confirmed', 'needs_manual_confirmation', 'Current model increases expected wind power from about 2489 MW to 3000 MW; paper absorption and redispatch need confirmation.');
rows = add_row(rows, 'actual_wind_pg_total_mw_in_case', 'Current case applies the expected wind PG into the case; 12.00 m/s reaches 3000 MW.', source_file, 'actual_wind_pg_total_mw_in_case', ...
    get_text(snap11, 'actual_wind_pg_total_mw_in_case'), get_text(snap12, 'actual_wind_pg_total_mw_in_case'), same_text(get_text(snap11, 'actual_wind_pg_total_mw_in_case'), get_text(snap12, 'actual_wind_pg_total_mw_in_case')), ...
    'implementation_confirmed', 'needs_manual_confirmation', 'This is the central assumption to confirm against the paper.');

rows = add_row(rows, 'traditional_generator_dispatch_policy', 'wind_plus_redispatch lowers non-slack conventional generator PG by available downward room; slack bus 31 remains for balance trimming.', ...
    'src/cases/apply_renewable_scenario.m', 'renewable_dispatch_mode=wind_plus_redispatch', 'same policy', 'same policy', 'true', ...
    'not_paper_confirmed', 'manual_confirmation_required', 'Current implementation is documented in code, but the paper dispatch policy is not yet confirmed.');
rows = add_row(rows, 'slack_bus_policy', 'Current scenario struct uses slack_bus=31 and keeps conventional slack generator for power-flow balance.', ...
    'src/scenarios/build_scenario_library.m; config/scenario_config.m; src/cases/apply_renewable_scenario.m', 'slack_bus', '31', '31', 'true', ...
    'paper_system_slack_known_but_dispatch_unconfirmed', 'manual_confirmation_required', 'Need confirm whether the paper lets slack absorb wind-speed changes or performs specified redispatch.');
rows = add_row(rows, 'power_balance_policy', 'Current engineering balance is wind injection plus conventional redispatch, with MATPOWER/slack completing AC power balance.', ...
    'src/cases/apply_renewable_scenario.m', 'wind_plus_redispatch', 'same policy', 'same policy', 'true', ...
    'not_paper_confirmed', 'manual_confirmation_required', 'The paper may use a different redispatch, curtailment, or base-flow recalculation convention.');
rows = add_row(rows, 'load_level_policy', 'Current wind-speed comparison does not show a scenario-specific load change in snapshots.', source_file, 'not_present_in_snapshot', 'no load change field', 'no load change field', 'true', ...
    'not_paper_confirmed', 'manual_confirmation_required', 'Need confirm whether Table 4-6 keeps total load fixed.');
rows = add_row(rows, 'wind_curtailment_policy', 'No explicit curtailment is visible in the wind-speed snapshots; actual wind PG equals expected curve output.', source_file, 'expected_vs_actual_wind_pg', ...
    curtail_text(snap11), curtail_text(snap12), same_text(curtail_text(snap11), curtail_text(snap12)), 'not_paper_confirmed', 'manual_confirmation_required', ...
    'If paper curtails wind or fixes absorbed wind power, current base-flow response may differ.');
rows = add_row(rows, 'conventional_generation_reduction_policy', 'Current code redispatches non-slack conventional units by available downward margin; exact per-generator paper PG table is not available.', ...
    'src/cases/apply_renewable_scenario.m', 'redispatch_rows/reducible', 'same policy', 'same policy', 'true', 'not_paper_confirmed', 'manual_confirmation_required', ...
    'Need paper PG or dispatch rule to decide whether current line-loading increase is expected.');
rows = add_row(rows, 'reactive_power_policy', 'Wind generators are appended with generator rows; Q behavior follows MATPOWER generator limits/defaults in current case construction.', ...
    'src/cases/apply_renewable_scenario.m', 'append_wind_generators', 'same policy', 'same policy', 'true', 'not_paper_confirmed', 'manual_confirmation_required', ...
    'Paper reactive support or voltage-control assumptions are not confirmed.');
rows = add_row(rows, 'base_power_flow_solution_policy', 'Current diagnostics recompute AC power-flow operating points after applying wind-speed scenario case construction.', ...
    'src/main_build_wind_speed_case_power_snapshot.m; diagnostic rerun outputs', 'run_ac_powerflow/basecase_validation', 'same workflow', 'same workflow', 'true', ...
    'not_paper_confirmed', 'manual_confirmation_required', 'Need confirm whether paper reports or recomputes base flow for each wind speed.');
rows = add_row(rows, 'paper_wind_penetration_basis', 'Current scenario uses 3000 MW over base load/capacity convention in scenario definitions; paper penetration basis remains a known uncertainty.', ...
    'src/scenarios/build_scenario_library.m; docs/scenario_definitions.md', 'paper_wind_penetration/wind_penetration_basis', '40pct nominal', '40pct nominal', 'true', ...
    'partially_confirmed_by_mapping', 'needs_manual_confirmation', 'Need confirm denominator and whether 3000 MW corresponds exactly to Table 4-6 basis.');
rows = add_row(rows, 'whether_only_wind_speed_changes', 'Capacity, buses, curve profile, seed policy, and probability mode are the same; wind speed and resulting wind PG differ.', ...
    source_file, 'multiple fields', 'wind speed 11.28; PG about 2489 MW', 'wind speed 12.00; PG 3000 MW', 'false', ...
    'implementation_confirmed_only', 'manual_confirmation_required', 'Confirm whether paper intended only wind speed change or also a defined dispatch/absorption change.');
rows = add_row(rows, 'whether_dispatch_changes_with_wind_speed', 'Current dispatch changes indirectly because higher wind PG triggers more conventional reduction and slack balancing.', ...
    'src/cases/apply_renewable_scenario.m', 'wind_plus_redispatch', 'lower wind PG redispatch case', 'higher wind PG redispatch case', 'false', ...
    'not_paper_confirmed', 'manual_confirmation_required', 'This assumption can flip line-loading and tail probability trends.');
rows = add_row(rows, 'whether_line_loading_changes_are_expected', 'Current diagnostics show line loading and P_L changes between 11.28 and 12.00 m/s; some tails are higher at 12.00 m/s.', ...
    'results/calibration/severity_formula/wind_speed_after_severity_fix_baseflow_delta_summary.csv', 'delta_line_loading/delta_P_L', 'baseline', 'some branches higher', 'false', ...
    'not_paper_confirmed', 'manual_confirmation_required', 'Need paper base-flow or dispatch details to judge whether this response should occur.');

T = cell2table(rows, 'VariableNames', {'assumption_item','current_implementation','source_file','source_field','wind_speed_11_28_value','wind_speed_12_00_value','same_between_scenarios','paper_confirmed','issue_status','note'});
writetable(T, fullfile(out_dir, 'current_wind_speed_scenario_assumption_audit.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'current_wind_speed_scenario_assumption_audit.csv'));
end

function rows = add_row(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir')
    mkdir(pathname);
end
end

function T = read_first_existing(project_root, rels)
T = table();
for k = 1:numel(rels)
    p = fullfile(project_root, rels{k});
    if isfile(p)
        T = readtable(p, 'TextType', 'string', 'Delimiter', ',');
        return;
    end
end
end

function value = get_text(T, field)
if isempty(T) || ~ismember(field, T.Properties.VariableNames)
    value = "missing";
else
    value = string(T.(field)(1));
end
end

function value = same_text(a, b)
value = string(strcmp(string(a), string(b)));
end

function txt = per_bus_text(T)
cap = str2double(get_text(T, 'wind_capacity_total_mw'));
buses = get_text(T, 'wind_buses');
if isnan(cap) || buses == "missing"
    txt = "missing";
    return;
end
n = numel(split(buses, ":"));
txt = string(cap / max(n, 1));
end

function txt = curtail_text(T)
expected = str2double(get_text(T, 'expected_wind_power_total_mw'));
actual = str2double(get_text(T, 'actual_wind_pg_total_mw_in_case'));
if isnan(expected) || isnan(actual)
    txt = "missing";
elseif abs(expected - actual) < 1e-6
    txt = "no explicit curtailment observed";
else
    txt = sprintf("expected %.6g MW; actual %.6g MW", expected, actual);
end
end
