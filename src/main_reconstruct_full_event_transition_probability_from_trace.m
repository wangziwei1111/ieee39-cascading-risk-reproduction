function main_reconstruct_full_event_transition_probability_from_trace()
%MAIN_RECONSTRUCT_FULL_EVENT_TRANSITION_PROBABILITY_FROM_TRACE Offline full-event stage reconstruction.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
trace_dir = fullfile(root_dir, 'trace_smoke');
candidate_path = fullfile(trace_dir, 'candidate_probability_trace.csv');
stage_path = fullfile(trace_dir, 'stage_transition_probability_details.csv');
out_path = fullfile(root_dir, 'full_event_reconstruction_from_trace_stage.csv');
if exist(candidate_path, 'file') ~= 2 || exist(stage_path, 'file') ~= 2
    error('Missing trace smoke inputs for full-event reconstruction.');
end

candidate_trace = readtable(candidate_path, 'TextType', 'string');
stage_selected = readtable(stage_path, 'TextType', 'string');
rows = {};
for i = 1:height(stage_selected)
    ib = stage_selected.initial_branch(i);
    tr = stage_selected.trial_id(i);
    st = stage_selected.stage_id(i);
    mask = candidate_trace.initial_branch == ib & candidate_trace.trial_id == tr & candidate_trace.stage_id == st;
    cand = candidate_trace(mask, :);
    [full_prob, d] = reconstruct_stage(cand, stage_selected.stage_transition_probability(i));
    rows{end + 1, 1} = table( ... %#ok<AGROW>
        ib, tr, st, d.candidate_count, d.selected_candidate_count, d.unselected_candidate_count, ...
        d.selected_probability_product, d.unselected_probability_product, ...
        stage_selected.stage_transition_probability(i), full_prob, d.ratio_full_to_selected_only, ...
        d.random_u_available_count, d.selected_flag_available_count, string(d.reconstruction_status), string(d.note), ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'candidate_count', ...
        'selected_candidate_count', 'unselected_candidate_count', 'selected_probability_product', ...
        'unselected_probability_product', 'stage_transition_probability_selected_only', ...
        'stage_transition_probability_full_event', 'ratio_full_to_selected_only', ...
        'random_u_available_count', 'selected_flag_available_count', 'reconstruction_status', 'note'});
end
tbl = vertcat(rows{:});
writetable(tbl, out_path);
fprintf('full-event stage reconstruction written: %s\n', out_path);
end

function [full_prob, d] = reconstruct_stage(cand, selected_only_prob)
d = struct();
d.candidate_count = height(cand);
d.selected_candidate_count = 0;
d.unselected_candidate_count = 0;
d.selected_probability_product = selected_only_prob;
d.unselected_probability_product = 1;
d.ratio_full_to_selected_only = NaN;
d.random_u_available_count = 0;
d.selected_flag_available_count = 0;
d.reconstruction_status = "full_event_reconstructed";
d.note = "";

if height(cand) == 0
    full_prob = selected_only_prob;
    d.note = "terminal or no-candidate stage; full event contribution equals selected-only contribution.";
    d.ratio_full_to_selected_only = safe_ratio(full_prob, selected_only_prob);
    return;
end
if ~ismember('candidate_probability', cand.Properties.VariableNames)
    full_prob = NaN;
    d.reconstruction_status = "missing_candidate_probability";
    d.note = "candidate_probability column missing; full-event probability not fabricated.";
    return;
end
if ~ismember('selected', cand.Properties.VariableNames)
    full_prob = NaN;
    d.reconstruction_status = "missing_selected_flag";
    d.note = "selected flag missing; full-event probability not fabricated.";
    return;
end

p = cand.candidate_probability;
selected = logical(cand.selected);
d.random_u_available_count = count_available(cand, 'random_u');
d.selected_flag_available_count = sum(~ismissing(cand.selected));
if any(isnan(p))
    full_prob = NaN;
    d.reconstruction_status = "missing_candidate_probability";
    d.note = "candidate_probability contains NaN; full-event probability not fabricated.";
    return;
end

p = min(max(p, 0), 1);
d.candidate_count = numel(p);
d.selected_candidate_count = sum(selected);
d.unselected_candidate_count = sum(~selected);
d.selected_probability_product = prod(p(selected));
if isempty(d.selected_probability_product), d.selected_probability_product = 1; end
d.unselected_probability_product = prod(1 - p(~selected));
if isempty(d.unselected_probability_product), d.unselected_probability_product = 1; end
full_prob = d.selected_probability_product * d.unselected_probability_product;
d.ratio_full_to_selected_only = safe_ratio(full_prob, selected_only_prob);
if any(~selected & p >= 1)
    d.note = "high_impact_event: an unselected candidate has probability 1, so full-event probability is 0.";
else
    d.note = "full Bernoulli stage event reconstructed from candidate_probability and selected flag.";
end
end

function n = count_available(tbl, col)
if ismember(col, tbl.Properties.VariableNames)
    n = sum(~ismissing(tbl.(col)));
else
    n = 0;
end
end

function r = safe_ratio(a, b)
if isnan(a) || isnan(b) || b == 0
    r = NaN;
else
    r = a / b;
end
end
