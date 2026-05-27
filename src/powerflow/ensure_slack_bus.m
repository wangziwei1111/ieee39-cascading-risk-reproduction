function [mpc, new_slack_bus] = ensure_slack_bus(mpc, main_bus_numbers, original_slack_bus, wind_gen_rows)
%ENSURE_SLACK_BUS 保证主岛内存在且仅存在一个平衡节点。
% 输入：
%   mpc - 已切除非主岛负荷/机组后的MATPOWER算例。
%   main_bus_numbers - 主岛母线编号集合。
%   original_slack_bus - 原始平衡节点编号。
%   wind_gen_rows - 新增或标记为风电机组的gen行号。
% 输出：
%   mpc - 更新bus type后的算例。
%   new_slack_bus - 当前平衡节点编号。
% 物理含义：
%   潮流计算需要一个参考节点。若原平衡机随孤岛被切除，则从主岛在线
%   常规机组中选择新的平衡节点，避免优先让风电机组承担平衡。

if nargin < 4
    wind_gen_rows = [];
end

wind_gen_rows = wind_gen_rows(:);
online_gen_rows = find(mpc.gen(:, 8) > 0 & ismember(mpc.gen(:, 1), main_bus_numbers));
online_conventional_rows = setdiff(online_gen_rows, wind_gen_rows);

if ismember(original_slack_bus, main_bus_numbers) && ...
        any(mpc.gen(:, 1) == original_slack_bus & mpc.gen(:, 8) > 0)
    new_slack_bus = original_slack_bus;
elseif ~isempty(online_conventional_rows)
    [~, idx] = max(mpc.gen(online_conventional_rows, 9));
    new_slack_bus = mpc.gen(online_conventional_rows(idx), 1);
elseif ~isempty(online_gen_rows)
    % 仅当主岛内没有在线常规机组时，才退化选择在线风电机组作为平衡节点。
    [~, idx] = max(mpc.gen(online_gen_rows, 9));
    new_slack_bus = mpc.gen(online_gen_rows(idx), 1);
else
    error('主岛内没有在线发电机，无法设置平衡节点。');
end

% 先将非主岛节点设置为NONE(4)，主岛节点设置为PQ(1)，再把主岛内在线
% 发电机节点设置为PV，最后设置唯一REF。
mpc.bus(:, 2) = 4;
main_bus_rows = ismember(mpc.bus(:, 1), main_bus_numbers);
mpc.bus(main_bus_rows, 2) = 1;
gen_buses = unique(mpc.gen(online_gen_rows, 1));
for k = 1:numel(gen_buses)
    bus_row = find(mpc.bus(:, 1) == gen_buses(k), 1);
    if ~isempty(bus_row)
        mpc.bus(bus_row, 2) = 2;
    end
end

slack_row = find(mpc.bus(:, 1) == new_slack_bus, 1);
mpc.bus(slack_row, 2) = 3;
end
