function [mpc_preshed, dc_detail] = solve_dc_ols_preshed(mpc_in, cfg)
%SOLVE_DC_OLS_PRESHED Diagnostic DC-OLS preshed for AC-OLS warm-start tests.
% 该函数只做 DC 线性近似下的最小有功切负荷预处理，用于判断
% dispatchable_load AC-OLS 的剩余失败是否可能通过 DC->AC 两阶段流程改善。
% 它不是论文最终 AC-OLS，也不应直接写入正式 benchmark。
arguments
    mpc_in struct
    cfg struct
end

mpc_preshed = mpc_in;
dc_detail = init_detail();
if exist('linprog', 'file') ~= 2
    dc_detail.status = "unavailable";
    dc_detail.message = "linprog unavailable; DC-OLS preshed not run.";
    return;
end

bus_ids = mpc_in.bus(:, 1);
nb = numel(bus_ids);
online_gen = find(mpc_in.gen(:, 8) > 0);
ng = numel(online_gen);
load_rows = find(mpc_in.bus(:, 3) > 1e-9);
nl = numel(load_rows);
if ng == 0 || nl == 0
    dc_detail.status = "failed";
    dc_detail.message = "No online generator or no positive load for DC-OLS preshed.";
    return;
end

branch_on = find(mpc_in.branch(:, 11) > 0 & abs(mpc_in.branch(:, 4)) > 1e-9);
B = zeros(nb, nb);
flow_rows = [];
for k = 1:numel(branch_on)
    br = branch_on(k);
    f = find(bus_ids == mpc_in.branch(br, 1), 1);
    t = find(bus_ids == mpc_in.branch(br, 2), 1);
    if isempty(f) || isempty(t), continue; end
    b = 1 / mpc_in.branch(br, 4);
    B(f, f) = B(f, f) + b;
    B(t, t) = B(t, t) + b;
    B(f, t) = B(f, t) - b;
    B(t, f) = B(t, f) - b;
    flow_rows(end + 1) = br; %#ok<AGROW>
end

nvar = nb + ng + nl;
theta_idx = 1:nb;
pg_idx = nb + (1:ng);
shed_idx = nb + ng + (1:nl);
f_obj = zeros(nvar, 1);
f_obj(shed_idx) = 1;

Aeq = zeros(nb, nvar);
beq = mpc_in.bus(:, 3);
Aeq(:, theta_idx) = -mpc_in.baseMVA * B;
for g = 1:ng
    bus_pos = find(bus_ids == mpc_in.gen(online_gen(g), 1), 1);
    Aeq(bus_pos, pg_idx(g)) = 1;
end
for l = 1:nl
    Aeq(load_rows(l), shed_idx(l)) = 1;
end

A = [];
b = [];
for k = 1:numel(flow_rows)
    br = flow_rows(k);
    fbus = find(bus_ids == mpc_in.branch(br, 1), 1);
    tbus = find(bus_ids == mpc_in.branch(br, 2), 1);
    rate = mpc_in.branch(br, 6);
    if rate <= 0
        rate = 1e4;
    end
    coeff = zeros(1, nvar);
    coeff(fbus) = mpc_in.baseMVA / mpc_in.branch(br, 4);
    coeff(tbus) = -mpc_in.baseMVA / mpc_in.branch(br, 4);
    A = [A; coeff; -coeff]; %#ok<AGROW>
    b = [b; rate; rate]; %#ok<AGROW>
end

lb = -pi * ones(nvar, 1);
ub = pi * ones(nvar, 1);
slack = find(mpc_in.bus(:, 2) == 3, 1);
if isempty(slack), slack = 1; end
lb(slack) = 0; ub(slack) = 0;
for g = 1:ng
    lb(pg_idx(g)) = mpc_in.gen(online_gen(g), 10);
    ub(pg_idx(g)) = mpc_in.gen(online_gen(g), 9);
end
for l = 1:nl
    lb(shed_idx(l)) = 0;
    ub(shed_idx(l)) = mpc_in.bus(load_rows(l), 3);
end

try
    opts = optimoptions('linprog', 'Display', 'none');
    [x, objective, exitflag, output] = linprog(f_obj, A, b, Aeq, beq, lb, ub, opts);
    dc_detail.lp_exitflag = exitflag;
    if isstruct(output) && isfield(output, 'message')
        dc_detail.message = string(output.message);
    end
catch ME
    dc_detail.status = "failed";
    dc_detail.message = "DC-OLS linprog failed: " + string(ME.message);
    return;
end

if exitflag <= 0
    dc_detail.status = "failed";
    dc_detail.lp_success = false;
    if strlength(dc_detail.message) == 0
        dc_detail.message = "DC-OLS LP did not find a feasible solution.";
    end
    return;
end

shed_p = x(shed_idx) * get_cfg(cfg, 'paper_ols_dc_preshed_safety_factor', 1.0);
original_pd = mpc_in.bus(load_rows, 3);
original_qd = mpc_in.bus(load_rows, 4);
shed_p = min(max(shed_p, 0), original_pd);
shed_q = compute_preshed_q(original_pd, original_qd, shed_p, cfg);
mpc_preshed.bus(load_rows, 3) = max(original_pd - shed_p, 0);
mpc_preshed.bus(load_rows, 4) = original_qd - shed_q;

dc_detail.status = "success";
dc_detail.lp_success = true;
dc_detail.objective_load_shed_mw = sum(shed_p);
dc_detail.num_shed_buses = sum(shed_p > 1e-7);
dc_detail.max_bus_shed_mw = max([shed_p; 0]);
dc_detail.max_dc_line_loading_after = compute_dc_max_loading(mpc_in, x(theta_idx), flow_rows);
dc_detail.message = "DC-OLS preshed found a linear feasible shed pattern; diagnostic only.";
dc_detail.bus_shed_table = build_bus_shed_table(mpc_in.bus(load_rows, 1), original_pd, original_qd, shed_p, shed_q);
dc_detail.raw_lp_objective = objective;
end

function detail = init_detail()
detail = struct();
detail.status = "not_started";
detail.lp_success = false;
detail.lp_exitflag = NaN;
detail.objective_load_shed_mw = NaN;
detail.num_shed_buses = 0;
detail.max_bus_shed_mw = 0;
detail.max_dc_line_loading_after = NaN;
detail.message = "";
detail.bus_shed_table = table();
detail.raw_lp_objective = NaN;
end

function shed_q = compute_preshed_q(original_pd, original_qd, shed_p, cfg)
switch lower(string(get_cfg(cfg, 'paper_ols_dc_preshed_apply_q_mode', 'constant_power_factor')))
    case "constant_power_factor"
        q_ratio = zeros(size(original_qd));
        positive_p = abs(original_pd) > 1e-9;
        q_ratio(positive_p) = original_qd(positive_p) ./ original_pd(positive_p);
        shed_q = shed_p .* q_ratio;
        shed_q = min(max(shed_q, min(original_qd, 0)), max(original_qd, 0));
    case "p_only"
        shed_q = zeros(size(shed_p));
    otherwise
        error('Unsupported paper_ols_dc_preshed_apply_q_mode.');
end
end

function max_loading = compute_dc_max_loading(mpc, theta, flow_rows)
loading = nan(numel(flow_rows), 1);
bus_ids = mpc.bus(:, 1);
for k = 1:numel(flow_rows)
    br = flow_rows(k);
    f = find(bus_ids == mpc.branch(br, 1), 1);
    t = find(bus_ids == mpc.branch(br, 2), 1);
    rate = mpc.branch(br, 6);
    if rate <= 0, continue; end
    flow = abs(mpc.baseMVA * (theta(f) - theta(t)) / mpc.branch(br, 4));
    loading(k) = flow / rate;
end
max_loading = max(loading, [], 'omitnan');
end

function tbl = build_bus_shed_table(bus_id, original_pd, original_qd, shed_p, shed_q)
remaining_pd = max(original_pd - shed_p, 0);
remaining_qd = original_qd - shed_q;
shed_fraction = zeros(size(original_pd));
positive = original_pd > 1e-9;
shed_fraction(positive) = shed_p(positive) ./ original_pd(positive);
tbl = table(bus_id(:), original_pd(:), original_qd(:), shed_p(:), shed_q(:), ...
    remaining_pd(:), remaining_qd(:), shed_fraction(:), ...
    'VariableNames', {'bus_id', 'original_Pd', 'original_Qd', 'shed_P', ...
    'shed_Q', 'remaining_Pd', 'remaining_Qd', 'shed_fraction'});
end

function value = get_cfg(cfg, field_name, default_value)
if isfield(cfg, field_name)
    value = cfg.(field_name);
else
    value = default_value;
end
end
