function main_select_wind_speed_common_random_rerun_readiness()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
pair_path = fullfile(out_root, 'wind_speed_random_seed_pairing_audit.csv');
delta_path = fullfile(out_root, 'wind_speed_paired_chain_risk_delta_summary.csv');
candidate_delta_path = fullfile(out_root, 'wind_speed_tail_candidate_probability_delta.csv');
wt_action_path = fullfile(project_root, 'results', 'calibration', 'renewable_trip', 'post_wind_trip_probability_action.csv');

Pair = read_if_exists(pair_path);
Delta = read_if_exists(delta_path);
Cand = read_if_exists(candidate_delta_path);
WtAction = read_if_exists(wt_action_path);

pairing_ok = ~isempty(Pair) && all(ismember(string(Pair.pairing_status), ["fully_pairable","paired_by_initial_branch_trial"]));
cri_direction = "unknown";
dominant_driver = "unknown";
if ~isempty(Delta) && ismember("metric_name", string(Delta.Properties.VariableNames))
    C = Delta(Delta.metric_name == "CRI", :);
    if ~isempty(C)
        if mean(C.mean_delta, 'omitnan') > 0
            cri_direction = "12mps_higher_than_11p28_in_paired_delta";
        elseif mean(C.mean_delta, 'omitnan') < 0
            cri_direction = "12mps_lower_than_11p28_in_paired_delta";
        else
            cri_direction = "no_mean_delta";
        end
        dominant_driver = join(unique(string(C.dominant_driver)), ";");
    end
end

candidate_note = "candidate probability delta unavailable";
if ~isempty(Cand)
    higher = sum(string(Cand.likely_effect) == "higher_probability_and_selected_more_at_12mps" | ...
        string(Cand.likely_effect) == "higher_candidate_probability_at_12mps");
    candidate_note = "tail candidate rows with higher 12mps effect=" + string(higher);
end

wind_trip_note = "wind trip action unavailable";
if ~isempty(WtAction)
    wind_trip_note = "P_WT action=" + first_existing_string(WtAction, ["recommended_action","recommended_next_action","go_no_go"]);
end

if ~pairing_ok
    ready = true;
    recommended_action = "prepare_common_random_wind_speed_only_rerun";
    reason = "Existing samples are not fully pairable; a common-random rerun would isolate sampling noise.";
elseif cri_direction == "12mps_higher_than_11p28_in_paired_delta"
    ready = false;
    recommended_action = "diagnose_probability_or_severity_basis_before_rerun";
    reason = "Paired samples already show the reversal direction, so first inspect probability/severity drivers.";
else
    ready = true;
    recommended_action = "optional_more_trials_wind_speed_only_after_driver_review";
    reason = "Pairing is adequate; rerun readiness is optional and should follow driver review.";
end

T = table("wind_speed_11_28_vs_12_00", pairing_ok, ready, recommended_action, reason, ...
    cri_direction, dominant_driver, candidate_note, wind_trip_note, ...
    "Readiness only; no common-random rerun was executed.", ...
    'VariableNames', {'comparison_id','pairing_ok','common_random_rerun_ready','recommended_action', ...
    'reason','paired_cri_direction','paired_delta_dominant_driver','candidate_probability_note', ...
    'wind_trip_probability_note','note'});
writetable(T, fullfile(out_root, 'wind_speed_common_random_rerun_readiness.csv'));
end

function T = read_if_exists(path)
if exist(path, 'file') == 2
    T = readtable(path, 'TextType', 'string');
else
    T = table();
end
end

function v = first_existing_string(T, names)
v = "";
for i = 1:numel(names)
    if ismember(names(i), string(T.Properties.VariableNames))
        v = string(T.(char(names(i)))(1));
        return;
    end
end
end
