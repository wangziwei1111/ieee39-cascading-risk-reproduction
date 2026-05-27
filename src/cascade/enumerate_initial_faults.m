function faults = enumerate_initial_faults(mpc)
%ENUMERATE_INITIAL_FAULTS 枚举IEEE39全部线路N-1初始故障。
% 输入：
%   mpc - MATPOWER算例结构体。
% 输出：
%   faults - 表格，每行表示一条被开断的线路。
% 物理含义：
%   论文以某条输电线路开断作为事故链开端。最小版只枚举初始N-1，
%   暂不扩展后续马尔可夫事故链。

branch_index = (1:size(mpc.branch, 1))';
from_bus = mpc.branch(:, 1);
to_bus = mpc.branch(:, 2);
faults = table(branch_index, from_bus, to_bus);
end
