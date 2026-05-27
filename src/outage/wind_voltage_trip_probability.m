function [p, region] = wind_voltage_trip_probability(v_pu, cfg)
%WIND_VOLTAGE_TRIP_PROBABILITY 兼容旧路径的风机电压脱网概率诊断函数。
% 输入：
%   v_pu - 风机并网点电压标幺值。
%   cfg - 可选配置，包含待校准的分段电压阈值。
% 输出：
%   p - 脱网概率诊断值，范围[0,1]。
%   region - 电压区间标签。
% 物理含义：
%   仅用于记录P_WT(h)，不触发实际脱网；保留在outage目录是为了兼容旧调用。
if nargin < 2
    cfg = struct();
end
low_start = get_cfg(cfg, 'wind_trip_low_voltage_start_pu', 0.90);
low_trip = get_cfg(cfg, 'wind_trip_low_voltage_trip_pu', 0.20);
high_start = get_cfg(cfg, 'wind_trip_high_voltage_start_pu', 1.10);
high_trip = get_cfg(cfg, 'wind_trip_high_voltage_trip_pu', 1.30);
prob_cap = get_cfg(cfg, 'wind_trip_probability_cap', 1.0);

p = zeros(size(v_pu));
region = strings(size(v_pu));
for k = 1:numel(v_pu)
    v = v_pu(k);
    if isnan(v)
        p(k) = NaN;
        region(k) = "missing_voltage";
    elseif v <= low_trip
        p(k) = 1;
        region(k) = "low_voltage_forced_trip";
    elseif v < low_start
        p(k) = (low_start - v) / max(low_start - low_trip, eps);
        region(k) = "low_voltage_ramp";
    elseif v <= high_start
        p(k) = 0;
        region(k) = "normal";
    elseif v < high_trip
        p(k) = (v - high_start) / max(high_trip - high_start, eps);
        region(k) = "high_voltage_ramp";
    else
        p(k) = 1;
        region(k) = "high_voltage_forced_trip";
    end
end
p = min(max(p, 0), prob_cap);
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
