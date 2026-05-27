function selected_scenario_ids = select_scenarios_by_batch_mode(scenarios, batch_mode)
%SELECT_SCENARIOS_BY_BATCH_MODE 按批处理模式选择场景编号。
% 输入：
%   scenarios - build_scenario_library返回的场景结构体数组。
%   batch_mode - 批处理模式：smoke/topology_compare/penetration_scan等。
% 输出：
%   selected_scenario_ids - 场景编号cell数组。
% 物理含义：
%   将第4章场景拆成可断点续跑的小组，避免一次性运行全部场景导致耗时和失败恢复困难。

all_ids = string({scenarios.scenario_id});
mode = string(batch_mode);

switch mode
    case "smoke"
        wanted = ["no_renewable_base", "distributed_wind_40pct", "centralized_wind_40pct"];
    case "topology_compare"
        wanted = ["no_renewable_base", "distributed_wind_40pct", "centralized_wind_40pct"];
    case "penetration_scan"
        wanted = "distributed_wind_" + string(40:5:80) + "pct";
    case "wind_speed_scan"
        wanted = "wind_speed_" + string([8, 10, 12, 14, 16]) + "mps";
    case "renewable_trip_record"
        wanted = ["distributed_wind_40pct", "distributed_wind_40pct_trip_record_only"];
    case "all_full"
        selected_scenario_ids = cellstr(all_ids);
        return;
    otherwise
        error('未知batch_mode：%s', batch_mode);
end

missing = setdiff(wanted, all_ids);
if ~isempty(missing)
    error('场景库缺少batch_mode=%s所需场景：%s', batch_mode, strjoin(missing, ', '));
end
selected_scenario_ids = cellstr(wanted);
end
