function [main_island_id, selection_reason] = select_main_island(island_summary, cfg)
%SELECT_MAIN_ISLAND 从所有电气孤岛中选择主岛。
% 输入：
%   island_summary - detect_islands输出的孤岛汇总表。
%   cfg - 全局配置，包含主岛选择阈值。
% 输出：
%   main_island_id - 被保留用于后续潮流计算的主岛编号。
%   selection_reason - 主岛选择原因，便于诊断。
% 物理含义：
%   连锁故障静态仿真通常保留主要受端/主网孤岛，切除与主网解列的小岛。
%   这里的规则服务于准静态潮流计算，不代表完整暂态解列过程。

if nargin < 2 || ~isfield(cfg, 'main_island_min_load_share')
    min_slack_load_share = 0.5;
else
    min_slack_load_share = cfg.main_island_min_load_share;
end

% 规则1：原平衡节点只作为加分项，不再绝对优先。只有当原平衡节点所在岛
% 同时有负荷、有发电能力，且承担的负荷比例不低于阈值时，才保留该岛。
slack_candidates = island_summary(island_summary.has_original_slack & ...
    island_summary.has_load & island_summary.has_generation & ...
    island_summary.load_share >= min_slack_load_share, :);
if ~isempty(slack_candidates)
    [~, idx] = max(slack_candidates.load_share);
    main_island_id = slack_candidates.island_id(idx);
    selection_reason = "original_slack_island_has_sufficient_load";
    return;
end

% 规则2：选择有负荷且有在线发电能力的最大负荷岛。该岛通常代表可继续
% 进行系统风险评估的主网，而不是孤立发电机小岛。
load_candidates = island_summary(island_summary.has_load & island_summary.has_generation, :);
if ~isempty(load_candidates)
    [~, idx] = sortrows([load_candidates.load_share, load_candidates.online_conventional_mw], ...
        [-1, -2]);
    idx = idx(1);
    main_island_id = load_candidates.island_id(idx);
    selection_reason = "largest_load_island_selected";
    return;
end

% 规则3：若多个岛缺少负荷但仍有发电，则选择在线常规机组容量最大的岛。
% 常规机组优先于风电，是为了后续能够自然设置平衡节点。
gen_candidates = island_summary(island_summary.has_conventional_generation, :);
if ~isempty(gen_candidates)
    [~, idx] = max(gen_candidates.online_conventional_mw);
    main_island_id = gen_candidates.island_id(idx);
    selection_reason = "largest_conventional_generation_selected";
    return;
end

% 规则4：极端退化情形下选择母线数最多的岛，避免返回空值。
[~, idx] = max(island_summary.bus_count);
main_island_id = island_summary.island_id(idx);
selection_reason = "largest_bus_count_selected";
end
