function [trigger, trigger_reason, trigger_detail] = should_trigger_load_shedding(pf_result, converged_before_shedding, violations, cfg)
%SHOULD_TRIGGER_LOAD_SHEDDING 判断当前阶段是否应触发切负荷策略。
% 输入：
%   pf_result - run_ac_powerflow 得到的潮流结果。
%   converged_before_shedding - 切负荷前潮流是否收敛。
%   violations - check_violations 的预检查结果。
%   cfg - 全局配置，包含 OLS/切负荷触发模式和阈值。
% 输出：
%   trigger - 是否触发切负荷或诊断。
%   trigger_reason - 触发原因：nonconverged_powerflow、line_overload等。
%   trigger_detail - 越限和电压诊断字段。
% 物理含义：
%   论文式 OLS 含线路容量和节点电压约束，因此除潮流不收敛外，也可配置为在
%   线路/电压越限时触发；默认仍只在非收敛时触发，保持既有结果。

if isfield(cfg, 'load_shedding_trigger_mode')
    mode = lower(string(cfg.load_shedding_trigger_mode));
else
    mode = "nonconverged_only";
end

detail = build_trigger_detail(pf_result, converged_before_shedding, violations, cfg);
trigger_detail = detail;
trigger = false;
trigger_reason = "none";

switch mode
    case "nonconverged_only"
        if ~converged_before_shedding
            trigger = true;
            trigger_reason = "nonconverged_powerflow";
        end

    case "nonconverged_or_violation"
        if ~converged_before_shedding
            trigger = true;
            trigger_reason = "nonconverged_powerflow";
        elseif detail.line_overload_flag && detail.voltage_violation_flag
            trigger = true;
            trigger_reason = "line_and_voltage_violation";
        elseif detail.line_overload_flag
            trigger = true;
            trigger_reason = "line_overload";
        elseif detail.voltage_violation_flag
            trigger = true;
            trigger_reason = "voltage_violation";
        end

    case "violation_only_diagnostic"
        if converged_before_shedding && (detail.line_overload_flag || detail.voltage_violation_flag)
            trigger = true;
            trigger_reason = "diagnostic_violation_only";
        end

    otherwise
        error('未知 load_shedding_trigger_mode：%s', mode);
end

trigger_detail.trigger_mode = mode;
trigger_detail.trigger_reason = trigger_reason;
end

function detail = build_trigger_detail(pf_result, converged_before_shedding, violations, cfg)
detail = struct();
detail.converged_before_shedding = logical(converged_before_shedding);
detail.max_line_loading_pu = get_numeric_field(violations, 'max_line_loading_pu', NaN);
detail.max_voltage_deviation_pu = get_numeric_field(violations, 'max_voltage_deviation_pu', NaN);
detail.min_voltage_pu = NaN;
detail.max_voltage_pu = NaN;

if isstruct(pf_result) && isfield(pf_result, 'bus') && ~isempty(pf_result.bus)
    vm = pf_result.bus(:, 8);
    detail.min_voltage_pu = min(vm, [], 'omitnan');
    detail.max_voltage_pu = max(vm, [], 'omitnan');
end

if ~isfield(cfg, 'load_shedding_violation_check_enable') || cfg.load_shedding_violation_check_enable
    line_threshold = get_cfg(cfg, 'load_shedding_line_overload_threshold_pu', 1.0);
    vmin = get_cfg(cfg, 'load_shedding_voltage_min_pu', get_cfg(cfg, 'voltage_min_pu', 0.90));
    vmax = get_cfg(cfg, 'load_shedding_voltage_max_pu', get_cfg(cfg, 'voltage_max_pu', 1.10));
    use_line = get_cfg(cfg, 'load_shedding_trigger_line_overload', true);
    use_voltage = get_cfg(cfg, 'load_shedding_trigger_voltage_violation', true);
    detail.line_overload_flag = logical(use_line) && ...
        ~isnan(detail.max_line_loading_pu) && detail.max_line_loading_pu > line_threshold;
    detail.voltage_violation_flag = logical(use_voltage) && ...
        ~isnan(detail.min_voltage_pu) && ~isnan(detail.max_voltage_pu) && ...
        (detail.min_voltage_pu < vmin || detail.max_voltage_pu > vmax);
else
    detail.line_overload_flag = false;
    detail.voltage_violation_flag = false;
end
end

function value = get_numeric_field(s, name, default_value)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = default_value;
end
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
