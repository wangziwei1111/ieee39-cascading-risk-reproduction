function main_build_wind_speed_case_power_snapshot()
%MAIN_BUILD_WIND_SPEED_CASE_POWER_SNAPSHOT Build base-case snapshots only.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
if ~exist(out_root, 'dir'), mkdir(out_root); end

cfg = base_config();
require_matpower(cfg);
base = build_case39_base(cfg);
base_load = sum(base.bus(:,3));
scenario_ids = ["wind_speed_11_28","wind_speed_12_00"];
rows = table();
for sid = scenario_ids
    scenario = get_scenario_by_id(char(sid), cfg, base_load);
    [mpc, info] = apply_renewable_scenario(base, scenario);
    curve_cfg = cfg;
    curve_cfg.wind_power_curve_profile = get_field_or_default(scenario, 'wind_power_curve_profile', cfg.wind_power_curve_profile);
    [expected, curve_detail] = compute_paper_wind_power_curve(scenario.wind_speed_mps, scenario.total_wind_capacity_mw, curve_cfg);
    wind_rows = info.wind_gen_rows(:);
    wind_pg = mpc.gen(wind_rows, 2);
    wind_bus = mpc.gen(wind_rows, 1);
    traditional_rows = setdiff((1:size(mpc.gen,1))', wind_rows);
    traditional_bus = mpc.gen(traditional_rows, 1);
    [pf, conv] = run_ac_powerflow(mpc);
    viol = check_violations(pf, cfg);
    status = "base_case_only_not_cascade";
    note = "Constructed renewable scenario and ran one base-case AC PF only; no cascade or Markov simulation.";
    rows = [rows; table(sid, scenario.wind_speed_mps, scenario.total_wind_capacity_mw, ...
        string(curve_detail.curve_profile), curve_detail.cut_in_speed, curve_detail.rated_speed, ...
        curve_detail.cut_out_speed, string(curve_detail.source_status), expected, ...
        sum(wind_pg), join(string(wind_bus'), ":"), join(string(round(wind_pg',6)), ":"), ...
        join(string(traditional_bus'), ":"), sum(mpc.gen(traditional_rows,2)), sum(mpc.gen(:,2)), ...
        sum(mpc.bus(:,3)), true, logical(conv), viol.max_line_loading_pu, ...
        min(pf.bus(:,8)), max(pf.bus(:,8)), status, note, ...
        'VariableNames', {'scenario_id','wind_speed_mps','wind_capacity_total_mw', ...
        'wind_power_curve_profile','wind_cut_in_speed','wind_rated_speed','wind_cut_out_speed', ...
        'wind_curve_source_status','expected_wind_power_total_mw','actual_wind_pg_total_mw_in_case','wind_bus_list', ...
        'wind_pg_by_bus','traditional_generator_buses','traditional_pg_total_mw','total_generation_pg_mw', ...
        'total_load_mw','runpf_used','base_pf_converged','max_base_line_loading_pu', ...
        'min_base_voltage_pu','max_base_voltage_pu','snapshot_status','note'})]; %#ok<AGROW>
end
writetable(rows, fullfile(out_root, 'wind_speed_case_power_snapshot.csv'));
end

function value = get_field_or_default(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end
