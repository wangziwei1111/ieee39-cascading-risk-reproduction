function main_check_full_event_probability_zero_fix()
%MAIN_CHECK_FULL_EVENT_PROBABILITY_ZERO_FIX Validate terminal/full-event zero probability handling.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
smoke_dir = fullfile(root_dir, 'full_event_trace_smoke');
log_path = fullfile(root_dir, 'full_event_probability_zero_fix_check_log.txt');
ok = true;
messages = strings(0, 1);

required = {
    fullfile(root_dir, 'full_event_zero_probability_diagnosis.csv')
    fullfile(root_dir, 'candidate_selection_consistency_audit.csv')
    fullfile(root_dir, 'candidate_selection_consistency_summary.csv')
    fullfile(project_root, 'src', 'cascade', 'is_terminal_stage_for_transition_probability.m')
    fullfile(smoke_dir, 'stage_transition_probability_details.csv')
    fullfile(smoke_dir, 'markov_chain_summary.csv')
    fullfile(root_dir, 'full_event_reconstruction_from_trace_stage.csv')
    fullfile(root_dir, 'full_event_reconstruction_from_trace_chain.csv')
    fullfile(root_dir, 'full_event_chain_risk_trace_preview.csv')
    };
for i = 1:numel(required)
    [ok, messages] = require_file(ok, messages, required{i});
end

stage_path = fullfile(smoke_dir, 'stage_transition_probability_details.csv');
if exist(stage_path, 'file') == 2
    stage_tbl = readtable(stage_path, 'TextType', 'string');
    required_cols = {'terminal_stage_flag', 'should_multiply_candidate_complements', 'candidate_selection_consistency_status'};
    for k = 1:numel(required_cols)
        if ~ismember(required_cols{k}, stage_tbl.Properties.VariableNames)
            ok = false;
            messages(end + 1) = "missing full-event stage column: " + required_cols{k}; %#ok<AGROW>
        end
    end
    zero_rows = stage_tbl(stage_tbl.stage_transition_probability == 0, :);
    if ~isempty(zero_rows)
        diag_path = fullfile(root_dir, 'full_event_zero_probability_diagnosis.csv');
        if exist(diag_path, 'file') == 2
            diag_tbl = readtable(diag_path, 'TextType', 'string');
            for z = 1:height(zero_rows)
                match = diag_tbl.initial_branch == zero_rows.initial_branch(z) & ...
                    diag_tbl.trial_id == zero_rows.trial_id(z) & ...
                    diag_tbl.stage_id == zero_rows.stage_id(z);
                if ~any(match)
                    ok = false;
                    messages(end + 1) = "zero stage lacks diagnosis: " + ...
                        string(zero_rows.initial_branch(z)) + "/" + string(zero_rows.trial_id(z)) + "/" + string(zero_rows.stage_id(z)); %#ok<AGROW>
                end
            end
        end
        messages(end + 1) = "stage_transition_probability=0 remains only if explained in diagnosis."; %#ok<AGROW>
    end
end

summary_path = fullfile(smoke_dir, 'markov_chain_summary.csv');
if exist(summary_path, 'file') == 2
    summary = readtable(summary_path, 'TextType', 'string');
    if any(summary.chain_probability_status == "selected_only_approximation")
        ok = false;
        messages(end + 1) = "full-event chain summary still contains selected_only_approximation."; %#ok<AGROW>
    end
end

if exist(fullfile(project_root, 'results', 'final_summary'), 'dir') == 7
    messages(end + 1) = "final_summary directory exists from prior work; this check did not write it."; %#ok<AGROW>
end
messages(end + 1) = "local_search was not run by this check."; %#ok<AGROW>

fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'full_event_probability_zero_fix_check\n');
fprintf(fid, 'check_status=%s\n', ternary(ok, 'pass', 'fail'));
for k = 1:numel(messages)
    fprintf(fid, '%s\n', messages(k));
end
if ~ok
    error('full-event probability zero fix check failed; see %s', log_path);
end
fprintf('full-event probability zero fix check passed: %s\n', log_path);
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
