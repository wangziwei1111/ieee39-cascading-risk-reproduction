function [mpc, applied_outages] = apply_line_outages(mpc, branch_indices)
%APPLY_LINE_OUTAGES 将指定线路设置为停运。
% 输入：
%   mpc - MATPOWER算例结构体。
%   branch_indices - 本级需要新增停运的线路编号。
% 输出：
%   mpc - 更新后的算例。
%   applied_outages - 实际成功设置为停运的线路编号。
% 物理含义：
%   线路停运通过MATPOWER的BR_STATUS=0表示，是事故链状态转移的执行步骤。

branch_indices = unique(branch_indices(:));
branch_indices = branch_indices(branch_indices >= 1 & branch_indices <= size(mpc.branch, 1));
applied_outages = branch_indices(mpc.branch(branch_indices, 11) > 0);
mpc.branch(applied_outages, 11) = 0;
end
