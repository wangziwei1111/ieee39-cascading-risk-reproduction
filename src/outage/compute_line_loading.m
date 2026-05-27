function line_table = compute_line_loading(pf_result)
%COMPUTE_LINE_LOADING 计算潮流结果中每条线路的负载率。
% 输入：
%   pf_result - MATPOWER潮流结果结构体。
% 输出：
%   line_table - 表格，包含线路编号、两端母线、状态、两端视在功率、
%                RATE_A和负载率。
% 物理含义：
%   线路后续停运概率由当前负载率驱动。负载率取from端和to端视在功率
%   的较大值除以线路RATE_A；已停运线路负载率置零。

branch = pf_result.branch;
branch_index = (1:size(branch, 1))';
from_bus = branch(:, 1);
to_bus = branch(:, 2);
branch_status = branch(:, 11);

pf = branch(:, 14);
qf = branch(:, 15);
pt = branch(:, 16);
qt = branch(:, 17);
sf_mva = sqrt(pf.^2 + qf.^2);
st_mva = sqrt(pt.^2 + qt.^2);

rate_a = branch(:, 6);
rate_a(rate_a <= 0) = NaN;
loading_pu = max(sf_mva, st_mva) ./ rate_a;
loading_pu(branch_status <= 0) = 0;
loading_pu(isnan(loading_pu)) = 0;

line_table = table(branch_index, from_bus, to_bus, branch_status, ...
    sf_mva, st_mva, rate_a, loading_pu);
end
