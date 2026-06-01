function main_select_formal_var_pilot_readiness()
%MAIN_SELECT_FORMAL_VAR_PILOT_READINESS Select go/no-go for formal VaR pilot.

out_dir = fullfile('results', 'calibration', 'diagnostics');
alignment_file = fullfile(out_dir, 'pilot_scenario_snapshot_target_alignment.csv');
if ~exist(alignment_file, 'file')
    error('Missing alignment file: %s', alignment_file);
end
A = readtable(alignment_file, 'TextType', 'string', 'Delimiter', ',');

blocking_count = sum(strcmp(A.severity, 'blocking') & ~strcmp(A.match_status, 'matched') & ~strcmp(A.match_status, 'assumption_matched'));
warning_count = sum(strcmp(A.severity, 'warning') & ~strcmp(A.match_status, 'matched') & ~strcmp(A.match_status, 'assumption_matched'));
scenario_count = numel(unique(A.scenario_id));

target_mapping_status = summarize_target_mapping(fullfile(out_dir, 'calibration_target_mapping_audit.csv'));
metric_source_status = summarize_metric_source(fullfile(out_dir, 'selected_calibration_metric_source.csv'));
if blocking_count == 0
    ready = true;
    recommended = 'formal_scenario_aligned_var_pilot_can_be_considered_after_review';
    reason = 'No blocking scenario snapshot mismatch was detected; still do not run local search before a fixed-source formal pilot.';
else
    ready = false;
    recommended = 'do_not_run_formal_var_pilot_until_scenario_builder_or_mapping_is_fixed';
    reason = 'Blocking snapshot mismatch exists; current pilot aliases do not fully match the intended paper scenario configuration.';
end

T = table(ready, scenario_count, blocking_count, warning_count, ...
    string(target_mapping_status), string(metric_source_status), string(recommended), string(reason), ...
    'VariableNames', {'formal_var_pilot_ready', 'scenario_count', ...
    'blocking_mismatch_count', 'warning_mismatch_count', 'target_mapping_status', ...
    'metric_source_status', 'recommended_next_step', 'note'});
writetable(T, fullfile(out_dir, 'formal_scenario_aligned_var_pilot_readiness.csv'));
fprintf('Wrote %s\n', fullfile(out_dir, 'formal_scenario_aligned_var_pilot_readiness.csv'));
end

function status = summarize_target_mapping(path_name)
if ~exist(path_name, 'file')
    status = 'missing_target_mapping_audit';
    return;
end
T = readtable(path_name, 'TextType', 'string', 'Delimiter', ',');
if ismember('mapping_status', T.Properties.VariableNames) && all(strcmp(T.mapping_status, 'exact_match'))
    status = 'all_targets_exact_match';
elseif ismember('match_status', T.Properties.VariableNames) && all(strcmp(T.match_status, 'exact_match'))
    status = 'all_targets_exact_match';
else
    status = 'target_mapping_requires_review';
end
end

function status = summarize_metric_source(path_name)
if ~exist(path_name, 'file')
    status = 'missing_metric_source_selection';
    return;
end
T = readtable(path_name, 'TextType', 'string', 'Delimiter', ',');
if ismember('go_no_go', T.Properties.VariableNames)
    status = char(T.go_no_go(1));
elseif ismember('recommended_use', T.Properties.VariableNames)
    status = char(T.recommended_use(1));
else
    status = 'metric_source_file_present';
end
end
