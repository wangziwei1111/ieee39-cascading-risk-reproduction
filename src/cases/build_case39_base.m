function mpc = build_case39_base(cfg)
%BUILD_CASE39_BASE 加载并整理MATPOWER IEEE 39节点算例。
% 输入：
%   cfg - 全局配置，包含默认线路容量。
% 输出：
%   mpc - MATPOWER算例结构体。
% 物理含义：
%   使用MATPOWER自带case39作为基础系统。若线路RATE_A未设置，则用
%   默认容量填充，以便最小版可以进行线路越限判断。

mpc = loadcase('case39');

% MATPOWER branch列定义中，第6列RATE_A为长期容量。
rate_a_col = 6;
missing_rate = mpc.branch(:, rate_a_col) <= 0;
mpc.branch(missing_rate, rate_a_col) = cfg.default_branch_rate_mva;
end
