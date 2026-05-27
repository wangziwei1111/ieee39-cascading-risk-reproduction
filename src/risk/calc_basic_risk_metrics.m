function metrics = calc_basic_risk_metrics(result, violations, shed, base_load_mw)
%CALC_BASIC_RISK_METRICS 计算最小版基础风险指标。
% 输入：
%   result - 潮流结果。
%   violations - 越限检查结果。
%   shed - 简化切负荷结果。
%   base_load_mw - 故障前系统总有功负荷。
% 输出：
%   metrics - 结构体，包含SLLR、SLFOR、SNVOR。
% 物理含义：
%   最小版尚未生成多条马尔可夫事故链，也未做VaR分布估计。因此这里
%   用每个N-1故障的直接后果构造可追溯的简化风险值。

if nargin < 4 || base_load_mw <= 0
    base_load_mw = 1;
end

if ~isfield(shed, 'island_load_shed_mw')
    shed.island_load_shed_mw = 0;
end
if ~isfield(shed, 'corrective_load_shed_mw')
    shed.corrective_load_shed_mw = shed.load_shed_mw;
end
if ~isfield(shed, 'total_load_shed_mw')
    shed.total_load_shed_mw = shed.load_shed_mw;
end

% 简化SLLR：总负荷损失比例。总负荷损失 = 孤岛切除负荷 + 校正切负荷。
sllr = shed.total_load_shed_mw / base_load_mw;

% 简化SLFOR：线路最大越限程度与越限数量共同刻画。
if isnan(violations.max_line_loading_pu)
    slfor = 1.0;
else
    line_excess = max(violations.max_line_loading_pu - 1.0, 0);
    slfor = line_excess * max(violations.num_overloaded_lines, 1);
end

% 简化SNVOR：节点电压最大越限偏差与越限数量共同刻画。
if isnan(violations.max_voltage_deviation_pu)
    snvor = 1.0;
else
    snvor = violations.max_voltage_deviation_pu * max(violations.num_voltage_violations, 1);
end

% 若潮流最终不收敛，记为严重后果。
if ~isfield(result, 'success') || result.success ~= 1
    sllr = max(sllr, 1.0);
    slfor = max(slfor, 1.0);
    snvor = max(snvor, 1.0);
end

metrics = struct();
metrics.island_load_shed_mw = shed.island_load_shed_mw;
metrics.corrective_load_shed_mw = shed.corrective_load_shed_mw;
metrics.total_load_shed_mw = shed.total_load_shed_mw;
metrics.SLLR = sllr;
metrics.SLFOR = slfor;
metrics.SNVOR = snvor;
end
