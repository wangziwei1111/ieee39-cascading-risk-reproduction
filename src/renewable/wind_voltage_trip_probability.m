function [trip_probability, trip_region] = wind_voltage_trip_probability(voltage_pu, cfg)
%WIND_VOLTAGE_TRIP_PROBABILITY 计算风机电压脱网概率诊断值。
% 输入：
%   voltage_pu - 风机并网母线电压标幺值。
%   cfg - 全局配置，包含待校准的电压-概率分段参数。
% 输出：
%   trip_probability - 电压导致的脱网概率诊断值，范围[0,1]。
%   trip_region - 电压所在区间：normal/low_voltage_ramp/low_voltage_forced_trip/
%                 high_voltage_ramp/high_voltage_forced_trip。
% 物理含义：
%   这是电压脱网概率诊断模型，只记录P_WT(h)，不抽样、不切除风机，
%   不是完整低电压穿越保护或新能源状态转移模型。

if nargin < 2 || isempty(cfg)
    cfg = struct();
end
low_start = get_cfg(cfg, 'wind_trip_low_voltage_start_pu', 0.90);
low_trip = get_cfg(cfg, 'wind_trip_low_voltage_trip_pu', 0.20);
high_start = get_cfg(cfg, 'wind_trip_high_voltage_start_pu', 1.10);
high_trip = get_cfg(cfg, 'wind_trip_high_voltage_trip_pu', 1.30);
prob_cap = get_cfg(cfg, 'wind_trip_probability_cap', 1.0);

trip_probability = zeros(size(voltage_pu));
trip_region = strings(size(voltage_pu));

for k = 1:numel(voltage_pu)
    v = voltage_pu(k);
    if isnan(v)
        trip_probability(k) = NaN;
        trip_region(k) = "missing_voltage";
    elseif v <= low_trip
        trip_probability(k) = 1;
        trip_region(k) = "low_voltage_forced_trip";
    elseif v < low_start
        trip_probability(k) = (low_start - v) / max(low_start - low_trip, eps);
        trip_region(k) = "low_voltage_ramp";
    elseif v <= high_start
        trip_probability(k) = 0;
        trip_region(k) = "normal";
    elseif v < high_trip
        trip_probability(k) = (v - high_start) / max(high_trip - high_start, eps);
        trip_region(k) = "high_voltage_ramp";
    else
        trip_probability(k) = 1;
        trip_region(k) = "high_voltage_forced_trip";
    end
end

trip_probability = min(max(trip_probability, 0), prob_cap);
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
