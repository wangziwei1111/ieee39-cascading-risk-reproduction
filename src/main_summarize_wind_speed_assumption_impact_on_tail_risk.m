function main_summarize_wind_speed_assumption_impact_on_tail_risk()
%MAIN_SUMMARIZE_WIND_SPEED_ASSUMPTION_IMPACT_ON_TAIL_RISK Summarize existing tail mechanism.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'wind_speed_scenario_assumption');
ensure_dir(out_dir);

audit = read_csv(fullfile(out_dir, 'current_wind_speed_scenario_assumption_audit.csv'));
baseflow = read_csv(fullfile(project_root, 'results/calibration/severity_formula/wind_speed_after_severity_fix_baseflow_delta_summary.csv'));
candidate = read_csv(fullfile(project_root, 'results/calibration/severity_formula/wind_speed_after_severity_fix_tail_candidate_branch_delta.csv'));
comparison = read_csv(fullfile(project_root, 'results/calibration/severity_formula/wind_speed_before_after_severity_fix_comparison.csv'));
action = read_csv(fullfile(project_root, 'results/calibration/severity_formula/post_wind_speed_after_severity_fix_tail_action.csv'));

pg11 = audit_value(audit, 'actual_wind_pg_total_mw_in_case', 'wind_speed_11_28_value');
pg12 = audit_value(audit, 'actual_wind_pg_total_mw_in_case', 'wind_speed_12_00_value');
delta_pg = pg12 - pg11;
loading_increase_count = count_positive_unique(baseflow, 'candidate_branch', 'delta_line_loading');
pl_increase_count = count_positive_unique(baseflow, 'candidate_branch', 'delta_P_L');
tail_more_count = count_tail_more(candidate);
risk_higher = risk_higher_text(comparison);

rows = {};
rows = add(rows, 'wind_pg_delta_12_minus_11', num2str(delta_pg, '%.6f'), 'Current model injects about this much additional wind PG at 12.00 m/s versus 11.28 m/s.', 'Confirms whether paper also absorbs this additional wind power.', 'Derived from current_wind_speed_scenario_assumption_audit.csv.');
rows = add(rows, 'number_of_branches_with_loading_increase_at_12mps', string(loading_increase_count), 'Existing base-flow diagnostic shows how many branches have higher loading at 12.00 m/s.', 'If paper dispatch differs, this count may change.', 'Counted from wind_speed_after_severity_fix_baseflow_delta_summary.csv.');
rows = add(rows, 'number_of_branches_with_P_L_increase_at_12mps', string(pl_increase_count), 'Existing probability diagnostic shows how many candidate branches have higher P_L at 12.00 m/s.', 'Directly tied to P_line tail under current scenario assumption.', 'Counted from delta_P_L > 0.');
rows = add(rows, 'number_of_tail_branches_only_or_more_at_12mps', string(tail_more_count), 'Tail candidate table has this many branches with more 12.00 m/s tail occurrences.', 'Shows why trend check should focus on base-flow and dispatch assumptions.', 'Counted by unique candidate_branch with tail_occurrence_count_12_00 > tail_occurrence_count_11_28.');
rows = add(rows, 'whether_12mps_risk_higher_after_all_formula_fixes', risk_higher, 'After severity and probability formula fixes, 12.00 m/s remains higher in current diagnostics.', 'Opposite of Table 4-6 target direction; requires paper scenario assumption confirmation.', 'Read from wind_speed_before_after_severity_fix_comparison.csv.');
rows = add(rows, 'likely_current_model_mechanism', 'higher_wind_pg_changes_redispatch_and_baseflow_then_increases_some_line_loading_P_L_tail', 'Current wind_plus_redispatch and higher 12 m/s wind output create a baseflow-driven probability tail.', 'Need confirm whether paper uses the same dispatch/absorption mechanism.', 'Consistent with dominant_root_cause=' + get_first(action, 'dominant_root_cause') + '.');
rows = add(rows, 'paper_assumption_needed_to_explain_opposite_trend', 'dispatch_absorption_curtailment_slack_or_wind_trip_probability_assumption', 'A different paper assumption could reduce line loading or risk at 12 m/s.', 'This is the key manual confirmation target before any formal pilot.', 'No new parameter tuning should be done before this is resolved.');
rows = add(rows, 'recommended_manual_check', 'confirm_paper_wind_speed_dispatch_absorption_power_flow_redistribution_assumptions', 'Manual evidence is needed before another rerun.', 'Matches post_wind_speed_after_severity_fix_tail_action go/no-go.', get_first(action, 'recommended_next_action'));

T = cell2table(rows, 'VariableNames', {'summary_item','value','interpretation','paper_confirmation_relevance','note'});
writetable(T, fullfile(out_dir, 'wind_speed_assumption_impact_summary.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'wind_speed_assumption_impact_summary.csv'));
end

function T = read_csv(pathname)
if isfile(pathname)
    T = readtable(pathname, 'TextType', 'string', 'Delimiter', ',');
else
    T = table();
end
end

function value = audit_value(T, item, col)
value = NaN;
if isempty(T) || ~all(ismember(["assumption_item", col], string(T.Properties.VariableNames)))
    return;
end
idx = find(string(T.assumption_item) == item, 1);
if ~isempty(idx)
    value = str2double(string(T.(col)(idx)));
end
end

function n = count_positive_unique(T, key_col, value_col)
n = 0;
needed = string({key_col, value_col});
if isempty(T) || ~all(ismember(needed, string(T.Properties.VariableNames)))
    return;
end
idx = str2double(string(T.(value_col))) > 0;
if any(idx)
    n = numel(unique(string(T.(key_col)(idx))));
end
end

function n = count_tail_more(T)
n = 0;
needed = ["candidate_branch","tail_occurrence_count_11_28","tail_occurrence_count_12_00"];
if isempty(T) || ~all(ismember(needed, string(T.Properties.VariableNames)))
    return;
end
idx = str2double(string(T.tail_occurrence_count_12_00)) > str2double(string(T.tail_occurrence_count_11_28));
if any(idx)
    n = numel(unique(string(T.candidate_branch(idx))));
end
end

function txt = risk_higher_text(T)
if isempty(T) || ~ismember('after_direction', T.Properties.VariableNames)
    txt = "unknown_missing_comparison";
    return;
end
dirs = string(T.after_direction);
if any(contains(dirs, '12mps_higher'))
    txt = "yes_12mps_higher_after_severity_fix";
elseif any(contains(dirs, '12mps_lower'))
    txt = "no_12mps_lower_after_severity_fix";
else
    txt = "unknown_direction";
end
end

function rows = add(rows, varargin)
rows(end + 1, :) = varargin; %#ok<AGROW>
end

function txt = get_first(T, field)
if isempty(T) || ~ismember(field, T.Properties.VariableNames)
    txt = "missing";
else
    txt = string(T.(field)(1));
end
end

function ensure_dir(pathname)
if ~exist(pathname, 'dir')
    mkdir(pathname);
end
end
