function violations = check_violations(result, cfg)
%CHECK_VIOLATIONS 检查线路潮流越限和节点电压越限。
% 输入：
%   result - MATPOWER潮流结果。
%   cfg - 全局配置，包含电压上下限。
% 输出：
%   violations - 结构体，记录越限数量和最大偏移。
% 物理含义：
%   线路越限表示潮流超过热稳容量；电压越限表示母线电压偏离允许区间。

violations = struct();

if ~isfield(result, 'success') || result.success ~= 1
    violations.num_overloaded_lines = NaN;
    violations.max_line_loading_pu = NaN;
    violations.num_voltage_violations = NaN;
    violations.max_voltage_deviation_pu = NaN;
    return;
end

rate_a = result.branch(:, 6);
rate_a(rate_a <= 0) = cfg.default_branch_rate_mva;

pf = result.branch(:, 14);
qf = result.branch(:, 15);
pt = result.branch(:, 16);
qt = result.branch(:, 17);
sf = sqrt(pf.^2 + qf.^2);
st = sqrt(pt.^2 + qt.^2);
loading = max(sf, st) ./ rate_a;

active_branch = result.branch(:, 11) > 0;
loading(~active_branch) = 0;
overloaded = loading > 1.0;

vm = result.bus(:, 8);
low_v = vm < cfg.voltage_min_pu;
high_v = vm > cfg.voltage_max_pu;
v_dev = max([cfg.voltage_min_pu - vm, vm - cfg.voltage_max_pu, zeros(size(vm))], [], 2);

violations.num_overloaded_lines = sum(overloaded);
violations.max_line_loading_pu = max(loading);
violations.num_voltage_violations = sum(low_v | high_v);
violations.max_voltage_deviation_pu = max(v_dev);
end
