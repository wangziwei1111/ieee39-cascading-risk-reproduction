function scenario = scenario_config()
%SCENARIO_CONFIG 默认新能源接入场景配置。
% 输入：
%   无。
% 输出：
%   scenario - 结构体，描述新能源接入节点、容量、风速和调度模式。
% 物理含义：
%   论文场景2为节点30至39分散式接入总容量3000 MW新能源机组，
%   渗透率约40%。论文未说明各节点容量分配方式，最小版采用等容量
%   分配并标注为“待校准”。

scenario = struct();
scenario.name = 'minimal_distributed_wind_40pct';

% IEEE 39 节点中 30-39 为发电机节点。
scenario.wind_buses = (30:39)';

% 新能源调度模式：
%   replace_pg_current：直接把指定节点现有机组PG替换为风电PG，
%       仅用于第一版流程测试，物理意义较弱。
%   wind_plus_redispatch：新增风电注入，同时按比例降低常规机组PG，
%       使系统总发电与原始运行点/总负荷保持接近。默认使用该模式。
scenario.renewable_dispatch_mode = 'wind_plus_redispatch';

% 保留一个常规平衡机用于潮流平衡。case39中节点31为平衡机节点。
scenario.slack_bus = 31;

% 总风电容量 3000 MW，按10个节点等分。待校准。
scenario.total_wind_capacity_mw = 3000.0;
scenario.wind_capacity_mw = scenario.total_wind_capacity_mw / numel(scenario.wind_buses);

% 论文默认风机在额定风速下运行。
scenario.wind_speed_mps = 12.0;

% 风机出力曲线参数。
scenario.cut_in_speed_mps = 2.0;
scenario.rated_speed_mps = 12.0;
scenario.cut_out_speed_mps = 20.0;

% 场景说明，写入结果日志。
scenario.description = ['节点30至39分散式接入总容量3000 MW风电；', ...
    '默认采用wind_plus_redispatch，新增风电并下调常规机组；', ...
    '各节点等容量分配为最小版假设，待校准。'];
end
