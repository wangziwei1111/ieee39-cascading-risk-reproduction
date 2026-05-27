function main_island_id = select_main_island(island_summary)
%SELECT_MAIN_ISLAND 从所有电气孤岛中选择主岛。
% 输入：
%   island_summary - detect_islands输出的孤岛汇总表。
% 输出：
%   main_island_id - 被保留用于后续潮流计算的主岛编号。
% 物理含义：
%   连锁故障静态仿真通常保留主要受端/主网孤岛，切除与主网解列的小岛。
%   这里的规则服务于准静态潮流计算，不代表完整暂态解列过程。

% 规则1：优先选择包含原平衡节点、且同时具备有效负荷和在线发电能力的岛。
slack_candidates = island_summary( ...
    island_summary.has_original_slack & ...
    island_summary.total_load_mw > 1e-6 & ...
    island_summary.online_generation_mw > 1e-6, :);
if ~isempty(slack_candidates)
    main_island_id = slack_candidates.island_id(1);
    return;
end

% 规则2：如果原平衡节点所在岛没有有效负荷或发电能力，则选择总负荷最大的岛。
load_candidates = island_summary(island_summary.total_load_mw > 1e-6, :);
if ~isempty(load_candidates)
    [~, idx] = max(load_candidates.total_load_mw);
    main_island_id = load_candidates.island_id(idx);
    return;
end

% 规则3：如果没有有效负荷，则选择在线发电容量最大的岛，保证潮流模型仍有电源岛。
gen_candidates = island_summary(island_summary.online_generation_mw > 1e-6, :);
if ~isempty(gen_candidates)
    [~, idx] = max(gen_candidates.online_generation_mw);
    main_island_id = gen_candidates.island_id(idx);
    return;
end

% 规则4：极端退化情形下选择母线数最多的岛，避免返回空值。
[~, idx] = max(island_summary.bus_count);
main_island_id = island_summary.island_id(idx);
end
