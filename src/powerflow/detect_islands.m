function [bus_island_id, island_summary] = detect_islands(mpc)
%DETECT_ISLANDS 识别由在线输电线路构成的电气连通分量。
% 输入：
%   mpc - MATPOWER算例结构体，使用branch(:,11)>0表示在线线路。
% 输出：
%   bus_island_id - 每个bus行所属的孤岛编号。
%   island_summary - 每个孤岛的母线、负荷、在线发电和风电信息。
% 物理含义：
%   N-1开断发电机接入支路时，发电机节点可能从主网脱离。潮流计算前
%   需要先识别这些电气孤岛，避免把拓扑解列误判为普通潮流不收敛。

nb = size(mpc.bus, 1);
bus_numbers = mpc.bus(:, 1);
bus_index = containers.Map(num2cell(bus_numbers), num2cell((1:nb)'));

adj = false(nb, nb);
active = mpc.branch(:, 11) > 0;
for k = find(active)'
    from_bus = mpc.branch(k, 1);
    to_bus = mpc.branch(k, 2);
    if isKey(bus_index, from_bus) && isKey(bus_index, to_bus)
        i = bus_index(from_bus);
        j = bus_index(to_bus);
        adj(i, j) = true;
        adj(j, i) = true;
    end
end

bus_island_id = zeros(nb, 1);
island_count = 0;
for start = 1:nb
    if bus_island_id(start) ~= 0
        continue;
    end
    island_count = island_count + 1;
    queue = start;
    bus_island_id(start) = island_count;
    while ~isempty(queue)
        current = queue(1);
        queue(1) = [];
        neighbors = find(adj(current, :));
        for next = neighbors
            if bus_island_id(next) == 0
                bus_island_id(next) = island_count;
                queue(end + 1) = next; %#ok<AGROW>
            end
        end
    end
end

wind_gen_rows = [];
if isfield(mpc, 'userdata') && isfield(mpc.userdata, 'wind_gen_rows')
    wind_gen_rows = mpc.userdata.wind_gen_rows(:);
    wind_gen_rows = wind_gen_rows(wind_gen_rows >= 1 & wind_gen_rows <= size(mpc.gen, 1));
end

island_id = (1:island_count)';
bus_list = cell(island_count, 1);
bus_count = zeros(island_count, 1);
total_load_mw = zeros(island_count, 1);
online_generation_mw = zeros(island_count, 1);
online_wind_mw = zeros(island_count, 1);
online_conventional_mw = zeros(island_count, 1);
has_online_gen = false(island_count, 1);
has_online_conventional_gen = false(island_count, 1);

for island = 1:island_count
    rows = find(bus_island_id == island);
    buses = bus_numbers(rows);
    bus_list{island} = buses(:)';
    bus_count(island) = numel(rows);
    total_load_mw(island) = sum(mpc.bus(rows, 3));

    gen_rows = find(ismember(mpc.gen(:, 1), buses) & mpc.gen(:, 8) > 0);
    wind_rows = intersect(gen_rows, wind_gen_rows);
    conventional_rows = setdiff(gen_rows, wind_gen_rows);

    online_generation_mw(island) = sum(mpc.gen(gen_rows, 2));
    online_wind_mw(island) = sum(mpc.gen(wind_rows, 2));
    online_conventional_mw(island) = sum(mpc.gen(conventional_rows, 2));
    has_online_gen(island) = ~isempty(gen_rows);
    has_online_conventional_gen(island) = ~isempty(conventional_rows);
end

has_original_slack = false(island_count, 1);
slack_rows = find(mpc.bus(:, 2) == 3);
if ~isempty(slack_rows)
    slack_islands = unique(bus_island_id(slack_rows));
    has_original_slack(ismember(island_id, slack_islands)) = true;
end

island_summary = table(island_id, bus_count, bus_list, total_load_mw, ...
    online_generation_mw, online_conventional_mw, online_wind_mw, ...
    has_online_gen, has_online_conventional_gen, has_original_slack);
end
