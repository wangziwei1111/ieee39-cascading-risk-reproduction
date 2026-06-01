function [chain_prob, detail] = aggregate_chain_transition_probability(stage_records, cfg)
%AGGREGATE_CHAIN_TRANSITION_PROBABILITY 汇总事故链各级转移概率。
% 该函数只做乘积汇总，不补造缺失概率。

if nargin < 2 || ~isfield(cfg, 'chain_transition_probability_mode')
    mode = 'selected_only_product';
else
    mode = char(cfg.chain_transition_probability_mode);
end

detail = struct();
detail.stage_probability_mode = string(mode);
detail.stage_count = numel(stage_records);
detail.valid_stage_probability_count = 0;
detail.missing_stage_probability_count = 0;
detail.chain_transition_probability = NaN;
detail.probability_status = 'not_computed';
detail.note = "";

if isempty(stage_records)
    chain_prob = NaN;
    detail.probability_status = 'missing_stage_records';
    detail.note = 'No stage records are available.';
    return;
end

stage_probs = NaN(numel(stage_records), 1);
stage_status = strings(numel(stage_records), 1);
for k = 1:numel(stage_records)
    if isfield(stage_records(k), 'transition_probability_detail') && ...
            isfield(stage_records(k).transition_probability_detail, 'stage_transition_probability')
        stage_probs(k) = stage_records(k).transition_probability_detail.stage_transition_probability;
        stage_status(k) = string(stage_records(k).transition_probability_detail.probability_status);
    else
        stage_status(k) = "missing_stage_probability_detail";
    end
end

valid_mask = ~isnan(stage_probs);
detail.valid_stage_probability_count = sum(valid_mask);
detail.missing_stage_probability_count = sum(~valid_mask);

if any(~valid_mask)
    chain_prob = NaN;
    detail.probability_status = 'partially_missing';
    detail.note = 'At least one stage transition probability is missing; chain probability is not fabricated.';
else
    chain_prob = prod(stage_probs);
    detail.chain_transition_probability = chain_prob;
    if any(stage_status == "selected_only_approximation")
        detail.probability_status = 'selected_only_approximation';
        detail.note = 'Chain probability is a selected-only approximation and excludes non-selected candidate complements.';
    elseif all(stage_status == "full_bernoulli_event" | stage_status == "terminal_no_candidate")
        detail.probability_status = 'full_bernoulli_event';
        detail.note = 'Chain probability uses full Bernoulli stage events where available.';
    else
        detail.probability_status = 'computed_with_terminal_or_mixed_status';
        detail.note = 'Chain probability contains terminal stages and available stage probabilities.';
    end
end
detail.chain_transition_probability = chain_prob;
detail.stage_probability_status_list = strjoin(stage_status(:)', ',');
end
