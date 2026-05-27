function wind_trip_summary_table = summarize_wind_trip_records(wind_trip_detail_table)
%SUMMARIZE_WIND_TRIP_RECORDS 汇总风机电压脱网概率诊断表。
% 输入：
%   wind_trip_detail_table - 逐级逐风机电压脱网概率明细。
% 输出：
%   wind_trip_summary_table - 全局统计量，用于场景汇总和自检。
% 物理含义：
%   统计record-only脱网概率的大小、分布和电压范围，不代表实际脱网次数。

if isempty(wind_trip_detail_table) || height(wind_trip_detail_table) == 0
    wind_trip_summary_table = table(0, 0, 0, 0, NaN, NaN, NaN, 0, 0, 0, NaN, NaN, ...
        'VariableNames', {'total_rows', 'unique_chain_count', 'unique_stage_count', ...
        'unique_wind_bus_count', 'max_trip_probability', 'mean_trip_probability', ...
        'p95_trip_probability', 'num_probability_positive', 'num_probability_above_0_1', ...
        'num_probability_equal_1', 'min_wind_voltage_pu', 'max_wind_voltage_pu'});
    return;
end

chain_key = string(wind_trip_detail_table.initial_branch) + "_" + string(wind_trip_detail_table.trial_id);
stage_key = chain_key + "_" + string(wind_trip_detail_table.stage_id);
prob = wind_trip_detail_table.trip_probability;
voltage = wind_trip_detail_table.voltage_pu;

wind_trip_summary_table = table(height(wind_trip_detail_table), numel(unique(chain_key)), ...
    numel(unique(stage_key)), numel(unique(wind_trip_detail_table.wind_bus)), ...
    max(prob, [], 'omitnan'), mean(prob, 'omitnan'), percentile_local(prob, 95), ...
    sum(prob > 0), sum(prob > 0.1), sum(abs(prob - 1) < 1e-12), ...
    min(voltage, [], 'omitnan'), max(voltage, [], 'omitnan'), ...
    'VariableNames', {'total_rows', 'unique_chain_count', 'unique_stage_count', ...
    'unique_wind_bus_count', 'max_trip_probability', 'mean_trip_probability', ...
    'p95_trip_probability', 'num_probability_positive', 'num_probability_above_0_1', ...
    'num_probability_equal_1', 'min_wind_voltage_pu', 'max_wind_voltage_pu'});
end

function value = percentile_local(x, p)
x = sort(x(~isnan(x)));
if isempty(x)
    value = NaN;
    return;
end
idx = max(1, min(numel(x), ceil(p / 100 * numel(x))));
value = x(idx);
end
