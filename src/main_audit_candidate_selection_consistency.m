function main_audit_candidate_selection_consistency()
%MAIN_AUDIT_CANDIDATE_SELECTION_CONSISTENCY Audit random_u/probability/selected consistency.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
trace_path = fullfile(root_dir, 'full_event_trace_smoke', 'candidate_probability_trace.csv');
audit_path = fullfile(root_dir, 'candidate_selection_consistency_audit.csv');
summary_path = fullfile(root_dir, 'candidate_selection_consistency_summary.csv');
if exist(trace_path, 'file') ~= 2
    error('Missing full-event candidate trace: %s', trace_path);
end

tbl = readtable(trace_path, 'TextType', 'string');
n = height(tbl);
expected = false(n, 1);
consistent = strings(n, 1);
issue = strings(n, 1);
note = strings(n, 1);

for i = 1:n
    p = tbl.candidate_probability(i);
    selected = logical(tbl.selected(i));
    if ~ismember('random_u', tbl.Properties.VariableNames) || isnan(tbl.random_u(i))
        expected(i) = false;
        consistent(i) = "unknown";
        issue(i) = "random_u_missing";
        note(i) = "random_u missing; cannot audit selection.";
        continue;
    end
    u = tbl.random_u(i);
    expected(i) = u < p;
    if p >= 1 && ~selected
        consistent(i) = "false";
        issue(i) = "probability_one_not_selected";
        note(i) = "candidate_probability is 1 but selected is false.";
    elseif expected(i) && ~selected
        consistent(i) = "false";
        issue(i) = "random_rule_violation_not_selected";
        note(i) = "random_u < candidate_probability but selected is false.";
    elseif ~expected(i) && selected
        consistent(i) = "false";
        issue(i) = "random_rule_violation_selected";
        note(i) = "random_u >= candidate_probability but selected is true.";
    else
        consistent(i) = "true";
        issue(i) = "none";
        note(i) = "selection matches random_u < probability rule.";
    end
end

audit = table(tbl.initial_branch, tbl.trial_id, tbl.stage_id, tbl.candidate_branch, ...
    tbl.candidate_probability, tbl.random_u, logical(tbl.selected), expected, consistent, issue, note, ...
    'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'candidate_branch', ...
    'candidate_probability', 'random_u', 'selected', 'expected_selected_by_rule', ...
    'selection_consistency', 'issue_type', 'note'});
writetable(audit, audit_path);

summary = table(n, sum(consistent == "true"), sum(consistent == "false"), ...
    sum(issue == "probability_one_not_selected"), ...
    sum(issue == "random_rule_violation_not_selected"), ...
    sum(issue == "random_rule_violation_selected"), ...
    sum(issue == "random_u_missing"), ...
    resolve_recommendation(issue), ...
    'VariableNames', {'total_candidate_count', 'consistent_count', 'inconsistent_count', ...
    'probability_one_not_selected_count', 'random_rule_violation_not_selected_count', ...
    'random_rule_violation_selected_count', 'random_u_missing_count', 'recommendation'});
writetable(summary, summary_path);
fprintf('candidate selection consistency audit written: %s\n', root_dir);
end

function rec = resolve_recommendation(issue)
if any(issue ~= "none")
    rec = "investigate_selection_trace_before_formal_rerun";
else
    rec = "candidate_selection_trace_consistent";
end
end
