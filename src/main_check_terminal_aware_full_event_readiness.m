function main_check_terminal_aware_full_event_readiness()
%MAIN_CHECK_TERMINAL_AWARE_FULL_EVENT_READINESS Check terminal-aware full-event readiness artifacts.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
log_path = fullfile(root_dir, 'terminal_aware_full_event_readiness_check_log.txt');
ok = true;
messages = strings(0, 1);
required = {
    fullfile(root_dir, 'candidate_selection_consistency_terminal_aware_audit.csv')
    fullfile(root_dir, 'candidate_selection_consistency_terminal_aware_summary.csv')
    fullfile(root_dir, 'full_event_zero_selection_reconciliation.csv')
    fullfile(root_dir, 'full_event_formal_var_pilot_readiness.csv')
    };
for i = 1:numel(required)
    [ok, messages] = require_file(ok, messages, required{i});
end

if ok
    raw = readtable(fullfile(root_dir, 'candidate_selection_consistency_summary.csv'), 'TextType', 'string');
    ta = readtable(fullfile(root_dir, 'candidate_selection_consistency_terminal_aware_summary.csv'), 'TextType', 'string');
    readiness = readtable(fullfile(root_dir, 'full_event_formal_var_pilot_readiness.csv'), 'TextType', 'string');
    if raw.inconsistent_count(1) > 0 && ta.inconsistent_nonterminal_count(1) == 0
        messages(end + 1) = "raw inconsistencies were terminal residual candidates and are not blocking."; %#ok<AGROW>
    end
    if readiness.ready_for_full_event_formal_var_pilot(1)
        messages(end + 1) = "ready=1; next step is full-event formal scenario-aligned VaR pilot, not local search."; %#ok<AGROW>
    else
        messages(end + 1) = "ready=0; blocking reason: " + readiness.recommended_next_step(1); %#ok<AGROW>
    end
end
if exist(fullfile(project_root, 'results', 'final_summary'), 'dir') == 7
    messages(end + 1) = "final_summary directory exists from prior work; this check did not write it."; %#ok<AGROW>
end
messages(end + 1) = "formal pilot and local search were not run by this check."; %#ok<AGROW>

fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'terminal_aware_full_event_readiness_check\n');
fprintf(fid, 'check_status=%s\n', ternary(ok, 'pass', 'fail'));
for k = 1:numel(messages)
    fprintf(fid, '%s\n', messages(k));
end
if ~ok
    error('terminal-aware full-event readiness check failed; see %s', log_path);
end
fprintf('terminal-aware full-event readiness check passed: %s\n', log_path);
end

function [ok, messages] = require_file(ok, messages, path)
if exist(path, 'file') ~= 2
    ok = false;
    messages(end + 1) = "missing file: " + string(path);
else
    messages(end + 1) = "found file: " + string(path);
end
end

function value = ternary(cond, a, b)
if cond, value = a; else, value = b; end
end
