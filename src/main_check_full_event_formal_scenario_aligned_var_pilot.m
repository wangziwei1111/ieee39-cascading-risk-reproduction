function main_check_full_event_formal_scenario_aligned_var_pilot()
%MAIN_CHECK_FULL_EVENT_FORMAL_SCENARIO_ALIGNED_VAR_PILOT Validate full-event formal pilot artifacts.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot');
log_path = fullfile(out_root, 'full_event_formal_var_pilot_check_log.txt');
ok = true;
messages = strings(0, 1);
ready_path = fullfile(project_root, 'results', 'calibration', 'transition_probability', 'full_event_formal_var_pilot_readiness.csv');
[ok, messages] = require_file(ok, messages, ready_path);
if exist(ready_path, 'file') == 2
    ready = readtable(ready_path, 'TextType', 'string');
    if ~logical(ready.ready_for_full_event_formal_var_pilot(1))
        ok = false; messages(end+1) = "readiness is not 1"; %#ok<AGROW>
    end
end
parameter_sets = ["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids = ["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00", ...
    "penetration_40pct","penetration_60pct","penetration_80pct"];
for p = 1:numel(parameter_sets)
    for s = 1:numel(scenario_ids)
        d = fullfile(out_root, char(parameter_sets(p)), char(scenario_ids(s)));
        [ok, messages] = require_file(ok, messages, fullfile(d, 'scenario_config_snapshot.csv'));
        summary_path = fullfile(d, 'tables', 'markov_chain_summary.csv');
        [ok, messages] = require_file(ok, messages, summary_path);
        [ok, messages] = require_file(ok, messages, fullfile(d, 'tables', 'stage_transition_probability_details.csv'));
        [ok, messages] = require_file(ok, messages, fullfile(d, 'tables', 'candidate_probability_trace.csv'));
        if exist(summary_path, 'file') == 2
            T = readtable(summary_path, 'TextType', 'string');
            if any(string(T.stage_probability_mode) ~= "bernoulli_full_event")
                ok = false; messages(end+1) = "non-full-event stage mode in " + string(summary_path); %#ok<AGROW>
            end
            if any(string(T.chain_probability_status) == "selected_only_approximation")
                ok = false; messages(end+1) = "selected-only status in " + string(summary_path); %#ok<AGROW>
            end
        end
    end
end
for f = ["full_event_formal_var_metrics.csv","full_event_formal_var_to_paper_gap.csv", ...
        "full_event_formal_var_score_summary.csv","post_full_event_formal_var_action.csv"]
    [ok, messages] = require_file(ok, messages, fullfile(out_root, char(f)));
end
if exist(fullfile(project_root, 'results', 'final_summary'), 'dir') == 7
    messages(end+1) = "final_summary directory exists from prior work; this check did not write it."; %#ok<AGROW>
end
if exist(fullfile(out_root, 'local_search_results.csv'), 'file') == 2
    ok = false; messages(end+1) = "local_search_results unexpectedly exists in full-event pilot root."; %#ok<AGROW>
else
    messages(end+1) = "local_search_results not generated."; %#ok<AGROW>
end
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'full_event_formal_scenario_aligned_var_pilot_check\n');
fprintf(fid, 'check_status=%s\n', ternary(ok, 'pass', 'fail'));
for i = 1:numel(messages), fprintf(fid, '%s\n', messages(i)); end
if ~ok
    error('full-event formal pilot check failed; see %s', log_path);
end
fprintf('full-event formal pilot check passed: %s\n', log_path);
end

function [ok, messages] = require_file(ok, messages, path)
if exist(path, 'file') ~= 2
    ok = false; messages(end+1) = "missing file: " + string(path);
else
    messages(end+1) = "found file: " + string(path);
end
end

function value = ternary(cond, a, b)
if cond, value = a; else, value = b; end
end
