function main_diagnose_full_event_zero_probability_causes()
%MAIN_DIAGNOSE_FULL_EVENT_ZERO_PROBABILITY_CAUSES Explain zero full-event probabilities.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'calibration', 'transition_probability');
stage_path = fullfile(root_dir, 'full_event_trace_smoke', 'stage_transition_probability_details.csv');
candidate_path = fullfile(root_dir, 'full_event_trace_smoke', 'candidate_probability_trace.csv');
chain_path = fullfile(root_dir, 'full_event_trace_smoke', 'markov_chain_summary.csv');
out_path = fullfile(root_dir, 'full_event_zero_probability_diagnosis.csv');
if exist(stage_path, 'file') ~= 2 || exist(candidate_path, 'file') ~= 2 || exist(chain_path, 'file') ~= 2
    error('Missing full-event smoke inputs for zero-probability diagnosis.');
end

stage_tbl = readtable(stage_path, 'TextType', 'string');
candidate_tbl = readtable(candidate_path, 'TextType', 'string');
chain_tbl = readtable(chain_path, 'TextType', 'string');

rows = {};
for i = 1:height(stage_tbl)
    ib = stage_tbl.initial_branch(i);
    tr = stage_tbl.trial_id(i);
    st = stage_tbl.stage_id(i);
    chain_row = chain_tbl(chain_tbl.initial_branch == ib & chain_tbl.trial_id == tr, :);
    cand = candidate_tbl(candidate_tbl.initial_branch == ib & candidate_tbl.trial_id == tr & candidate_tbl.stage_id == st, :);

    chain_depth = get_chain_value(chain_row, 'chain_depth', NaN);
    terminated_reason = string(get_chain_value(chain_row, 'terminated_reason', ""));
    candidate_count = get_stage_value(stage_tbl, i, 'candidate_count', height(cand));
    selected_count = get_stage_value(stage_tbl, i, 'selected_candidate_count', sum_safe(cand, 'selected', true));
    unselected_count = get_stage_value(stage_tbl, i, 'unselected_candidate_count', candidate_count - selected_count);
    stage_prob = get_stage_value(stage_tbl, i, 'stage_transition_probability', NaN);
    unselected_product = get_stage_value(stage_tbl, i, 'unselected_probability_product', NaN);
    terminal_flag = st == chain_depth;
    no_new_flag = terminal_flag && terminated_reason == "no_new_outage";
    load_loss_flag = terminal_flag && terminated_reason == "load_loss_threshold";
    max_depth_flag = terminal_flag && terminated_reason == "max_depth_reached";
    generated_after_terminal = terminal_flag && (load_loss_flag || max_depth_flag) && candidate_count > 0;

    unselected_probability_one_count = 0;
    selected_probability_zero_count = 0;
    if height(cand) > 0
        unselected_probability_one_count = sum(~logical(cand.selected) & cand.candidate_probability >= 1);
        selected_probability_zero_count = sum(logical(cand.selected) & cand.candidate_probability <= 0);
    end
    [diagnosis, fix, note] = classify_zero(stage_prob, terminal_flag, no_new_flag, load_loss_flag, max_depth_flag, ...
        generated_after_terminal, unselected_probability_one_count, selected_probability_zero_count, unselected_product);

    rows{end + 1, 1} = table( ... %#ok<AGROW>
        ib, tr, st, chain_depth, terminated_reason, candidate_count, selected_count, unselected_count, ...
        stage_prob, unselected_product, unselected_probability_one_count > 0, unselected_probability_one_count, ...
        selected_probability_zero_count > 0, selected_probability_zero_count, terminal_flag, no_new_flag, ...
        load_loss_flag, max_depth_flag, generated_after_terminal, diagnosis, fix, note, ...
        'VariableNames', {'initial_branch', 'trial_id', 'stage_id', 'chain_depth', 'terminated_reason', ...
        'candidate_count', 'selected_candidate_count', 'unselected_candidate_count', ...
        'stage_transition_probability', 'unselected_probability_product', ...
        'has_unselected_probability_one', 'unselected_probability_one_count', ...
        'has_selected_probability_zero', 'selected_probability_zero_count', ...
        'terminal_stage_flag', 'no_new_outage_stage_flag', 'load_loss_threshold_stage_flag', ...
        'max_depth_stage_flag', 'candidate_table_generated_after_terminal', ...
        'diagnosis', 'recommended_fix', 'note'});
end
out = vertcat(rows{:});
writetable(out, out_path);
fprintf('full-event zero probability diagnosis written: %s\n', out_path);
end

function [diagnosis, fix, note] = classify_zero(stage_prob, terminal_flag, no_new_flag, load_loss_flag, max_depth_flag, generated_after_terminal, unselected_p1_count, selected_p0_count, unselected_product)
diagnosis = "normal_nonzero_or_not_applicable";
fix = "none";
note = "Stage probability is not a problematic zero.";
if isnan(stage_prob)
    diagnosis = "unknown";
    fix = "inspect missing or inconsistent probability status";
    note = "Stage probability is NaN; check status fields.";
elseif stage_prob == 0
    if terminal_flag && ~no_new_flag
        diagnosis = "terminal_stage_should_not_multiply_candidates";
        fix = "set terminal recording stage transition probability to 1";
        note = "Terminal stage should not multiply leftover candidate complements.";
    elseif generated_after_terminal
        diagnosis = "candidate_table_after_termination";
        fix = "exclude terminal diagnostic candidate table from full-event product";
        note = "Candidate table exists after terminal condition.";
    elseif unselected_p1_count > 0
        diagnosis = "inconsistent_selected_flag_for_probability_one";
        fix = "mark stage probability inconsistent instead of zero";
        note = "At least one probability-one candidate is unselected.";
    elseif selected_p0_count > 0
        diagnosis = "selected_probability_zero_in_path";
        fix = "inspect selected candidate probability";
        note = "A selected candidate has zero probability.";
    elseif no_new_flag && unselected_product == 0
        diagnosis = "no_new_outage_full_event_valid_zero";
        fix = "retain only if candidate selection is consistent";
        note = "No-new-outage can have zero event probability if a non-selected candidate has probability one.";
    else
        diagnosis = "normal_full_event_zero";
        fix = "retain with explanation";
        note = "Zero is produced by the full Bernoulli product.";
    end
elseif terminal_flag && (load_loss_flag || max_depth_flag)
    diagnosis = "terminal_stage_should_not_multiply_candidates";
    fix = "verify terminal stage probability is 1 after fix";
    note = "Terminal load-loss/max-depth stage should be excluded from complement product.";
end
end

function value = get_chain_value(tbl, name, default_value)
if isempty(tbl) || ~ismember(name, tbl.Properties.VariableNames)
    value = default_value;
else
    value = tbl.(name)(1);
end
end

function value = get_stage_value(tbl, idx, name, default_value)
if ~ismember(name, tbl.Properties.VariableNames)
    value = default_value;
else
    value = tbl.(name)(idx);
end
end

function n = sum_safe(tbl, name, logical_value)
if isempty(tbl) || ~ismember(name, tbl.Properties.VariableNames)
    n = 0;
else
    n = sum(logical(tbl.(name)) == logical_value);
end
end
