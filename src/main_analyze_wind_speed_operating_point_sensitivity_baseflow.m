function main_analyze_wind_speed_operating_point_sensitivity_baseflow()
project_root = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
in_root = fullfile(root, 'baseflow_operating_point_sensitivity');
policies = ["wind_plus_redispatch_current","slack_only_balance","proportional_conventional_redispatch", ...
    "designated_generator_redispatch","wind_curtail_to_constant_absorbed_power","constant_total_generation_dispatch"];
rows = {};
for p = policies
    b11 = read_csv(fullfile(in_root, p, 'wind_speed_11_28', 'base_power_flow_snapshot.csv'));
    b12 = read_csv(fullfile(in_root, p, 'wind_speed_12_00', 'base_power_flow_snapshot.csv'));
    l11 = read_csv(fullfile(in_root, p, 'wind_speed_11_28', 'line_loading_snapshot.csv'));
    l12 = read_csv(fullfile(in_root, p, 'wind_speed_12_00', 'line_loading_snapshot.csv'));
    if isempty(b11) || isempty(b12) || isempty(l11) || isempty(l12)
        rows = add(rows, p, false, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
            "pf_failed", "invalid_pf", "missing snapshot");
        continue;
    end
    conv_both = logical(b11.base_pf_converged(1)) && logical(b12.base_pf_converged(1));
    dw = b12.wind_absorbed_power_total_mw(1) - b11.wind_absorbed_power_total_mw(1);
    dslack = b12.slack_pg_mw(1) - b11.slack_pg_mw(1);
    dconv = b12.total_conventional_generation_mw(1) - b11.total_conventional_generation_mw(1);
    dmax = b12.max_line_loading_pu(1) - b11.max_line_loading_pu(1);
    dmean = b12.mean_line_loading_pu(1) - b11.mean_line_loading_pu(1);
    [l11s, l12s] = align_by_branch(l11, l12);
    nload = sum(l12s.line_loading_pu > l11s.line_loading_pu + 1e-9);
    npl = sum(l12s.P_L > l11s.P_L + 1e-12);
    if ~conv_both
        proxy = "pf_failed"; status = "invalid_pf";
    elseif dmax < -1e-6 && dmean <= 1e-6 && npl < height(l11s)/2
        proxy = "12mps_likely_lower_risk"; status = "candidate_policy_for_wind_speed_diagnostic_rerun";
    elseif dmax > 1e-6 || dmean > 1e-6 || npl >= height(l11s)/2
        proxy = "12mps_likely_higher_risk"; status = "diagnostic_only";
    else
        proxy = "mixed_or_unclear"; status = "not_candidate_currently";
    end
    rows = add(rows, p, conv_both, b11.wind_absorbed_power_total_mw(1), b12.wind_absorbed_power_total_mw(1), dw, ...
        b11.slack_pg_mw(1), b12.slack_pg_mw(1), dslack, b11.total_conventional_generation_mw(1), b12.total_conventional_generation_mw(1), dconv, ...
        b11.max_line_loading_pu(1), b12.max_line_loading_pu(1), dmax, b11.mean_line_loading_pu(1), b12.mean_line_loading_pu(1), dmean, ...
        nload, npl, proxy, status, "Base-case sensitivity only; not Markov and not paper-confirmed.");
end
T = cell2table(rows, 'VariableNames', {'policy_id','pf_converged_both','wind_absorbed_11_28','wind_absorbed_12_00','delta_wind_absorbed','slack_pg_11_28','slack_pg_12_00','delta_slack_pg','conventional_pg_11_28','conventional_pg_12_00','delta_conventional_pg','max_line_loading_11_28','max_line_loading_12_00','delta_max_line_loading','mean_line_loading_11_28','mean_line_loading_12_00','delta_mean_line_loading','branch_count_loading_increase_at_12','branch_count_PL_increase_at_12','risk_direction_proxy','policy_effect_status','note'});
writetable(T, fullfile(root, 'wind_speed_operating_point_sensitivity_summary.csv'));
fprintf('Wrote wind speed operating point sensitivity summary.\n');
end

function T = read_csv(pathname)
if isfile(pathname), T = readtable(pathname, 'TextType', 'string', 'Delimiter', ','); else, T = table(); end
end

function [A, B] = align_by_branch(A, B)
[~, ia, ib] = intersect(A.branch_id, B.branch_id);
A = A(ia, :); B = B(ib, :);
end

function rows = add(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end
