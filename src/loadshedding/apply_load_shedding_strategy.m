function [mpc_current, pf_result, shed, shed_detail] = apply_load_shedding_strategy(mpc_current, cfg, cumulative_load_shed_mw)
%APPLY_LOAD_SHEDDING_STRATEGY 统一调度 simple 与 paper_ols 切负荷策略。
% 输入：
%   mpc_current - 当前故障阶段、潮流不收敛的 MATPOWER 算例。
%   cfg - 全局配置，cfg.load_shedding_mode 控制策略。
%   cumulative_load_shed_mw - 已累计负荷损失，MW。
% 输出：
%   mpc_current - 切负荷后的算例。
%   pf_result - 切负荷后的潮流结果。
%   shed - 与原 simple_load_shedding 兼容的切负荷汇总。
%   shed_detail - 诊断结构，记录 OLS 成败、回退和对比信息。
% 物理含义：
%   simple 保持原工程简化流程；paper_ols 对应论文最小切负荷思想；both_diagnostic
%   只在同一输入上额外求解 OLS，不改变主事故链。

if isfield(cfg, 'load_shedding_mode')
    mode = lower(string(cfg.load_shedding_mode));
else
    mode = "simple";
end

switch mode
    case "simple"
        [mpc_current, pf_result, shed] = simple_load_shedding( ...
            mpc_current, cfg, cumulative_load_shed_mw);
        shed_detail = simple_detail(shed);

    case "paper_ols"
        if isfield(cfg, 'paper_ols_enable') && ~cfg.paper_ols_enable
            error('paper_ols requested but cfg.paper_ols_enable=false。');
        end
        [mpc_current, pf_result, shed, shed_detail] = solve_paper_ols_load_shedding( ...
            mpc_current, cfg, cumulative_load_shed_mw);

    case "both_diagnostic"
        input_mpc = mpc_current;
        [mpc_simple, pf_simple, shed_simple] = simple_load_shedding( ...
            input_mpc, cfg, cumulative_load_shed_mw);
        [~, ~, ~, ols_detail] = solve_paper_ols_load_shedding( ...
            input_mpc, cfg, cumulative_load_shed_mw);
        mpc_current = mpc_simple;
        pf_result = pf_simple;
        shed = shed_simple;
        shed_detail = struct();
        shed_detail.mode = "both_diagnostic";
        shed_detail.status = "simple_returned_with_ols_diagnostic";
        shed_detail.simple_detail = simple_detail(shed_simple);
        shed_detail.paper_ols_detail = ols_detail;
        shed_detail.message = "主链路返回simple_load_shedding结果；OLS仅用于诊断记录。";

    otherwise
        error('未知 load_shedding_mode：%s', mode);
end
end

function detail = simple_detail(shed)
detail = struct();
detail.mode = "simple";
detail.status = "simple_applied";
detail.solver = "simple_load_shedding";
detail.objective_load_shed_mw = shed.corrective_load_shed_mw;
detail.total_load_shed_mw = shed.total_load_shed_mw;
detail.corrective_load_shed_mw = shed.corrective_load_shed_mw;
detail.island_load_shed_mw = shed.island_load_shed_mw;
detail.converged_after_shed = shed.converged_after_shed;
detail.opf_success = NaN;
detail.pf_success_after_apply = shed.converged_after_shed;
detail.num_shed_buses = NaN;
detail.max_bus_shed_mw = NaN;
detail.message = "使用原simple_load_shedding工程简化切负荷。";
detail.bus_shed_table = table();
end
