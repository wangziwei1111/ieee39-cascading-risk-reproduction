function [mpc_opf, shed_gen_rows, load_bus_rows, meta] = build_dispatchable_load_case(mpc_in, cfg, load_rows)
%BUILD_DISPATCHABLE_LOAD_CASE Build MATPOWER negative-generator load variables.
% 论文式 OLS 的变量 C_i 表示负荷削减量。这里不用正注入发电机直接代表
% C_i，而是把可削减负荷建成 MATPOWER dispatchable load（负发电机）：
% PG=-Pd 表示负荷全部保留，PG=0 表示负荷全部切除，因此 C_i=Pd+PG。
% 该函数只构造诊断 OPF 模型，不声称已经与原文式(3-19)至(3-26)完全一致。
arguments
    mpc_in struct
    cfg struct
    load_rows double
end

mpc_opf = mpc_in;
if get_cfg(cfg, 'paper_ols_relax_voltage_limits', false)
    mpc_opf.bus(:, 12) = max(mpc_opf.bus(:, 12), get_cfg(cfg, 'paper_ols_relaxed_voltage_max_pu', 1.15));
    mpc_opf.bus(:, 13) = min(mpc_opf.bus(:, 13), get_cfg(cfg, 'paper_ols_relaxed_voltage_min_pu', 0.85));
end
rate_factor = get_cfg(cfg, 'paper_ols_rate_limit_relax_factor', 1.0);
if rate_factor ~= 1.0
    positive_rate = mpc_opf.branch(:, 6) > 0;
    mpc_opf.branch(positive_rate, 6) = mpc_opf.branch(positive_rate, 6) * rate_factor;
end

load_bus_rows = load_rows(:);
num_load = numel(load_bus_rows);
num_gen0 = size(mpc_in.gen, 1);
num_gen_col = size(mpc_in.gen, 2);
new_gen = zeros(num_load, num_gen_col);
q_mode = lower(string(get_cfg(cfg, 'paper_ols_dispatchable_load_q_mode', 'variable_absorption')));
original_pd = mpc_in.bus(load_bus_rows, 3);
original_qd = mpc_in.bus(load_bus_rows, 4);

for k = 1:num_load
    bus_row = load_bus_rows(k);
    bus_id = mpc_in.bus(bus_row, 1);
    pd = mpc_in.bus(bus_row, 3);
    qd = mpc_in.bus(bus_row, 4);

    % 将可削减有功负荷从固定 PD 中移出，避免 OPF 中重复计入。
    mpc_opf.bus(bus_row, 3) = 0;
    switch q_mode
        case "p_only"
            % 只转移有功负荷，固定无功负荷仍留在 bus QD 中。
        case "variable_absorption"
            % 只将感性无功负荷转入负发电机吸收变量；若 Qd<=0，则保持为固定 QD，
            % 避免为了表示容性负荷而让 dispatchable load 提供正无功支撑。
            if qd > 0
                mpc_opf.bus(bus_row, 4) = 0;
            end
        case "constant_pf_after_apply"
            % OPF 只优化有功，应用阶段再按原功率因数削减 Q。
            mpc_opf.bus(bus_row, 4) = 0;
        otherwise
            error('Unsupported paper_ols_dispatchable_load_q_mode: %s', q_mode);
    end

    new_gen(k, 1) = bus_id;
    new_gen(k, 2) = -pd;       % PG=-Pd means all flexible load is served.
    new_gen(k, 3) = initial_dispatchable_q(qd, q_mode);
    switch q_mode
        case "variable_absorption"
            new_gen(k, 4) = 0;             % QMAX: no positive reactive injection.
            new_gen(k, 5) = -max(qd, 0);   % QMIN: may absorb inductive reactive power.
        case {"p_only", "constant_pf_after_apply"}
            new_gen(k, 4) = 0;
            new_gen(k, 5) = 0;
    end
    new_gen(k, 6) = max(mpc_in.bus(bus_row, 8), 1.0);
    new_gen(k, 7) = mpc_in.baseMVA;
    new_gen(k, 8) = 1;
    new_gen(k, 9) = 0;         % PMAX=0 means full shedding is allowed.
    new_gen(k, 10) = -pd;      % PMIN=-Pd means full load service is allowed.
end

mpc_opf.gen = [mpc_opf.gen; new_gen];
shed_gen_rows = (num_gen0 + 1):(num_gen0 + num_load);

if isfield(mpc_opf, 'gencost') && ~isempty(mpc_opf.gencost)
    cost_col = size(mpc_opf.gencost, 2);
else
    cost_col = 6;
end
gencost = zeros(num_gen0 + num_load, cost_col);
gencost(:, 1) = 2;
gencost(:, 4) = 2;
if cost_col >= 6
    gencost(1:num_gen0, 5) = get_cfg(cfg, 'paper_ols_generation_cost', 0.0);
    % 对负 PG 使用正线性成本：min c*PG 会优先让 PG 更负，即尽量保留负荷；
    % 只有网络/电压/发电约束需要时才将 PG 往 0 推动并形成切负荷。
    gencost(num_gen0 + 1:end, 5) = get_cfg(cfg, 'paper_ols_shed_cost', 1.0);
end
mpc_opf.gencost = gencost;

meta = struct();
meta.formulation = "dispatchable_load";
meta.q_mode = q_mode;
meta.original_pd = original_pd;
meta.original_qd = original_qd;
meta.sign_convention = "PG=-Pd served, PG=0 shed, shed_P=Pd+PG";
end

function q0 = initial_dispatchable_q(qd, q_mode)
switch q_mode
    case "variable_absorption"
        q0 = -max(qd, 0);
    otherwise
        q0 = 0;
end
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
