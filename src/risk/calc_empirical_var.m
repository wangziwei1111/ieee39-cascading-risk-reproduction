function var_value = calc_empirical_var(values, sigma, weights)
%CALC_EMPIRICAL_VAR 计算右尾风险的经验VaR分位数。
% 输入：
%   values - 风险样本值，数值越大表示后果越严重。
%   sigma - 置信水平，例如0.95。
%   weights - 可选样本权重；为空时使用无权重经验分位数。
% 输出：
%   var_value - sigma分位数对应的VaR值。
% 物理含义：
%   当前风险越大越严重，因此VaR_sigma取样本分布的sigma分位数。
%   本函数是经验分位数方法，不做Logistic/指数等概率密度拟合。

if nargin < 3
    weights = [];
end

values = values(:);
if isempty(weights)
    weights = [];
else
    weights = weights(:);
end

valid = ~isnan(values);
if ~isempty(weights)
    valid = valid & ~isnan(weights) & weights > 0;
end
values = values(valid);
if ~isempty(weights)
    weights = weights(valid);
end

if isempty(values)
    var_value = NaN;
    return;
end

sigma = min(max(sigma, 0), 1);

if isempty(weights)
    sorted_values = sort(values);
    idx = max(1, ceil(sigma * numel(sorted_values)));
    var_value = sorted_values(idx);
else
    [sorted_values, order] = sort(values);
    sorted_weights = weights(order);
    sorted_weights = sorted_weights / sum(sorted_weights);
    cdf = cumsum(sorted_weights);
    idx = find(cdf >= sigma, 1, 'first');
    if isempty(idx)
        idx = numel(sorted_values);
    end
    var_value = sorted_values(idx);
end
end
