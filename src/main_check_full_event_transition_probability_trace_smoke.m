function main_check_full_event_transition_probability_trace_smoke()
%MAIN_CHECK_FULL_EVENT_TRANSITION_PROBABILITY_TRACE_SMOKE Validate full-event reconstruction and smoke.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
smoke_dir = fullfile(root_dir, 'full_event_trace_smoke');
log_path = fullfile(root_dir, 'full_event_transition_probability_trace_smoke_check_log.txt');

ok = true;
messages = strings(0, 1);
required_files = {
    fullfile(root_dir, 'full_event_reconstruction_from_trace_stage.csv')
    fullfile(root_dir, 'full_event_reconstruction_from_trace_chain.csv')
    fullfile(root_dir, 'full_event_chain_risk_trace_preview.csv')
    fullfile(smoke_dir, 'markov_chain_summary.csv')
    fullfile(smoke_dir, 'stage_transition_probability_details.csv')
    fullfile(smoke_dir, 'candidate_probability_trace.csv')
    fullfile(project_root, 'src', 'cascade', 'compute_stage_transition_probability_from_candidates.m')
    };
for k = 1:numel(required_files)
    [ok, messages] = require_file(ok, messages, required_files{k});
end

fn_text = fileread(fullfile(project_root, 'src', 'cascade', 'compute_stage_transition_probability_from_candidates.m'));
if ~contains(fn_text, 'bernoulli_full_event')
    ok = false;
    messages(end + 1) = "compute_stage_transition_probability_from_candidates does not mention bernoulli_full_event."; %#ok<AGROW>
end

stage_path = fullfile(smoke_dir, 'stage_transition_probability_details.csv');
if exist(stage_path, 'file') == 2
    stage_tbl = readtable(stage_path, 'TextType', 'string');
    if any(stage_tbl.stage_probability_mode ~= "bernoulli_full_event")
        ok = false;
        messages(end + 1) = "full-event smoke contains non-bernoulli stage_probability_mode."; %#ok<AGROW>
    end
    bad = ~(stage_tbl.probability_status == "full_event_available" | stage_tbl.probability_status == "terminal_no_candidate");
    if any(bad)
        ok = false;
        messages(end + 1) = "full-event smoke has unavailable stage probability rows."; %#ok<AGROW>
    end
end

summary_path = fullfile(smoke_dir, 'markov_chain_summary.csv');
if exist(summary_path, 'file') == 2
    summary = readtable(summary_path, 'TextType', 'string');
    if any(summary.chain_probability_status == "selected_only_approximation")
        ok = false;
        messages(end + 1) = "full-event smoke chain_probability_status still selected_only_approximation."; %#ok<AGROW>
    end
    if ~ismember('chain_transition_probability', summary.Properties.VariableNames)
        ok = false;
        messages(end + 1) = "full-event summary lacks chain_transition_probability."; %#ok<AGROW>
    end
end

if exist(fullfile(project_root, 'results', 'final_summary'), 'dir') == 7
    messages(end + 1) = "final_summary directory exists from prior work; this check did not write it."; %#ok<AGROW>
end
messages(end + 1) = "local_search was not run by this check."; %#ok<AGROW>

fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'full_event_transition_probability_trace_smoke_check\n');
fprintf(fid, 'check_status=%s\n', ternary(ok, 'pass', 'fail'));
for k = 1:numel(messages)
    fprintf(fid, '%s\n', messages(k));
end
if ~ok
    error('full-event transition probability trace smoke check failed; see %s', log_path);
end
fprintf('full-event transition probability trace smoke check passed: %s\n', log_path);
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
