function [mpc_shed, result, shed] = simple_load_shedding(mpc, cfg, existing_shed_mw)
%SIMPLE_LOAD_SHEDDING 简化按比例负荷削减。
% 输入：
%   mpc - 故障后的MATPOWER算例。
%   cfg - 全局配置，包含每轮切负荷比例和最大切负荷比例。
%   existing_shed_mw - 可选，进入本函数前已发生的负荷损失，例如孤岛切除。
% 输出：
%   mpc_shed - 切负荷后的算例。
%   result - 最后一轮潮流结果。
%   shed - 切负荷信息，包括切负荷MW、比例、迭代次数和是否收敛。
% 物理含义：
%   该函数不是论文中的最优负荷削减模型，而是最小版校正控制。
%   它按比例降低所有负荷，尝试恢复潮流收敛。

if nargin < 3
    existing_shed_mw = 0;
end

mpc_shed = mpc;
original_pd = mpc.bus(:, 3);
original_qd = mpc.bus(:, 4);
base_load = sum(original_pd);

result = struct('success', 0, 'bus', mpc.bus, 'branch', mpc.branch);
converged = false;
applied_frac = 0;

for iter = 1:cfg.load_shed_max_iter
    applied_frac = min(iter * cfg.load_shed_step, cfg.load_shed_max_frac);
    mpc_shed.bus(:, 3) = original_pd * (1 - applied_frac);
    mpc_shed.bus(:, 4) = original_qd * (1 - applied_frac);
    [result, converged] = run_ac_powerflow(mpc_shed);
    if converged
        break;
    end
end

shed = struct();
shed.island_load_shed_mw = existing_shed_mw;
shed.corrective_load_shed_mw = base_load * applied_frac;
shed.load_shed_frac = applied_frac;
shed.load_shed_mw = existing_shed_mw + shed.corrective_load_shed_mw;
shed.total_load_shed_mw = shed.load_shed_mw;
shed.iterations = iter;
shed.converged_after_shed = converged;
end
