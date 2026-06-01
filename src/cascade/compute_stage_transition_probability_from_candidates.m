function [stage_prob, detail] = compute_stage_transition_probability_from_candidates(candidate_table, selected_outage_ids, cfg, terminal_stage_detail)
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
if nargin < 4 || isempty(terminal_stage_detail)
    terminal_stage_detail = struct('terminal_stage_flag', false, ...
        'should_multiply_candidate_complements', true, ...
        'terminal_reason', "", 'note', "");
end

detail = default_detail(mode);
detail.terminal_stage_flag = logical(get_struct_field(terminal_stage_detail, 'terminal_stage_flag', false));
detail.should_multiply_candidate_complements = logical(get_struct_field(terminal_stage_detail, 'should_multiply_candidate_complements', true));
detail.terminal_reason = string(get_struct_field(terminal_stage_detail, 'terminal_reason', ""));
detail.terminal_stage_note = string(get_struct_field(terminal_stage_detail, 'note', ""));

if strcmp(mode, 'bernoulli_full_event') && ~detail.should_multiply_candidate_complements
    if istable(candidate_table)
        detail.candidate_count = height(candidate_table);
        if ismember('trip_selected', candidate_table.Properties.VariableNames)
            detail.selected_candidate_count = sum(logical(candidate_table.trip_selected(:)));
            detail.unselected_candidate_count = detail.candidate_count - detail.selected_candidate_count;
        elseif ismember('selected', candidate_table.Properties.VariableNames)
            detail.selected_candidate_count = sum(logical(candidate_table.selected(:)));
            detail.unselected_candidate_count = detail.candidate_count - detail.selected_candidate_count;
        end
    end
    stage_prob = 1;
    detail.stage_transition_probability = stage_prob;
    detail.probability_status = 'terminal_stage_probability_one';
    detail.missing_reason = '';
    detail.note = 'Terminal recording stage excluded from Bernoulli complement product.';
    return;
end

if isempty(candidate_table) || height(candidate_table) == 0
    stage_prob = 1;
    detail.stage_transition_probability = stage_prob;
    detail.probability_status = 'terminal_no_candidate';
    detail.missing_reason = '';
    detail.note = 'No candidate line exists at this terminal or nonconverged stage; transition contribution is recorded as 1.';
    return;
end

probability_column = resolve_probability_column(candidate_table);
if probability_column == ""
    stage_prob = NaN;
    detail.candidate_count = height(candidate_table);
    detail.stage_transition_probability = stage_prob;
    detail.probability_status = 'missing_candidate_probability';
    detail.missing_reason = 'candidate probability column missing';
    detail.note = 'Cannot compute stage transition probability without candidate outage probabilities.';
    return;
end

p = candidate_table.(probability_column)(:);
p = min(max(p, 0), 1);
detail.candidate_count = numel(p);

if ismember('trip_selected', candidate_table.Properties.VariableNames)
    selected_mask = logical(candidate_table.trip_selected(:));
elseif ismember('selected', candidate_table.Properties.VariableNames)
    selected_mask = logical(candidate_table.selected(:));
else
    stage_prob = NaN;
    detail.stage_transition_probability = stage_prob;
    detail.probability_status = 'missing_selected_flag';
    detail.missing_reason = 'candidate selected flag missing';
    detail.note = 'Cannot compute full candidate event without selected/trip_selected flag.';
    return;
end
if ~isempty(selected_outage_ids) && ismember('branch_index', candidate_table.Properties.VariableNames)
    selected_mask = ismember(candidate_table.branch_index(:), selected_outage_ids(:));
elseif ~isempty(selected_outage_ids) && ismember('branch_id', candidate_table.Properties.VariableNames)
    selected_mask = ismember(candidate_table.branch_id(:), selected_outage_ids(:));
elseif ~isempty(selected_outage_ids) && ismember('candidate_branch', candidate_table.Properties.VariableNames)
    selected_mask = ismember(candidate_table.candidate_branch(:), selected_outage_ids(:));
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
        if any(isnan(p))
            stage_prob = NaN;
            detail.unselected_probability_product = NaN;
            detail.probability_status = 'full_event_unavailable';
            detail.missing_reason = 'candidate probability contains NaN';
            detail.note = 'Full-event probability is unavailable because at least one candidate probability is NaN; selected-only is not substituted.';
            detail.stage_transition_probability = stage_prob;
            return;
        end
        if ismember('random_u', candidate_table.Properties.VariableNames)
            expected_selected = candidate_table.random_u(:) < p;
            if any(expected_selected ~= selected_mask)
                stage_prob = NaN;
                detail.unselected_probability_product = NaN;
                detail.probability_status = 'inconsistent_random_selection';
                detail.missing_reason = 'random_u and selected flag are inconsistent';
                detail.note = 'Full-event probability is not reported because candidate selection does not match random_u < probability.';
                detail.stage_transition_probability = stage_prob;
                return;
            end
        end
        if any(~selected_mask & p >= 1)
            stage_prob = NaN;
            detail.unselected_probability_product = NaN;
            detail.probability_status = 'inconsistent_candidate_selection';
            detail.missing_reason = 'candidate_probability=1 but selected=false';
            detail.note = 'Full-event probability is not reported because a probability-one candidate was not selected.';
            detail.stage_transition_probability = stage_prob;
            return;
        end
        unselected_product = prod(1 - p(~selected_mask));
        if isempty(unselected_product)
            unselected_product = 1;
        end
        stage_prob = selected_product * unselected_product;
        detail.unselected_probability_product = unselected_product;
        detail.probability_status = 'full_event_available';
        detail.note = 'Full Bernoulli event probability uses selected probabilities and non-selected complement probabilities.';
    otherwise
        stage_prob = selected_product;
        detail.unselected_probability_product = NaN;
        detail.probability_status = 'selected_only_approximation';
        if detail.selected_candidate_count == 0
            detail.note = 'No additional outage was selected; selected-only transition contribution is recorded as 1. selected_only_product is an approximation and should not be used as final paper risk if full candidate event is available.';
        else
            detail.note = 'Selected-only approximation uses only sampled outage probabilities and does not multiply non-selected complements. selected_only_product is an approximation and should not be used as final paper risk if full candidate event is available.';
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
detail.terminal_stage_flag = false;
detail.should_multiply_candidate_complements = true;
detail.terminal_reason = "";
detail.terminal_stage_note = "";
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

function column_name = resolve_probability_column(candidate_table)
column_name = "";
names = candidate_table.Properties.VariableNames;
if ismember('outage_probability', names)
    column_name = "outage_probability";
elseif ismember('candidate_probability', names)
    column_name = "candidate_probability";
end
end

function value = get_struct_field(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end
