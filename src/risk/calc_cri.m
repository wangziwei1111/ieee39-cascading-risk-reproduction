function cri = calc_cri(sllr, slfor, snvor, weights)
%CALC_CRI 计算综合风险指标。
% 输入：
%   sllr - 系统负荷损失风险。
%   slfor - 系统线路潮流越限风险。
%   snvor - 系统节点电压越限风险。
%   weights - 三个风险指标的权重。
% 输出：
%   cri - 综合风险指标。
% 物理含义：
%   论文中综合风险指标按SLLR、SLFOR、SNVOR加权得到，默认权重为
%   0.6、0.2、0.2。

if nargin < 4 || isempty(weights)
    weights = [0.6, 0.2, 0.2];
end

weights = weights(:)' / sum(weights);
cri = weights(1) * sllr + weights(2) * slfor + weights(3) * snvor;
end
