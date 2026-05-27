function [mpc, info] = apply_renewable_scenario(mpc, scenario)
%APPLY_RENEWABLE_SCENARIO 将默认风电场景应用到IEEE39系统。
% 输入：
%   mpc - MATPOWER算例结构体。
%   scenario - 新能源场景配置。
% 输出：
%   mpc - 修改后的算例结构体。
%   info - 新能源接入信息，包括风电节点、容量和出力。
% 物理含义：
%   最小版将节点30-39上原机组的有功出力替换为风电出力。该处理用于
%   建立高占比新能源静态潮流场景，不涉及动态控制。

wind_buses = scenario.wind_buses(:);
wind_capacity = scenario.wind_capacity_mw * ones(numel(wind_buses), 1);
wind_p = zeros(numel(wind_buses), 1);

for k = 1:numel(wind_buses)
    wind_p(k) = wind_power_curve(scenario.wind_speed_mps, wind_capacity(k), ...
        scenario.cut_in_speed_mps, scenario.rated_speed_mps, scenario.cut_out_speed_mps);

    gen_row = find(mpc.gen(:, 1) == wind_buses(k), 1);
    if ~isempty(gen_row)
        mpc.gen(gen_row, 2) = wind_p(k);       % PG
        mpc.gen(gen_row, 9) = wind_capacity(k); % PMAX
        mpc.gen(gen_row, 10) = 0;              % PMIN
    end
end

info = struct();
info.wind_buses = wind_buses;
info.wind_capacity_mw = wind_capacity;
info.wind_output_mw = wind_p;
info.total_wind_output_mw = sum(wind_p);
end
