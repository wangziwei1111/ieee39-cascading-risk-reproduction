function scenario = get_scenario_by_id(scenario_id, cfg, base_load_mw)
%GET_SCENARIO_BY_ID 按scenario_id读取场景定义。
% 输入：
%   scenario_id - 场景编号字符串。
%   cfg - 全局配置。
%   base_load_mw - 系统总负荷，MW；用于构造渗透率扫描容量。
% 输出：
%   scenario - 场景结构体。
% 物理含义：
%   将场景编号映射为可直接应用到case39的新能源接入和调度参数。

if nargin < 3
    base_load_mw = [];
end

scenarios = build_scenario_library(cfg, base_load_mw);
ids = string({scenarios.scenario_id});
idx = find(ids == string(scenario_id), 1);
if isempty(idx)
    error('未知场景编号：%s', scenario_id);
end

scenario = scenarios(idx);
end
