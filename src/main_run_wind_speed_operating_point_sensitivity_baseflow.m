function main_run_wind_speed_operating_point_sensitivity_baseflow()
%MAIN_RUN_WIND_SPEED_OPERATING_POINT_SENSITIVITY_BASEFLOW Base-case-only sensitivity.
% This script intentionally does not call Markov/cascade/local-search entry points.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));
out_root = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption', 'baseflow_operating_point_sensitivity');
ensure_dir(out_root);

cfg0 = base_config();
require_matpower(cfg0);
cfgP = load_benchmark_calibration_parameter_set(cfg0, 'benchmark_calibrated_seed');
base = build_case39_base(cfg0);
base_load = sum(base.bus(:, 3));
policies = ["wind_plus_redispatch_current","slack_only_balance","proportional_conventional_redispatch", ...
    "designated_generator_redispatch","wind_curtail_to_constant_absorbed_power","constant_total_generation_dispatch"];
scenarios = ["wind_speed_11_28","wind_speed_12_00"];

scenario11 = get_scenario_by_id('wind_speed_11_28', cfg0, base_load);
[absorbed_reference, ~] = compute_paper_wind_power_curve(scenario11.wind_speed_mps, scenario11.total_wind_capacity_mw, cfg0);

for p = policies
    for s = scenarios
        scenario = get_scenario_by_id(char(s), cfg0, base_load);
        scenario.wind_speed_operating_point_policy = char(p);
        [mpc, info] = build_policy_case(base, scenario, cfg0, char(p), absorbed_reference);
        [pf, converged] = run_ac_powerflow(mpc);
        viol = check_violations(pf, cfg0);
        out_dir = fullfile(out_root, char(p), char(s));
        ensure_dir(out_dir);
        write_snapshots(out_dir, char(p), char(s), scenario, mpc, pf, converged, viol, info, cfgP);
    end
end
fill_generator_pg_changes(out_root, policies);
fprintf('Wrote wind-speed operating-point sensitivity: %s\n', out_root);
end

function [mpc, info] = build_policy_case(base, scenario, cfg, policy, absorbed_reference)
mpc = base;
wind_buses = scenario.wind_buses(:);
wind_capacity = (scenario.total_wind_capacity_mw / numel(wind_buses)) * ones(numel(wind_buses), 1);
[available_total, ~] = compute_paper_wind_power_curve(scenario.wind_speed_mps, scenario.total_wind_capacity_mw, cfg);
absorbed_total = available_total;
if strcmp(policy, 'wind_curtail_to_constant_absorbed_power')
    absorbed_total = min(available_total, absorbed_reference);
end
wind_p = (absorbed_total / numel(wind_buses)) * ones(numel(wind_buses), 1);
original_gen_count = size(mpc.gen, 1);
[mpc, wind_rows] = append_wind_generators_local(mpc, wind_buses, wind_p, wind_capacity);
slack_bus = get_field_or_default(scenario, 'slack_bus', 31);
conv_rows = (1:original_gen_count)';
non_slack_rows = conv_rows(mpc.gen(conv_rows, 1) ~= slack_bus);

switch policy
    case 'wind_plus_redispatch_current'
        mpc = base;
        scenario.renewable_dispatch_mode = 'wind_plus_redispatch';
        [mpc, apply_info] = apply_renewable_scenario(mpc, scenario);
        wind_rows = apply_info.wind_gen_rows(:);
        absorbed_total = sum(mpc.gen(wind_rows, 2));
    case 'slack_only_balance'
        % Keep original conventional setpoints; the slack generator balances in runpf.
    case 'proportional_conventional_redispatch'
        mpc = reduce_pg_local(mpc, non_slack_rows, absorbed_total, max(mpc.gen(non_slack_rows, 2), 0));
    case 'designated_generator_redispatch'
        [~, order] = sort(mpc.gen(non_slack_rows, 2), 'descend');
        designated = non_slack_rows(order(1:min(3, numel(order))));
        mpc = reduce_pg_local(mpc, designated, absorbed_total, max(mpc.gen(designated, 2), 0));
    case 'wind_curtail_to_constant_absorbed_power'
        mpc = reduce_pg_local(mpc, non_slack_rows, absorbed_total, max(mpc.gen(non_slack_rows, 2), 0));
    case 'constant_total_generation_dispatch'
        mpc = reduce_pg_local(mpc, non_slack_rows, absorbed_total, ones(size(non_slack_rows)));
    otherwise
        error('Unknown wind-speed operating-point policy: %s', policy);
end

info = struct();
info.policy_id = policy;
info.original_gen_count = original_gen_count;
info.wind_rows = wind_rows(:);
info.wind_available_power_total_mw = available_total;
info.wind_absorbed_power_total_mw = absorbed_total;
info.wind_curtailed_power_total_mw = max(available_total - absorbed_total, 0);
info.slack_bus = slack_bus;
info.assumption_status = "diagnostic_sensitivity_not_paper_confirmed";
end

function mpc = reduce_pg_local(mpc, rows, target_reduction, weights)
active = rows(:);
base_rows = rows(:);
base_weights = weights(:);
remaining = target_reduction;
for iter = 1:20
    if remaining <= 1e-8 || isempty(active)
        break;
    end
    room = max(mpc.gen(active, 2) - mpc.gen(active, 10), 0);
    if sum(room) <= 1e-8
        break;
    end
    [~, loc] = ismember(active, base_rows);
    w = base_weights(loc);
    if sum(w) <= 0
        w = room;
    end
    delta = min(room, remaining * w / sum(w));
    mpc.gen(active, 2) = mpc.gen(active, 2) - delta;
    remaining = remaining - sum(delta);
    active = active(room - delta > 1e-7);
end
end

function [mpc, wind_rows] = append_wind_generators_local(mpc, wind_buses, wind_p, wind_capacity)
template = mpc.gen(1, :);
new_gens = zeros(numel(wind_buses), size(mpc.gen, 2));
for k = 1:numel(wind_buses)
    local_gen = find(mpc.gen(:, 1) == wind_buses(k), 1);
    if ~isempty(local_gen)
        template = mpc.gen(local_gen, :);
    end
    new_gens(k, :) = template;
    new_gens(k, 1) = wind_buses(k);
    new_gens(k, 2) = wind_p(k);
    new_gens(k, 3) = 0;
    new_gens(k, 6) = 1.0;
    new_gens(k, 8) = 1;
    new_gens(k, 9) = wind_capacity(k);
    new_gens(k, 10) = 0;
end
mpc.gen = [mpc.gen; new_gens];
wind_rows = ((size(mpc.gen, 1) - numel(wind_buses) + 1):size(mpc.gen, 1))';
if isfield(mpc, 'gencost') && ~isempty(mpc.gencost)
    mpc.gencost = [mpc.gencost; repmat(mpc.gencost(1, :), numel(wind_buses), 1)];
end
end

function write_snapshots(out_dir, policy, scenario_id, scenario, mpc, pf, converged, violations, info, cfgP)
assumption_status = string(info.assumption_status);
wind_rows = info.wind_rows(:);
conv_rows = setdiff((1:size(pf.gen, 1))', wind_rows);
rate = pf.branch(:, 6);
rate(rate <= 0) = cfgP.default_branch_rate_mva;
loading = compute_loading(pf, rate);
slack_rows = find(pf.gen(:, 1) == info.slack_bus);
slack_rows = setdiff(slack_rows, wind_rows);
if isempty(slack_rows)
    slack_pg = NaN;
else
    slack_pg = sum(pf.gen(slack_rows, 2));
end

scenario_snapshot = table(string(policy), string(scenario_id), scenario.wind_speed_mps, ...
    scenario.total_wind_capacity_mw, join(string(scenario.wind_buses(:)'), ":"), ...
    string(scenario.wind_power_curve_profile), assumption_status, ...
    "Sensitivity policy is not paper-confirmed.", ...
    'VariableNames', {'policy_id','scenario_id','wind_speed_mps','wind_capacity_total_mw','wind_buses','wind_power_curve_profile','assumption_status','note'});

base_snapshot = table(string(policy), string(scenario_id), scenario.wind_speed_mps, ...
    info.wind_available_power_total_mw, info.wind_absorbed_power_total_mw, info.wind_curtailed_power_total_mw, ...
    sum(pf.bus(:, 3)), sum(pf.gen(:, 2)), sum(pf.gen(conv_rows, 2)), info.slack_bus, slack_pg, ...
    logical(converged), violations.max_line_loading_pu, mean(loading), min(pf.bus(:, 8)), max(pf.bus(:, 8)), ...
    assumption_status, "Base-case AC power flow only; no Markov/cascade/local search.", ...
    'VariableNames', {'policy_id','scenario_id','wind_speed_mps','wind_available_power_total_mw','wind_absorbed_power_total_mw','wind_curtailed_power_total_mw','total_load_mw','total_generation_mw','total_conventional_generation_mw','slack_bus','slack_pg_mw','base_pf_converged','max_line_loading_pu','mean_line_loading_pu','min_voltage_pu','max_voltage_pu','assumption_status','note'});

branch_id = (1:size(pf.branch, 1))';
P_L = NaN(size(branch_id)); P1 = P_L; P2 = P_L; P3 = P_L; P_flow = P_L; P_HF_L = P_L;
for i = 1:numel(branch_id)
    [P_L(i), d] = compute_paper_line_outage_probability(loading(i), pf.branch(i, :), cfgP, 'branch_index', i);
    P1(i) = d.P1; P2(i) = d.P2; P3(i) = d.P3; P_flow(i) = d.P_flow; P_HF_L(i) = d.P_HF_L;
end
line_snapshot = table(repmat(string(policy), numel(branch_id), 1), repmat(string(scenario_id), numel(branch_id), 1), ...
    branch_id, pf.branch(:, 1), pf.branch(:, 2), loading, P_L, P1, P2, P3, P_flow, P_HF_L, ...
    repmat(assumption_status, numel(branch_id), 1), repmat("Base-case line probability input only.", numel(branch_id), 1), ...
    'VariableNames', {'policy_id','scenario_id','branch_id','from_bus','to_bus','line_loading_pu','P_L','P1','P2','P3','P_flow','P_HF_L','assumption_status','note'});

gen_index = (1:size(pf.gen, 1))';
is_wind = ismember(gen_index, wind_rows);
is_slack = pf.gen(:, 1) == info.slack_bus & ~is_wind;
is_conventional = ~is_wind;
gen_type = repmat("conventional", size(gen_index));
gen_type(is_wind) = "wind";
gen_snapshot = table(repmat(string(policy), numel(gen_index), 1), repmat(string(scenario_id), numel(gen_index), 1), ...
    pf.gen(:, 1), gen_type, pf.gen(:, 2), pf.gen(:, 3), NaN(size(gen_index)), ...
    is_slack, is_wind, is_conventional, repmat(assumption_status, numel(gen_index), 1), ...
    repmat("PG_change_from_11_28 is computed in the sensitivity summary.", numel(gen_index), 1), ...
    'VariableNames', {'policy_id','scenario_id','gen_bus','gen_type','PG_mw','QG_mvar','PG_change_from_11_28','is_slack','is_wind','is_conventional','assumption_status','note'});

    writetable(scenario_snapshot, fullfile(out_dir, 'scenario_config_snapshot.csv'));
    writetable(base_snapshot, fullfile(out_dir, 'base_power_flow_snapshot.csv'));
    writetable(line_snapshot, fullfile(out_dir, 'line_loading_snapshot.csv'));
    writetable(gen_snapshot, fullfile(out_dir, 'generator_dispatch_snapshot.csv'));
    fid = fopen(fullfile(out_dir, 'baseflow_sensitivity_log.txt'), 'w');
    fprintf(fid, 'policy_id,%s\nscenario_id,%s\nbase_case_only,1\nmarkov_run,0\ncascade_run,0\nlocal_search,0\nparameter_tuning,0\nfinal_summary_write,0\n', policy, scenario_id);
    fclose(fid);
end

function loading = compute_loading(pf, rate)
sf = sqrt(pf.branch(:, 14).^2 + pf.branch(:, 15).^2);
st = sqrt(pf.branch(:, 16).^2 + pf.branch(:, 17).^2);
loading = max(sf, st) ./ rate;
loading(pf.branch(:, 11) <= 0) = 0;
end

function value = get_field_or_default(s, field_name, default_value)
if isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir')
    mkdir(pathname);
end
end

function fill_generator_pg_changes(out_root, policies)
for p = policies
    p11 = fullfile(out_root, char(p), 'wind_speed_11_28', 'generator_dispatch_snapshot.csv');
    p12 = fullfile(out_root, char(p), 'wind_speed_12_00', 'generator_dispatch_snapshot.csv');
    if ~isfile(p11) || ~isfile(p12)
        continue;
    end
    g11 = readtable(p11, 'TextType', 'string', 'Delimiter', ',');
    g12 = readtable(p12, 'TextType', 'string', 'Delimiter', ',');
    g11.PG_change_from_11_28 = zeros(height(g11), 1);
    g12.PG_change_from_11_28 = nan(height(g12), 1);
    for i = 1:height(g12)
        idx = find(g11.gen_bus == g12.gen_bus(i) & string(g11.gen_type) == string(g12.gen_type(i)), 1);
        if ~isempty(idx)
            g12.PG_change_from_11_28(i) = g12.PG_mw(i) - g11.PG_mw(idx);
        end
    end
    writetable(g11, p11);
    writetable(g12, p12);
end
end
