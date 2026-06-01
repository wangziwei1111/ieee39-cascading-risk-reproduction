function [stage_prob, detail] = compute_stage_transition_probability_from_candidates(candidate_table, selected_outage_ids, cfg)
%COMPUTE_STAGE_TRANSITION_PROBABILITY_FROM_CANDIDATES 记录单级后续停运转移概率。
% 该函数只读取候选线路概率和已抽样结果，不生成随机数，也不改变 Markov 抽样逻辑。

if nargin < 2 || isempty(selected_outage_ids)
    selected_outage_ids = [];
end
if nargin < 3 || ~isfield(cfg, 'chain_transition_probability_mode')
    mode = 'selected_only_product';
else
    mode = char(cfg.chain_transition_probability_mode);
end

detail = default_detail(mode);

if isempty(candidate_table) || height(candidate_table) == 0
    stage_prob = 1;
    detail.stage_transition_probability = stage_prob;
    detail.probability_status = 'terminal_no_candidate';
    detail.missing_reason = '';
    detail.note = 'No candidate line exists at this terminal or nonconverged stage; transition contribution is recorded as 1.';
    return;
end

if ~ismember('outage_probability', candidate_table.Properties.VariableNames)
    stage_prob = NaN;
    detail.candidate_count = height(candidate_table);
    detail.stage_transition_probability = stage_prob;
    detail.probability_status = 'missing_candidate_probability';
    detail.missing_reason = 'candidate_table.outage_probability missing';
    detail.note = 'Cannot compute stage transition probability without candidate outage probabilities.';
    return;
end

p = candidate_table.outage_probability(:);
p = min(max(p, 0), 1);
detail.candidate_count = numel(p);

if ismember('trip_selected', candidate_table.Properties.VariableNames)
    selected_mask = logical(candidate_table.trip_selected(:));
else
    selected_mask = false(numel(p), 1);
end
if ~isempty(selected_outage_ids) && ismember('branch_index', candidate_table.Properties.VariableNames)
    selected_mask = ismember(candidate_table.branch_index(:), selected_outage_ids(:));
end

detail.selected_candidate_count = sum(selected_mask);
detail.unselected_candidate_count = sum(~selected_mask);
detail.selected_branch_ids = join_ids(candidate_table, selected_mask);
detail.random_u_selected = join_random_u(candidate_table, selected_mask);
detail.candidate_probability_basis = resolve_probability_basis(candidate_table);

selected_product = prod(p(selected_mask));
if isempty(selected_product)
    selected_product = 1;
end
detail.selected_probability_product = selected_product;

switch mode
    case 'bernoulli_full_event'
        unselected_product = prod(1 - p(~selected_mask));
        if isempty(unselected_product)
            unselected_product = 1;
        end
        stage_prob = selected_product * unselected_product;
        detail.unselected_probability_product = unselected_product;
        detail.probability_status = 'full_bernoulli_event';
        detail.note = 'Full Bernoulli event probability uses selected probabilities and non-selected complement probabilities.';
    otherwise
        stage_prob = selected_product;
        detail.unselected_probability_product = NaN;
        detail.probability_status = 'selected_only_approximation';
        if detail.selected_candidate_count == 0
            detail.note = 'No additional outage was selected; selected-only transition contribution is recorded as 1.';
        else
            detail.note = 'Selected-only approximation uses only sampled outage probabilities and does not multiply non-selected complements.';
        end
end

detail.stage_transition_probability = stage_prob;
end

function detail = default_detail(mode)
detail = struct();
detail.stage_probability_mode = string(mode);
detail.candidate_count = 0;
detail.selected_candidate_count = 0;
detail.unselected_candidate_count = 0;
detail.selected_probability_product = NaN;
detail.unselected_probability_product = NaN;
detail.stage_transition_probability = NaN;
detail.probability_status = 'not_computed';
detail.missing_reason = '';
detail.selected_branch_ids = "";
detail.random_u_selected = "";
detail.candidate_probability_basis = "";
detail.note = "";
end

function ids = join_ids(candidate_table, selected_mask)
ids = "";
if ismember('branch_index', candidate_table.Properties.VariableNames) && any(selected_mask)
    ids = strjoin(string(candidate_table.branch_index(selected_mask)), ',');
end
end

function s = join_random_u(candidate_table, selected_mask)
s = "";
if ismember('random_u', candidate_table.Properties.VariableNames) && any(selected_mask)
    s = strjoin(string(candidate_table.random_u(selected_mask)), ',');
end
end

function basis = resolve_probability_basis(candidate_table)
basis = "outage_probability";
if ismember('prob_model', candidate_table.Properties.VariableNames) && height(candidate_table) > 0
    models = unique(string(candidate_table.prob_model));
    basis = strjoin(models(:)', ',');
end
end
