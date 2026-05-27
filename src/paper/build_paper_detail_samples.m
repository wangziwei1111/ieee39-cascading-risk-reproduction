function [line_flow_sample_table, bus_voltage_sample_table] = ...
    build_paper_detail_samples(line_flow_detail_table, bus_voltage_detail_table)
%BUILD_PAPER_DETAIL_SAMPLES 构造paper_formula大明细表的人工复核样本。
% 输入：
%   line_flow_detail_table - 每级全线路有功潮流明细。
%   bus_voltage_detail_table - 每级全节点电压明细。
% 输出：
%   line_flow_sample_table - 线路明细样本，保留最严重线路越限和最大有功负载率行。
%   bus_voltage_sample_table - 电压明细样本，保留最严重电压越限和最大电压偏差行。
% 物理含义：
%   sample文件用于在GitHub中快速人工检查paper_formula明细是否可信，完整复核仍以manifest+chunks为准。

line_idx = unique([top_indices(line_flow_detail_table.line_severity_component, 1000); ...
    top_indices(line_flow_detail_table.P_li_pu, 1000)], 'stable');
line_flow_sample_table = line_flow_detail_table(line_idx, :);

bus_idx = unique([top_indices(bus_voltage_detail_table.voltage_severity_component, 1000); ...
    top_indices(bus_voltage_detail_table.voltage_deviation_component, 1000)], 'stable');
bus_voltage_sample_table = bus_voltage_detail_table(bus_idx, :);
end

function idx = top_indices(values, n)
%TOP_INDICES 返回数值最大的前n个行号。
if isempty(values)
    idx = [];
    return;
end
[~, order] = sort(values, 'descend');
idx = order(1:min(n, numel(order)));
idx = idx(:);
end
