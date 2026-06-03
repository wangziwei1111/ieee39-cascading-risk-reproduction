function main_compare_tail_branches_under_wind_speed_operating_point_policies()
project_root = fileparts(fileparts(mfilename('fullpath')));
root = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
in_root = fullfile(root, 'baseflow_operating_point_sensitivity');
tail_path = fullfile(project_root, 'results', 'calibration', 'severity_formula', 'wind_speed_after_severity_fix_tail_candidate_branch_delta.csv');
tail = readtable(tail_path, 'TextType', 'string', 'Delimiter', ',');
tail.importance = tail.tail_occurrence_count_12_00 + tail.tail_occurrence_count_11_28;
[~, order] = sort(tail.importance, 'descend');
top = tail(order(1:min(10, height(tail))), :);
policies = ["wind_plus_redispatch_current","slack_only_balance","proportional_conventional_redispatch", ...
    "designated_generator_redispatch","wind_curtail_to_constant_absorbed_power","constant_total_generation_dispatch"];
rows = {};
for p = policies
    l11 = read_csv(fullfile(in_root, p, 'wind_speed_11_28', 'line_loading_snapshot.csv'));
    l12 = read_csv(fullfile(in_root, p, 'wind_speed_12_00', 'line_loading_snapshot.csv'));
    for k = 1:height(top)
        br = top.candidate_branch(k);
        a = l11(l11.branch_id == br, :);
        b = l12(l12.branch_id == br, :);
        if isempty(a) || isempty(b)
            rows = add(rows, p, br, k, NaN, NaN, NaN, NaN, NaN, NaN, false, false, "missing_snapshot", "Missing line snapshot.");
        else
            dl = b.line_loading_pu(1) - a.line_loading_pu(1);
            dp = b.P_L(1) - a.P_L(1);
            reduces_load = b.line_loading_pu(1) < a.line_loading_pu(1);
            reduces_pl = b.P_L(1) < a.P_L(1);
            if reduces_load && reduces_pl
                status = "candidate_policy_for_user_confirmation";
            elseif reduces_load || reduces_pl
                status = "mixed_diagnostic_only";
            else
                status = "not_candidate_currently";
            end
            rows = add(rows, p, br, k, a.line_loading_pu(1), b.line_loading_pu(1), dl, a.P_L(1), b.P_L(1), dp, reduces_load, reduces_pl, status, "Top tail branch comparison under base-case policy only.");
        end
    end
end
T = cell2table(rows, 'VariableNames', {'policy_id','candidate_branch','tail_importance_rank','line_loading_11_28','line_loading_12_00','delta_line_loading','P_L_11_28','P_L_12_00','delta_P_L','whether_policy_reduces_12mps_tail_branch_loading','whether_policy_reduces_12mps_tail_branch_PL','policy_candidate_status','note'});
writetable(T, fullfile(root, 'tail_branch_operating_point_policy_comparison.csv'));
fprintf('Wrote tail branch operating point policy comparison.\n');
end

function T = read_csv(pathname)
if isfile(pathname), T = readtable(pathname, 'TextType', 'string', 'Delimiter', ','); else, T = table(); end
end

function rows = add(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end
