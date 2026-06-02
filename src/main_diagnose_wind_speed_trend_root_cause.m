function main_diagnose_wind_speed_trend_root_cause()
%MAIN_DIAGNOSE_WIND_SPEED_TREND_ROOT_CAUSE Consolidate wind-speed trend diagnosis.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
cfg_audit = readtable(fullfile(out_root, 'wind_speed_scenario_config_audit.csv'), 'TextType','string', 'Delimiter', ',');
curve = readtable(fullfile(out_root, 'wind_power_curve_speed_scan_audit.csv'), 'TextType','string', 'Delimiter', ',');
snap = readtable(fullfile(out_root, 'wind_speed_case_power_snapshot.csv'), 'TextType','string', 'Delimiter', ',');
trip = readtable(fullfile(out_root, 'wind_trip_probability_speed_scan_audit.csv'), 'TextType','string', 'Delimiter', ',');
delta = readtable(fullfile(out_root, 'wind_speed_11_28_vs_12_00_distribution_delta.csv'), 'TextType','string', 'Delimiter', ',');
cand = readtable(fullfile(out_root, 'wind_speed_candidate_probability_summary.csv'), 'TextType','string', 'Delimiter', ',');
rows = table();

rows = add_row(rows, "scenario_config_correct", all(cfg_audit.config_match_status=="match"), ...
    sprintf('matched_rows=%d/%d', sum(cfg_audit.config_match_status=="match"), height(cfg_audit)), false, ...
    "No config fix needed if all rows match.", "Scenario labels/capacity/buses are audited from snapshots.");
rows = add_row(rows, "wind_power_curve_matches_paper", all(curve.match_status=="match"), ...
    sprintf('mismatch_rows=%d; 3000MW differences include %.6g MW at 11.28 and %.6g MW at 12.00', ...
    sum(curve.match_status~="match"), curve.difference_mw(curve.rated_wind_capacity_mw==3000 & curve.wind_speed_mps==11.28), ...
    curve.difference_mw(curve.rated_wind_capacity_mw==3000 & curve.wind_speed_mps==12.00)), true, ...
    "If this fails, keep blocking parameter refinement and fix the wind-power curve first.", ...
    "Paper-aligned dry-run curve check after curve entry fix.");
pg11 = snap.actual_wind_pg_total_mw_in_case(snap.scenario_id=="wind_speed_11_28");
pg12 = snap.actual_wind_pg_total_mw_in_case(snap.scenario_id=="wind_speed_12_00");
rows = add_row(rows, "actual_case_wind_pg_changes_with_speed", ~isempty(pg11)&&~isempty(pg12)&&pg11(1)<pg12(1), ...
    sprintf('actual_wind_pg_11_28=%.6g; actual_wind_pg_12_00=%.6g', first_or_nan(pg11), first_or_nan(pg12)), false, ...
    "No case-builder fix needed if 12.00 has higher actual wind PG.", "Dry-run base case only.");
rows = add_row(rows, "base_case_power_flow_changes_reasonably", all(snap.base_pf_converged), ...
    sprintf('base_pf_converged=%s; max_loading=[%s]', mat2str(logical(snap.base_pf_converged')), join(string(snap.max_base_line_loading_pu'), ',')), false, ...
    "Use snapshot to inspect whether base-case loading changes explain severity direction.", "Base PF only, not cascade.");
rows = add_row(rows, "wind_trip_probability_available", any(trip.wind_trip_probability_available), ...
    sprintf('available_rows=%d/%d', sum(trip.wind_trip_probability_available), height(trip)), true, ...
    "Wind-trip probability remains a warning before interpreting wind-speed benchmark trends.", ...
    "Current full-event pilot has no actual wind-trip probability records.");
cri_sev = delta(delta.metric_name=="basic_CRI" & delta.sample_variant=="severity_only",:);
rows = add_row(rows, "severity_distribution_direction", all(cri_sev.direction_match), ...
    sprintf('severity_basic_CRI_direction_matches=%d/%d', sum(cri_sev.direction_match), height(cri_sev)), true, ...
    "Old full-event pilot distribution is stale after curve fix; rerun is required before using this as calibration evidence.", ...
    "stale_after_curve_fix; paper direction expects 12.00 lower than 11.28.");
cri_full = delta(delta.metric_name=="CRI_display" & delta.sample_variant=="full_event_chain_risk_display",:);
rows = add_row(rows, "chain_probability_distribution_direction", all(cri_full.direction_match), ...
    sprintf('full_event_CRI_direction_matches=%d/%d', sum(cri_full.direction_match), height(cri_full)), true, ...
    "Old full-event pilot distribution is stale after curve fix; rerun is required before using this as calibration evidence.", ...
    "stale_after_curve_fix; uses existing 10-trial pilot.");
candidate_note = summarize_candidate(cand);
rows = add_row(rows, "candidate_probability_direction", contains(candidate_note,"12.00 higher"), candidate_note, true, ...
    "Use branch-level candidate deltas to see whether line probability dominates trend.", "Candidate probability is from existing full-event trace.");
rows = add_row(rows, "paper_direction_vs_sim_direction", all(cri_full.direction_match), ...
    sprintf('paper_direction=12.00 lower; matched full_event_CRI rows=%d/%d', sum(cri_full.direction_match), height(cri_full)), true, ...
    "Do not enter parameter refinement until a post-curve-fix formal pilot rerun confirms the wind-speed direction.", ...
    "Old full-event pilot predates the curve fix.");

root = infer_root(rows);
rows = [rows; table("likely_root_cause", "diagnosed", root.evidence, true, root.fix, root.cause, ...
    'VariableNames', rows.Properties.VariableNames)];
writetable(rows, fullfile(out_root, 'wind_speed_trend_root_cause_diagnosis.csv'));
end

function rows = add_row(rows, item, pass, evidence, blocking, fix, note)
if pass, status = "pass"; else, status = "fail"; end
rows = [rows; table(string(item), status, string(evidence), logical(blocking), string(fix), string(note), ...
    'VariableNames', {'diagnosis_item','status','evidence','blocking_for_parameter_refinement','recommended_fix','note'})];
end

function x = first_or_nan(v)
if isempty(v), x = NaN; else, x = v(1); end
end

function s = summarize_candidate(cand)
sc = unique(cand.parameter_set_id);
parts = strings(0,1);
for p = sc'
    a = cand(cand.parameter_set_id==p & cand.scenario_id=="wind_speed_11_28",:);
    b = cand(cand.parameter_set_id==p & cand.scenario_id=="wind_speed_12_00",:);
    if ~isempty(a) && ~isempty(b)
        if b.mean_candidate_probability > a.mean_candidate_probability
            dir = "12.00 higher";
        elseif b.mean_candidate_probability < a.mean_candidate_probability
            dir = "12.00 lower";
        else
            dir = "no effect";
        end
        parts(end+1) = p + ":" + dir; %#ok<AGROW>
    end
end
s = join(parts, "; ");
end

function root = infer_root(rows)
if any(rows.diagnosis_item=="scenario_config_correct" & rows.status=="fail")
    cause = "wind_speed_not_applied_to_case"; fix = "fix_wind_speed_case_builder";
elseif any(rows.diagnosis_item=="wind_power_curve_matches_paper" & rows.status=="fail")
    cause = "wind_power_curve_mismatch"; fix = "fix_wind_power_curve";
elseif any(rows.diagnosis_item=="wind_trip_probability_available" & rows.status=="fail")
    cause = "wind_trip_model_missing"; fix = "rerun_full_event_formal_pilot_after_curve_fix_with_wind_trip_warning";
elseif any(rows.diagnosis_item=="severity_distribution_direction" & rows.status=="fail")
    cause = "severity_model_dominates_wrong_direction"; fix = "fix_metric_definition_first";
elseif any(rows.diagnosis_item=="chain_probability_distribution_direction" & rows.status=="fail")
    cause = "chain_probability_dominates_wrong_direction"; fix = "inspect_candidate_probability_basis";
else
    cause = "unknown_need_formal_rerun_with_more_trials"; fix = "rerun_full_event_formal_pilot_with_more_trials";
end
root.cause = cause;
root.fix = fix;
root.evidence = "Root cause selected from scenario config, wind curve, wind-trip availability, severity, and chain probability diagnostics.";
end
