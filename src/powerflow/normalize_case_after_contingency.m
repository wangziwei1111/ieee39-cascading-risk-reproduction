function [mpc_normalized, island_info] = normalize_case_after_contingency(mpc, cfg, scenario, renewable_info)
%NORMALIZE_CASE_AFTER_CONTINGENCY 故障后孤岛识别与状态标准化。
% 输入：
%   mpc - 线路或机组故障后的MATPOWER算例。
%   cfg - 全局配置，本函数预留使用。
%   scenario - 场景配置，包含原始平衡节点。
%   renewable_info - 新能源接入信息，包含风电机组行号。
% 输出：
%   mpc_normalized - 切除非主岛并保证平衡节点后的算例。
%   island_info - 孤岛处理诊断信息。
% 物理含义：
%   对N-1后的网络先做拓扑连通性处理，记录被解列小岛造成的负荷损失和
%   发电脱网，再把主岛送入潮流计算。

arguments
    mpc struct
    cfg struct %#ok<INUSA>
    scenario struct
    renewable_info struct
end

if isfield(renewable_info, 'wind_gen_rows')
    wind_gen_rows = renewable_info.wind_gen_rows(:);
else
    wind_gen_rows = [];
end

if isfield(scenario, 'slack_bus')
    original_slack_bus = scenario.slack_bus;
else
    original_slack_rows = find(mpc.bus(:, 2) == 3);
    original_slack_bus = mpc.bus(original_slack_rows(1), 1);
end

[bus_island_id, island_summary] = detect_islands(mpc);
[main_island_id, selection_reason] = select_main_island(island_summary, cfg);
main_bus_numbers = island_summary.bus_list{island_summary.island_id == main_island_id};
main_row = island_summary(island_summary.island_id == main_island_id, :);

original_slack_island_id = NaN;
original_slack_row = island_summary(island_summary.has_original_slack, :);
if ~isempty(original_slack_row)
    original_slack_island_id = original_slack_row.island_id(1);
    original_slack_island_load_mw = original_slack_row.total_load_mw(1);
    original_slack_island_load_share = original_slack_row.load_share(1);
    original_slack_island_generation_mw = original_slack_row.online_generation_mw(1);
else
    original_slack_island_load_mw = 0;
    original_slack_island_load_share = 0;
    original_slack_island_generation_mw = 0;
end

bus_in_main = ismember(mpc.bus(:, 1), main_bus_numbers);
gen_in_main = ismember(mpc.gen(:, 1), main_bus_numbers);
branch_in_main = ismember(mpc.branch(:, 1), main_bus_numbers) & ...
    ismember(mpc.branch(:, 2), main_bus_numbers);

disconnected_bus_rows = find(~bus_in_main);
disconnected_gen_rows = find(~gen_in_main & mpc.gen(:, 8) > 0);
disconnected_wind_rows = intersect(disconnected_gen_rows, wind_gen_rows);

disconnected_load_mw = sum(mpc.bus(disconnected_bus_rows, 3));
disconnected_generation_mw = sum(mpc.gen(disconnected_gen_rows, 2));
disconnected_wind_mw = sum(mpc.gen(disconnected_wind_rows, 2));

mpc_normalized = mpc;
mpc_normalized.bus(disconnected_bus_rows, 3) = 0; % PD
mpc_normalized.bus(disconnected_bus_rows, 4) = 0; % QD
mpc_normalized.gen(disconnected_gen_rows, 8) = 0; % GEN_STATUS
mpc_normalized.branch(~branch_in_main, 11) = 0;   % BR_STATUS

original_slack_in_main_island = ismember(original_slack_bus, main_bus_numbers);
[mpc_normalized, new_slack_bus] = ensure_slack_bus( ...
    mpc_normalized, main_bus_numbers, original_slack_bus, wind_gen_rows);

island_info = struct();
island_info.island_count = height(island_summary);
island_info.main_island_id = main_island_id;
island_info.disconnected_load_mw = disconnected_load_mw;
island_info.disconnected_generation_mw = disconnected_generation_mw;
island_info.disconnected_wind_mw = disconnected_wind_mw;
island_info.original_slack_in_main_island = original_slack_in_main_island;
island_info.new_slack_bus = new_slack_bus;
island_info.main_island_load_mw = main_row.total_load_mw;
island_info.main_island_load_share = main_row.load_share;
island_info.main_island_generation_mw = main_row.online_generation_mw;
island_info.main_island_gen_share = main_row.gen_share;
island_info.original_slack_island_id = original_slack_island_id;
island_info.original_slack_island_load_mw = original_slack_island_load_mw;
island_info.original_slack_island_load_share = original_slack_island_load_share;
island_info.original_slack_island_generation_mw = original_slack_island_generation_mw;
island_info.main_island_selection_reason = selection_reason;
island_info.island_bus_summary = island_summary;
island_info.bus_island_id = bus_island_id;
end
