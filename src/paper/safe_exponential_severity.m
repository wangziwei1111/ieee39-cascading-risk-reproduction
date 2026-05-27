function [severity_component, valid_flag, invalid_reason] = safe_exponential_severity(component, cfg)
%SAFE_EXPONENTIAL_SEVERITY 安全计算论文指数型严重度分量。
% 输入：
%   component - 指数效用函数的非负自变量，例如线路越限量或电压偏差量。
%   cfg - 全局配置，包含 paper_max_exp_argument 和 fail_if_inf 策略。
% 输出：
%   severity_component - (exp(component)-1)/(exp(1)-1)*100。
%   valid_flag - 逻辑值，true表示该分量可用于paper_formula。
%   invalid_reason - 字符串，说明无效原因。
% 物理含义：
%   非收敛潮流或异常数值会让指数函数溢出为Inf。本函数显式阻断这类非物理结果，
%   避免把Inf或离谱大数带入论文LFOR/NVOR。

if any(component < 0, 'all')
    error('指数严重度自变量不能为负数。');
end

severity_component = NaN(size(component));
valid_flag = true(size(component));
invalid_reason = strings(size(component));
invalid_reason(:) = "none";

bad_nan = isnan(component);
valid_flag(bad_nan) = false;
invalid_reason(bad_nan) = "nan_component";

too_large = component > cfg.paper_max_exp_argument;
valid_flag(too_large) = false;
invalid_reason(too_large) = "exp_argument_too_large";

ok = valid_flag;
severity_component(ok) = (exp(component(ok)) - 1) / (exp(1) - 1) * 100;

bad_inf = isinf(severity_component) | isnan(severity_component);
valid_flag(bad_inf) = false;
invalid_reason(bad_inf) = "inf_or_nan_severity";
if isfield(cfg, 'paper_fail_if_inf_severity') && cfg.paper_fail_if_inf_severity && any(isinf(severity_component), 'all')
    error('指数严重度出现Inf，已停止paper_formula计算。');
end
end
