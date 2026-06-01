function main_check_transition_probability_trace_smoke()
%MAIN_CHECK_TRANSITION_PROBABILITY_TRACE_SMOKE Validate transition trace smoke outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
smoke_dir = fullfile(root_dir, 'trace_smoke');
log_path = fullfile(root_dir, 'transition_probability_trace_smoke_check_log.txt');
if ~exist(root_dir, 'dir'), mkdir(root_dir); end

messages = strings(0, 1);
ok = true;

[ok, messages] = require_file(ok, messages, fullfile(project_root, 'src', 'cascade', 'compute_stage_transition_probability_from_candidates.m'));
[ok, messages] = require_file(ok, messages, fullfile(project_root, 'src', 'cascade', 'aggregate_chain_transition_probability.m'));
[ok, messages] = require_file(ok, messages, fullfile(root_dir, 'current_markov_transition_logic_audit.csv'));
[ok, messages] = require_file(ok, messages, fullfile(smoke_dir, 'markov_chain_summary.csv'));
[ok, messages] = require_file(ok, messages, fullfile(smoke_dir, 'stage_transition_probability_details.csv'));
[ok, messages] = require_file(ok, messages, fullfile(smoke_dir, 'candidate_probability_trace.csv'));

summary_path = fullfile(smoke_dir, 'markov_chain_summary.csv');
if exist(summary_path, 'file') == 2
    summary = readtable(summary_path);
    required_cols = {'chain_transition_probability', 'chain_probability_status', ...
        'stage_probability_mode', 'initial_line_probability', 'total_chain_probability_actual'};
    for k = 1:numel(required_cols)
        if ~ismember(required_cols{k}, summary.Properties.VariableNames)
            ok = false;
            messages(end + 1) = "missing summary column: " + required_cols{k}; %#ok<AGROW>
        end
    end
    if height(summary) ~= 6
        ok = false;
        messages(end + 1) = "expected 6 smoke chains, found " + string(height(summary)); %#ok<AGROW>
    end
    if ismember('chain_transition_probability', summary.Properties.VariableNames) && any(isnan(summary.chain_transition_probability))
        ok = false;
        messages(end + 1) = "chain_transition_probability contains NaN"; %#ok<AGROW>
    end
end

stage_path = fullfile(smoke_dir, 'stage_transition_probability_details.csv');
if exist(stage_path, 'file') == 2
    stage_tbl = readtable(stage_path);
    if ~ismember('stage_transition_probability', stage_tbl.Properties.VariableNames)
        ok = false;
        messages(end + 1) = "missing stage transition probability column"; %#ok<AGROW>
    elseif any(isnan(stage_tbl.stage_transition_probability))
        ok = false;
        messages(end + 1) = "stage transition probability contains NaN"; %#ok<AGROW>
    end
    if ismember('probability_status', stage_tbl.Properties.VariableNames) && ...
            any(string(stage_tbl.probability_status) == "selected_only_approximation")
        messages(end + 1) = "selected_only_product mode intentionally records a selected-only approximation."; %#ok<AGROW>
    end
end

if exist(fullfile(project_root, 'results', 'final_summary'), 'dir') == 7
    messages(end + 1) = "final_summary directory exists from prior work; this check did not write it."; %#ok<AGROW>
else
    messages(end + 1) = "final_summary directory not present in this workspace."; %#ok<AGROW>
end

fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'transition_probability_trace_smoke_check\n');
fprintf(fid, 'check_status=%s\n', ternary(ok, 'pass', 'fail'));
for k = 1:numel(messages)
    fprintf(fid, '%s\n', messages(k));
end
if ~ok
    error('transition probability trace smoke check failed; see %s', log_path);
end
fprintf('transition probability trace smoke check passed: %s\n', log_path);
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
if cond
    value = a;
else
    value = b;
end
end
