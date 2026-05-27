function candidate_table = update_line_outage_probabilities(mpc, pf_result, cfg, already_outaged_branches)
%UPDATE_LINE_OUTAGE_PROBABILITIES 更新当前状态下候选线路停运概率。
% 输入：
%   mpc - 当前标准化后的MATPOWER算例。
%   pf_result - 当前潮流结果。
%   cfg - 全局配置，包含线路概率模型和抽样方式。
%   already_outaged_branches - 已经停运的线路编号，不能再次作为候选。
% 输出：
%   candidate_table - 候选线路表，含负载率、停运概率、随机数和是否选中。
% 物理含义：
%   每一级事故后，根据当前线路负载率计算下一阶段可能跳闸的线路集合。

if nargin < 4
    already_outaged_branches = [];
end

line_table = compute_line_loading(pf_result);
online = mpc.branch(:, 11) > 0 & line_table.branch_status > 0;
not_outaged = ~ismember(line_table.branch_index, already_outaged_branches(:));
candidate_mask = online & not_outaged;

candidate_table = line_table(candidate_mask, {'branch_index', 'from_bus', 'to_bus', 'loading_pu'});
num_candidates = height(candidate_table);
outage_probability = zeros(num_candidates, 1);
for k = 1:num_candidates
    outage_probability(k) = line_outage_probability(candidate_table.loading_pu(k), cfg);
end

keep = outage_probability >= cfg.markov_min_trip_probability;
candidate_table = candidate_table(keep, :);
outage_probability = outage_probability(keep);
num_candidates = height(candidate_table);

random_u = rand(num_candidates, 1);
trip_selected = outage_probability >= random_u;

if ~cfg.markov_allow_multiple_trips_per_stage && any(trip_selected)
    selected_idx = find(trip_selected);
    [~, best_local] = max(outage_probability(selected_idx));
    keep_one = false(num_candidates, 1);
    keep_one(selected_idx(best_local)) = true;
    trip_selected = keep_one;
end

candidate_table.outage_probability = outage_probability;
candidate_table.random_u = random_u;
candidate_table.trip_selected = trip_selected;
end
