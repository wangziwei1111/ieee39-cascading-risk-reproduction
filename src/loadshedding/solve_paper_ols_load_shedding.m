function [mpc_shed, pf_result, shed, ols_detail] = solve_paper_ols_load_shedding(mpc_in, cfg, cumulative_load_shed_mw)
%SOLVE_PAPER_OLS_LOAD_SHEDDING 求解论文式最优负荷削减的工程接口。
% 输入：
%   mpc_in - 故障后、孤岛标准化后的 MATPOWER 算例。
%   cfg - 全局配置，包含 OLS 求解器、切负荷成本和失败策略。
%   cumulative_load_shed_mw - 前序孤岛解列和切负荷累计损失，MW。
% 输出：
%   mpc_shed - 应用 OLS 切负荷后的算例。
%   pf_result - 对 mpc_shed 重新潮流校验的结果。
%   shed - 与 simple_load_shedding 兼容的切负荷汇总结构。
%   ols_detail - OLS 求解诊断，含逐节点切负荷表。
% 物理含义：
%   对应论文式(3-19)至式(3-26)的“最小总切负荷”思想。本实现使用 MATPOWER
%   AC OPF 和等效可调正注入发电机表示负荷削减变量 C_i，并保留发电机上下限、
%   线路 RATE_A 容量约束和节点电压上下限。该接口仍需原文参数进一步校准。

arguments
    mpc_in struct
    cfg struct
    cumulative_load_shed_mw double = 0
end

base_load_mw = sum(mpc_in.bus(:, 3)) + cumulative_load_shed_mw;
ols_detail = init_detail(cfg, cumulative_load_shed_mw);
mpc_shed = mpc_in;
pf_result = struct('success', false);
shed = init_shed(cumulative_load_shed_mw, base_load_mw, false);

load_rows = find(mpc_in.bus(:, 3) > 1e-9);
if isempty(load_rows)
    [pf_result, pf_success] = run_ac_powerflow(mpc_in);
    ols_detail.status = "no_load_to_shed";
    ols_detail.opf_success = true;
    ols_detail.pf_success_after_apply = pf_success;
    ols_detail.converged_after_shed = pf_success;
    ols_detail.message = "无可削减负荷节点，仅重新校验潮流。";
    shed.converged_after_shed = pf_success;
    return;
end

try
    [mpc_opf, shed_gen_rows, load_bus_rows] = build_dispatchable_shed_case(mpc_in, cfg, load_rows);
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    opf_result = runopf(mpc_opf, mpopt);
    opf_success = isfield(opf_result, 'success') && opf_result.success == 1;
catch ME
    opf_result = struct();
    opf_success = false;
    ols_detail.message = "OPF调用失败：" + string(ME.message);
end

ols_detail.opf_success = opf_success;

if opf_success
    shed_p = max(opf_result.gen(shed_gen_rows, 2), 0);
    original_pd = mpc_in.bus(load_bus_rows, 3);
    original_qd = mpc_in.bus(load_bus_rows, 4);
    shed_p = min(shed_p, original_pd);

    switch lower(string(get_cfg(cfg, 'paper_ols_q_shed_mode', 'constant_power_factor')))
        case "constant_power_factor"
            q_ratio = zeros(size(original_qd));
            positive_p = abs(original_pd) > 1e-9;
            q_ratio(positive_p) = original_qd(positive_p) ./ original_pd(positive_p);
            shed_q = shed_p .* q_ratio;
            shed_q = min(max(shed_q, min(original_qd, 0)), max(original_qd, 0));
        otherwise
            shed_q = zeros(size(shed_p));
    end

    mpc_shed.bus(load_bus_rows, 3) = max(original_pd - shed_p, 0);
    mpc_shed.bus(load_bus_rows, 4) = original_qd - shed_q;
    [pf_result, pf_success] = run_ac_powerflow(mpc_shed);

    corrective_load_shed_mw = sum(shed_p);
    shed = build_shed(cumulative_load_shed_mw, corrective_load_shed_mw, base_load_mw, pf_success);
    ols_detail.objective_load_shed_mw = corrective_load_shed_mw;
    ols_detail.corrective_load_shed_mw = corrective_load_shed_mw;
    ols_detail.total_load_shed_mw = shed.total_load_shed_mw;
    ols_detail.pf_success_after_apply = pf_success;
    ols_detail.converged_after_shed = pf_success;
    ols_detail.num_shed_buses = sum(shed_p > 1e-7);
    ols_detail.max_bus_shed_mw = max([shed_p; 0]);
    ols_detail.bus_shed_table = build_bus_shed_table(mpc_in.bus(load_bus_rows, 1), original_pd, original_qd, shed_p, shed_q);

    if pf_success
        ols_detail.status = "success";
        ols_detail.message = "OLS求解成功，应用切负荷后潮流收敛。";
        return;
    end

    ols_detail.status = "failed_pf_after_apply";
    ols_detail.message = "OLS OPF成功，但应用切负荷后AC潮流仍不收敛。";
else
    ols_detail.status = "failed_opf";
    if strlength(string(ols_detail.message)) == 0
        ols_detail.message = "OLS OPF未收敛。";
    end
end

fail_policy = lower(string(get_cfg(cfg, 'paper_ols_fail_policy', 'fallback_to_simple_with_warning')));
if fail_policy == "fallback_to_simple_with_warning"
    [mpc_shed, pf_result, shed] = simple_load_shedding(mpc_in, cfg, cumulative_load_shed_mw);
    ols_detail.status = "fallback_to_simple";
    ols_detail.total_load_shed_mw = shed.total_load_shed_mw;
    ols_detail.corrective_load_shed_mw = shed.corrective_load_shed_mw;
    ols_detail.converged_after_shed = shed.converged_after_shed;
    ols_detail.pf_success_after_apply = shed.converged_after_shed;
    ols_detail.message = ols_detail.message + " 已按配置回退到simple_load_shedding。";
elseif fail_policy == "strict_error"
    error('paper_ols_load_shedding:failed', '%s', char(ols_detail.message));
end
end

function [mpc_opf, shed_gen_rows, load_bus_rows] = build_dispatchable_shed_case(mpc_in, cfg, load_rows)
%BUILD_DISPATCHABLE_SHED_CASE 将每个负荷节点的C_i表示为可调正注入。
mpc_opf = mpc_in;
load_bus_rows = load_rows(:);
num_shed = numel(load_bus_rows);
num_gen0 = size(mpc_in.gen, 1);
num_gen_col = size(mpc_in.gen, 2);
new_gen = zeros(num_shed, num_gen_col);

for k = 1:num_shed
    bus_row = load_bus_rows(k);
    bus_id = mpc_in.bus(bus_row, 1);
    pd = mpc_in.bus(bus_row, 3);
    qd = mpc_in.bus(bus_row, 4);
    new_gen(k, 1) = bus_id;                       % GEN_BUS
    new_gen(k, 2) = 0;                            % PG
    new_gen(k, 3) = 0;                            % QG
    new_gen(k, 4) = max(abs(qd), 0);              % QMAX
    new_gen(k, 5) = -max(abs(qd), 0);             % QMIN
    new_gen(k, 6) = max(mpc_in.bus(bus_row, 8), 1.0); % VG
    new_gen(k, 7) = mpc_in.baseMVA;               % MBASE
    new_gen(k, 8) = 1;                            % GEN_STATUS
    new_gen(k, 9) = pd;                           % PMAX = C_i上限
    new_gen(k, 10) = 0;                           % PMIN = 0
end

mpc_opf.gen = [mpc_opf.gen; new_gen];
shed_gen_rows = (num_gen0 + 1):(num_gen0 + num_shed);

if isfield(mpc_opf, 'gencost') && ~isempty(mpc_opf.gencost)
    cost_col = size(mpc_opf.gencost, 2);
else
    cost_col = 6;
end
gencost = zeros(num_gen0 + num_shed, cost_col);
gencost(:, 1) = 2; % polynomial cost
gencost(:, 4) = 2; % ncost
if cost_col >= 6
    gencost(1:num_gen0, 5) = get_cfg(cfg, 'paper_ols_generation_cost', 0.0);
    gencost(num_gen0 + 1:end, 5) = get_cfg(cfg, 'paper_ols_shed_cost', 1.0);
end
mpc_opf.gencost = gencost;
end

function tbl = build_bus_shed_table(bus_id, original_pd, original_qd, shed_p, shed_q)
%BUILD_BUS_SHED_TABLE 记录每个负荷节点的最优削减量。
remaining_pd = max(original_pd - shed_p, 0);
remaining_qd = original_qd - shed_q;
shed_fraction = zeros(size(original_pd));
positive = original_pd > 1e-9;
shed_fraction(positive) = shed_p(positive) ./ original_pd(positive);
tbl = table(bus_id(:), original_pd(:), original_qd(:), shed_p(:), shed_q(:), ...
    remaining_pd(:), remaining_qd(:), shed_fraction(:), ...
    'VariableNames', {'bus_id', 'original_Pd', 'original_Qd', 'shed_P', 'shed_Q', ...
    'remaining_Pd', 'remaining_Qd', 'shed_fraction'});
end

function detail = init_detail(cfg, cumulative_load_shed_mw)
detail = struct();
detail.mode = "paper_ols";
detail.status = "not_started";
detail.solver = string(get_cfg(cfg, 'paper_ols_solver', 'matpower_opf_dispatchable_shed'));
detail.objective_load_shed_mw = NaN;
detail.total_load_shed_mw = cumulative_load_shed_mw;
detail.corrective_load_shed_mw = NaN;
detail.island_load_shed_mw = cumulative_load_shed_mw;
detail.converged_after_shed = false;
detail.opf_success = false;
detail.pf_success_after_apply = false;
detail.num_shed_buses = 0;
detail.max_bus_shed_mw = 0;
detail.message = "";
detail.bus_shed_table = table();
end

function shed = init_shed(cumulative_load_shed_mw, base_load_mw, converged)
shed = build_shed(cumulative_load_shed_mw, 0, base_load_mw, converged);
end

function shed = build_shed(cumulative_load_shed_mw, corrective_load_shed_mw, base_load_mw, converged)
shed = struct();
shed.island_load_shed_mw = cumulative_load_shed_mw;
shed.corrective_load_shed_mw = corrective_load_shed_mw;
shed.load_shed_mw = cumulative_load_shed_mw + corrective_load_shed_mw;
shed.total_load_shed_mw = cumulative_load_shed_mw + corrective_load_shed_mw;
if base_load_mw > 0
    shed.load_shed_frac = corrective_load_shed_mw / base_load_mw;
else
    shed.load_shed_frac = 0;
end
shed.iterations = 1;
shed.converged_after_shed = logical(converged);
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
