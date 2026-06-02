function main_check_wind_speed_tail_attribution_diagnosis()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
required = [
    "wind_speed_var_tail_attribution.csv"
    "wind_speed_tail_branch_contribution_summary.csv"
    "wind_speed_tail_branch_delta_11_28_vs_12_00.csv"
    "wind_speed_random_seed_pairing_audit.csv"
    "wind_speed_paired_chain_risk_delta.csv"
    "wind_speed_paired_chain_risk_delta_summary.csv"
    "wind_speed_tail_candidate_probability_driver.csv"
    "wind_speed_tail_candidate_probability_delta.csv"
    "wind_speed_common_random_rerun_readiness.csv"
    "post_wind_speed_tail_diagnosis_action.csv"
];
log_lines = strings(0,1);
pass = true;
for i = 1:numel(required)
    path = fullfile(out_root, required(i));
    ok = exist(path, 'file') == 2;
    pass = pass && ok;
    log_lines(end+1,1) = sprintf('%s: %s', required(i), status_word(ok)); %#ok<AGROW>
end

tail_path = fullfile(out_root, 'wind_speed_var_tail_attribution.csv');
if exist(tail_path, 'file') == 2
    Tail = readtable(tail_path, 'TextType', 'string');
    has_two_speeds = all(ismember(["wind_speed_11_28","wind_speed_12_00"], unique(string(Tail.scenario_id))));
    has_metrics = all(ismember(["SLLR","SLFOR","SNVOR","CRI"], unique(string(Tail.metric_name))));
    pass = pass && has_two_speeds && has_metrics;
    log_lines(end+1,1) = "tail_two_wind_speeds: " + status_word(has_two_speeds);
    log_lines(end+1,1) = "tail_required_metrics: " + status_word(has_metrics);
end

pair_path = fullfile(out_root, 'wind_speed_random_seed_pairing_audit.csv');
if exist(pair_path, 'file') == 2
    Pair = readtable(pair_path, 'TextType', 'string');
    log_lines(end+1,1) = "pairing_status_values: " + join(unique(string(Pair.pairing_status)), ";");
end

action_path = fullfile(out_root, 'post_wind_speed_tail_diagnosis_action.csv');
if exist(action_path, 'file') == 2
    Action = readtable(action_path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    action_values = get_string_column(Action, ["recommended_action","recommended_action_"]);
    forbidden = contains(action_values, "local_search") | contains(action_values, "formal");
    pass = pass && ~any(forbidden);
    log_lines(end+1,1) = "post_action_guardrail_no_local_search_or_formal_rerun: " + status_word(~any(forbidden));
    if ~isempty(action_values)
        log_lines(end+1,1) = "post_action: " + action_values(1);
    end
end

final_summary_paths = [
    string(fullfile(project_root, 'results', 'final_summary'));
    string(fullfile(project_root, 'results', 'final_summary.csv'))
];
log_lines(end+1,1) = "final_summary_not_written_by_this_check: manual_guardrail_confirmed";
for i = 1:numel(final_summary_paths)
    log_lines(end+1,1) = "final_summary_path_observed=" + string(final_summary_paths(i)) + ", exists=" + string(exist(final_summary_paths(i), 'file') == 2 || exist(final_summary_paths(i), 'dir') == 7);
end

if pass
    log_lines(end+1,1) = "overall_status: pass";
else
    log_lines(end+1,1) = "overall_status: fail";
end

log_path = fullfile(out_root, 'wind_speed_tail_attribution_diagnosis_check_log.txt');
writelines(log_lines, log_path);
if ~pass
    error('Wind-speed tail attribution diagnosis check failed. See %s', log_path);
end
end

function s = status_word(ok)
if ok
    s = "pass";
else
    s = "fail";
end
end

function values = get_string_column(T, names)
values = strings(0,1);
vars = string(T.Properties.VariableNames);
for i = 1:numel(names)
    idx = find(vars == names(i), 1);
    if ~isempty(idx)
        values = string(T.(T.Properties.VariableNames{idx}));
        return;
    end
end
end
