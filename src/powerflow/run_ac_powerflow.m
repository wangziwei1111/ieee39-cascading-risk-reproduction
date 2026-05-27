function [result, converged] = run_ac_powerflow(mpc)
%RUN_AC_POWERFLOW 运行MATPOWER交流潮流。
% 输入：
%   mpc - MATPOWER算例结构体。
% 输出：
%   result - MATPOWER潮流结果结构体。
%   converged - 布尔值，表示潮流是否收敛。
% 物理含义：
%   潮流计算给出故障后稳态的节点电压、线路潮流和系统功率平衡状态。

mpopt = mpoption('verbose', 0, 'out.all', 0);

% 某些N-1开断会造成孤岛或病态雅可比矩阵，MATPOWER会给出奇异矩阵警告。
% 最小版将这些情况交由success标志和后续切负荷逻辑处理，日志中不重复打印警告。
warn_states = warning;
warning('off', 'MATLAB:singularMatrix');
warning('off', 'MATLAB:nearlySingularMatrix');
cleanup_warning = onCleanup(@() warning(warn_states)); %#ok<NASGU>

result = runpf(mpc, mpopt);
converged = isfield(result, 'success') && result.success == 1;
end
