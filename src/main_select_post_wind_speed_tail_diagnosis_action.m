function main_select_post_wind_speed_tail_diagnosis_action()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
ready_path = fullfile(out_root, 'wind_speed_common_random_rerun_readiness.csv');
delta_path = fullfile(out_root, 'wind_speed_paired_chain_risk_delta_summary.csv');
branch_delta_path = fullfile(out_root, 'wind_speed_tail_branch_delta_11_28_vs_12_00.csv');
wt_summary_path = fullfile(project_root, 'results', 'calibration', 'renewable_trip', 'wind_speed_wt_probability_smoke_summary.csv');

Ready = read_if_exists(ready_path);
Delta = read_if_exists(delta_path);
Branch = read_if_exists(branch_delta_path);
Wt = read_if_exists(wt_summary_path);

if isempty(Ready)
    action = "rerun_readiness_missing";
    go_no_go = "hold";
    reason = "Common-random readiness table is missing.";
elseif ~logical(first_existing_value(Ready, ["pairing_ok","pairing_ok_"], 1))
    action = "prepare_common_random_wind_speed_only_rerun";
    go_no_go = "ready_for_small_diagnostic_rerun_only";
    reason = "Existing 11.28 and 12.00 mps samples are not fully paired.";
else
    [driver, mean_delta] = cri_driver(Delta);
    if contains(driver, "chain_probability")
        action = "inspect_line_probability_tail_driver_before_rerun";
        go_no_go = "do_not_start_local_search";
        reason = "Paired CRI reversal is driven by chain probability changes.";
    elseif contains(driver, "severity")
        action = "inspect_stage_severity_tail_driver_before_rerun";
        go_no_go = "do_not_start_local_search";
        reason = "Paired CRI reversal is driven by severity changes.";
    elseif mean_delta > 0
        action = "increase_trials_for_wind_speed_only_after_driver_review";
        go_no_go = "ready_for_small_diagnostic_rerun_only";
        reason = "Paired CRI delta remains opposite to the expected wind-speed trend.";
    else
        action = "keep_after_curve_fix_wind_speed_result_as_diagnostic";
        go_no_go = "no_rerun_now";
        reason = "Paired delta does not require immediate rerun.";
    end
end

branch_note = "branch delta unavailable";
if ~isempty(Branch)
    branch_note = "branch_delta_rows=" + string(height(Branch));
end
wt_note = "P_WT smoke unavailable";
if ~isempty(Wt)
    wt_note = "max_P_wt_in_smoke=" + string(max(Wt.max_P_wt, [], 'omitnan'));
end

T = table(action, go_no_go, reason, branch_note, wt_note, ...
    "No local search, formal rerun, final_summary write, or P_WT integration was performed.", ...
    'VariableNames', {'recommended_action','go_no_go','reason','tail_branch_note','wind_trip_probability_note','guardrail_note'});
writetable(T, fullfile(out_root, 'post_wind_speed_tail_diagnosis_action.csv'));
end

function [driver, mean_delta] = cri_driver(Delta)
driver = "unknown";
mean_delta = NaN;
if isempty(Delta), return; end
if ~ismember("metric_name", string(Delta.Properties.VariableNames)), return; end
C = Delta(Delta.metric_name == "CRI", :);
if isempty(C), return; end
driver = join(unique(string(C.dominant_driver)), ";");
mean_delta = mean(C.mean_delta, 'omitnan');
end

function T = read_if_exists(path)
if exist(path, 'file') == 2
    T = readtable(path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
else
    T = table();
end
end

function v = first_existing_value(T, names, default_value)
v = default_value;
vars = string(T.Properties.VariableNames);
for i = 1:numel(names)
    idx = find(vars == names(i), 1);
    if ~isempty(idx)
        v = T.(T.Properties.VariableNames{idx})(1);
        return;
    end
end
end
