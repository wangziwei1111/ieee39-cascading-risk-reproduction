function main_select_wind_trip_probability_next_action()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'renewable_trip');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
log_path = fullfile(out_dir, 'post_wind_trip_probability_action_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'main_select_wind_trip_probability_next_action\n');
audit_path = fullfile(out_dir, 'wind_trip_probability_input_source_audit.csv');
dry_path = fullfile(out_dir, 'wind_trip_probability_dry_run_table.csv');
summary_path = fullfile(out_dir, 'wind_speed_wt_probability_smoke_summary.csv');
delta_path = fullfile(out_dir, 'wind_speed_wt_probability_delta.csv');
post_curve_path = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix', ...
    'post_curve_fix_formal_pilot_action.csv');

reason = "unknown";
go_no_go = "keep_as_diagnostic_only";
recommended = "Keep P_WT record-only until voltage/frequency records and paper interval function are confirmed.";

if exist(audit_path, 'file') ~= 2 || exist(dry_path, 'file') ~= 2 || exist(summary_path, 'file') ~= 2
    reason = "missing_required_diagnostic_outputs";
    go_no_go = "implement_voltage_frequency_inputs_first";
    recommended = "Generate input audit, dry-run, and smoke outputs before any formal pilot integration.";
else
    A = readtable(audit_path, 'TextType', 'string');
    D = readtable(dry_path, 'TextType', 'string');
    S = readtable(summary_path, 'TextType', 'string');
    voltage_ok = is_available(A, "wind_bus_voltage_pu") || is_available(A, "stage_power_flow_bus_voltage");
    dry_ok = all(logical(D.pass_fail));
    missing_inputs = sum(S.missing_input_count);
    max_p = max(S.max_P_wt, [], 'omitnan');
    if ~voltage_ok || missing_inputs > 0
        reason = "missing_voltage_frequency_inputs";
        go_no_go = "implement_voltage_frequency_inputs_first";
        recommended = "Do not integrate P_WT into chain probability until U/f inputs are reliably recorded.";
    elseif ~dry_ok
        reason = "P_WT_dry_run_failed";
        go_no_go = "stop_calibration";
        recommended = "Fix P_WT formula implementation before any additional diagnostic run.";
    elseif max_p == 0
        reason = "P_WT_all_zero_in_wind_speed_smoke";
        go_no_go = "keep_as_diagnostic_only";
        recommended = "P_WT works in dry-run but is zero in current wind-speed smoke; trend remains line/severity driven.";
    else
        reason = "P_WT_record_available_nonzero";
        go_no_go = "record_wind_trip_probability_in_formal_pilot";
        recommended = "Consider a formal pilot with record-only P_WT trace, still not multiplying into chain probability.";
    end
end

if exist(delta_path, 'file') == 2
    Delta = readtable(delta_path, 'TextType', 'string');
    if any(contains(string(Delta.diagnosis), "higher_at_12mps"))
        reason = "P_WT_may_contribute_to_wind_speed_reverse_trend";
        go_no_go = "record_wind_trip_probability_in_formal_pilot";
    end
end
if exist(post_curve_path, 'file') == 2
    P = readtable(post_curve_path, 'TextType', 'string');
    post_curve_go = "";
    if ismember('go_no_go', P.Properties.VariableNames)
        post_curve_go = string(P.go_no_go(1));
    elseif ismember('go_no_go_', P.Properties.VariableNames)
        post_curve_go = string(P.go_no_go_(1));
    end
    if post_curve_go == "fix_metric_or_scenario_first" && go_no_go == "keep_as_diagnostic_only"
        recommended = recommended + " Post-curve-fix action still says fix_metric_or_scenario_first; no local search.";
    end
end

T = table(true, reason, go_no_go, recommended, ...
    "diagnostic interval probabilities are not original paper parameters; no final_summary or local search.", ...
    'VariableNames', {'selected','reason','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_dir, 'post_wind_trip_probability_action.csv'));
fprintf(fid, 'status=done\ngo_no_go=%s\nreason=%s\n', go_no_go, reason);
end

function ok = is_available(A, item)
row = A(string(A.source_item) == item, :);
ok = ~isempty(row) && logical(row.available(1));
end
