function main_audit_candidate_selection_consistency_terminal_aware()
%MAIN_AUDIT_CANDIDATE_SELECTION_CONSISTENCY_TERMINAL_AWARE Audit selection consistency excluding terminal recording stages.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
candidate_path = fullfile(root_dir, 'full_event_trace_smoke', 'candidate_probability_trace.csv');
stage_path = fullfile(root_dir, 'full_event_trace_smoke', 'stage_transition_probability_details.csv');
out_path = fullfile(root_dir, 'candidate_selection_consistency_terminal_aware_audit.csv');
summary_path = fullfile(root_dir, 'candidate_selection_consistency_terminal_aware_summary.csv');
if exist(candidate_path, 'file') ~= 2 || exist(stage_path, 'file') ~= 2
    error('Missing full-event trace candidate or stage detail file.');
end

candidate_tbl = readtable(candidate_path, 'TextType', 'string');
stage_tbl = readtable(stage_path, 'TextType', 'string');
n = height(candidate_tbl);

expected = false(n, 1);
terminal_stage_flag = false(n, 1);
should_multiply = true(n, 1);
stage_probability_status = strings(n, 1);
raw_consistency = strings(n, 1);
terminal_consistency = strings(n, 1);
raw_issue = strings(n, 1);
terminal_issue = strings(n, 1);
excluded = false(n, 1);
exclusion_reason = strings(n, 1);
note = strings(n, 1);

for i = 1:n
    p = candidate_tbl.candidate_probability(i);
    selected = logical(candidate_tbl.selected(i));
    u_missing = ~ismember('random_u', candidate_tbl.Properties.VariableNames) || isnan(candidate_tbl.random_u(i));
    if ~u_missing
        expected(i) = candidate_tbl.random_u(i) < p;
    end

    [terminal_stage_flag(i), should_multiply(i), stage_probability_status(i)] = ...
        lookup_stage_flags(stage_tbl, candidate_tbl.initial_branch(i), candidate_tbl.trial_id(i), candidate_tbl.stage_id(i));
    [raw_consistency(i), raw_issue(i)] = classify_raw(p, selected, expected(i), u_missing);

    if terminal_stage_flag(i) && ~should_multiply(i)
        excluded(i) = true;
        exclusion_reason(i) = "terminal_recording_stage_not_real_sampling_check";
        terminal_consistency(i) = "true";
        terminal_issue(i) = "terminal_recording_candidate_excluded";
        note(i) = "Terminal recording candidate residual excluded from sampling consistency check.";
    else
        terminal_consistency(i) = raw_consistency(i);
        terminal_issue(i) = make_terminal_issue(raw_issue(i));
        exclusion_reason(i) = "";
        note(i) = "Nonterminal or real no-new-outage sampling stage checked by random_u < probability.";
    end
end

audit = table(candidate_tbl.initial_branch, candidate_tbl.trial_id, candidate_tbl.stage_id, ...
    candidate_tbl.candidate_branch, candidate_tbl.candidate_probability, candidate_tbl.random_u, ...
    logical(candidate_tbl.selected), expected, terminal_stage_flag, should_multiply, ...
    stage_probability_status, raw_consistency, terminal_consistency, raw_issue, terminal_issue, ...
    excluded, exclusion_reason, note, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'candidate_branch', ...
    'candidate_probability', 'random_u', 'selected', 'expected_selected_by_rule', ...
    'terminal_stage_flag', 'should_multiply_candidate_complements', 'stage_probability_status', ...
    'selection_consistency_raw', 'selection_consistency_terminal_aware', ...
    'issue_type_raw', 'issue_type_terminal_aware', ...
    'excluded_from_sampling_consistency_check', 'exclusion_reason', 'note'});
writetable(audit, out_path);

checked = ~excluded;
inconsistent_nonterminal = checked & terminal_consistency == "false";
missing_nonterminal = checked & terminal_issue == "random_u_missing";
summary = table(n, sum(excluded), sum(checked), ...
    sum(checked & terminal_consistency == "true"), sum(inconsistent_nonterminal), ...
    sum(terminal_issue == "probability_one_not_selected_nonterminal"), ...
    sum(terminal_issue == "random_rule_violation_not_selected_nonterminal"), ...
    sum(terminal_issue == "random_rule_violation_selected_nonterminal"), ...
    sum(missing_nonterminal), sum(excluded), ...
    resolve_recommendation(sum(inconsistent_nonterminal), sum(missing_nonterminal), sum(excluded), any(raw_consistency == "false")), ...
    'VariableNames', {'total_candidate_count', 'excluded_terminal_candidate_count', ...
    'checked_nonterminal_candidate_count', 'consistent_nonterminal_count', ...
    'inconsistent_nonterminal_count', 'probability_one_not_selected_nonterminal_count', ...
    'random_rule_violation_not_selected_nonterminal_count', ...
    'random_rule_violation_selected_nonterminal_count', ...
    'random_u_missing_nonterminal_count', 'terminal_exclusion_count', 'recommendation'});
writetable(summary, summary_path);
fprintf('terminal-aware candidate selection audit written: %s\n', root_dir);
end

function [terminal_flag, should_multiply, status] = lookup_stage_flags(stage_tbl, ib, trial_id, stage_id)
row = stage_tbl(stage_tbl.initial_branch == ib & stage_tbl.trial_id == trial_id & stage_tbl.stage_id == stage_id, :);
if isempty(row)
    terminal_flag = false;
    should_multiply = true;
    status = "missing_stage_detail";
    return;
end
terminal_flag = logical(row.terminal_stage_flag(1));
should_multiply = logical(row.should_multiply_candidate_complements(1));
status = string(row.probability_status(1));
end

function [consistency, issue] = classify_raw(p, selected, expected, u_missing)
if u_missing
    consistency = "unknown";
    issue = "random_u_missing";
elseif p >= 1 && ~selected
    consistency = "false";
    issue = "probability_one_not_selected";
elseif expected && ~selected
    consistency = "false";
    issue = "random_rule_violation_not_selected";
elseif ~expected && selected
    consistency = "false";
    issue = "random_rule_violation_selected";
else
    consistency = "true";
    issue = "none";
end
end

function issue = make_terminal_issue(raw_issue)
switch string(raw_issue)
    case "probability_one_not_selected"
        issue = "probability_one_not_selected_nonterminal";
    case "random_rule_violation_not_selected"
        issue = "random_rule_violation_not_selected_nonterminal";
    case "random_rule_violation_selected"
        issue = "random_rule_violation_selected_nonterminal";
    otherwise
        issue = string(raw_issue);
end
end

function recommendation = resolve_recommendation(inconsistent_count, missing_count, excluded_count, had_raw_inconsistency)
if inconsistent_count == 0 && missing_count == 0 && had_raw_inconsistency && excluded_count > 0
    recommendation = "terminal_residual_candidates_excluded_ok";
elseif inconsistent_count == 0 && missing_count == 0
    recommendation = "full_event_trace_selection_consistency_passed";
else
    recommendation = "fix_nonterminal_selection_trace_before_formal_rerun";
end
end
