function main_reconstruct_full_event_chain_probability_from_trace()
%MAIN_RECONSTRUCT_FULL_EVENT_CHAIN_PROBABILITY_FROM_TRACE Offline full-event chain reconstruction.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
stage_path = fullfile(root_dir, 'full_event_reconstruction_from_trace_stage.csv');
summary_path = fullfile(root_dir, 'trace_smoke', 'markov_chain_summary.csv');
out_path = fullfile(root_dir, 'full_event_reconstruction_from_trace_chain.csv');
if exist(stage_path, 'file') ~= 2 || exist(summary_path, 'file') ~= 2
    error('Missing stage reconstruction or trace smoke chain summary.');
end
stage_tbl = readtable(stage_path, 'TextType', 'string');
summary = readtable(summary_path, 'TextType', 'string');

rows = {};
for i = 1:height(summary)
    ib = summary.initial_branch(i);
    tr = summary.trial_id(i);
    mask = stage_tbl.initial_branch == ib & stage_tbl.trial_id == tr;
    st = stage_tbl(mask, :);
    if isempty(st) || any(isnan(st.stage_transition_probability_full_event))
        full_chain = NaN;
        status = "missing_full_event_stage_probability";
        note = "At least one stage full-event probability is missing; selected-only is not substituted.";
    else
        full_chain = prod(st.stage_transition_probability_full_event);
        status = "full_event_reconstructed";
        note = "Full-event chain probability reconstructed as product of stage full-event probabilities.";
    end
    selected_chain = summary.chain_transition_probability(i);
    init_p = summary.initial_line_probability(i);
    display_selected = init_p * selected_chain / 1e-4;
    display_full = init_p * full_chain / 1e-4;
    rows{end + 1, 1} = table( ... %#ok<AGROW>
        ib, tr, height(st), selected_chain, full_chain, safe_ratio(full_chain, selected_chain), ...
        init_p, display_selected, display_full, status, note, ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_count', ...
        'chain_transition_probability_selected_only', 'chain_transition_probability_full_event', ...
        'ratio_full_to_selected_only', 'initial_line_probability', ...
        'total_chain_probability_display_selected_only', 'total_chain_probability_display_full_event', ...
        'chain_probability_status', 'note'});
end
chain_tbl = vertcat(rows{:});
writetable(chain_tbl, out_path);
fprintf('full-event chain reconstruction written: %s\n', out_path);
end

function r = safe_ratio(a, b)
if isnan(a) || isnan(b) || b == 0
    r = NaN;
else
    r = a / b;
end
end
