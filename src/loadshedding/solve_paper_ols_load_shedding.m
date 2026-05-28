function [mpc_shed, pf_result, shed, ols_detail] = solve_paper_ols_load_shedding(mpc_in, cfg, cumulative_load_shed_mw)
%SOLVE_PAPER_OLS_LOAD_SHEDDING Solve the paper-style OLS load shedding model.
% The implementation maps thesis equations (3-19) to (3-26) to a MATPOWER
% AC OPF with dispatchable positive injections at load buses. It is an
% engineering interface for diagnosis and still requires thesis parameter
% calibration before final reproduction use.
arguments
    mpc_in struct
    cfg struct
    cumulative_load_shed_mw double = 0
end

base_load_mw = sum(mpc_in.bus(:, 3)) + cumulative_load_shed_mw;
ols_detail = init_detail(cfg, cumulative_load_shed_mw);
ols_detail.num_zero_rateA_lines = sum(mpc_in.branch(:, 6) <= 0);
ols_detail.has_slack_online = has_online_slack(mpc_in);
mpc_shed = mpc_in;
pf_result = struct('success', false);
shed = init_shed(cumulative_load_shed_mw, base_load_mw, false);

load_rows = find(mpc_in.bus(:, 3) > 1e-9);
if isempty(load_rows)
    [pf_result, pf_success] = run_ac_powerflow(mpc_in);
    ols_detail.status = "no_load_to_shed";
    ols_detail.opf_success = true;
    ols_detail.opf_raw_success = true;
    ols_detail.pf_success_after_apply = pf_success;
    ols_detail.converged_after_shed = pf_success;
    ols_detail.message = "No load bus is available for shedding; PF was checked only.";
    shed.converged_after_shed = pf_success;
    return;
end

try
    [mpc_opf, shed_gen_rows, load_bus_rows] = build_dispatchable_shed_case(mpc_in, cfg, load_rows);
    mpopt = mpoption('verbose', 0, 'out.all', 0);
    opf_alg = string(get_cfg(cfg, 'paper_ols_opf_alg', 'DEFAULT'));
    ols_detail.mpopt_algorithm = opf_alg;
    if upper(opf_alg) ~= "DEFAULT"
        mpopt = mpoption(mpopt, 'opf.ac.solver', char(opf_alg));
    end
    opf_result = runopf(mpc_opf, mpopt);
    opf_success = isfield(opf_result, 'success') && opf_result.success == 1;
    ols_detail.opf_raw_success = opf_success;
    ols_detail.opf_objective = get_struct_field(opf_result, 'f', NaN);
    ols_detail.opf_message = extract_opf_message(opf_result);
catch ME
    opf_result = struct();
    opf_success = false;
    ols_detail.message = "OPF call failed: " + string(ME.message);
    ols_detail.opf_raw_success = false;
    ols_detail.opf_objective = NaN;
    ols_detail.opf_message = string(ME.message);
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
    ols_detail.num_binding_generators = count_binding_generators(opf_result);
    ols_detail.bus_shed_table = build_bus_shed_table( ...
        mpc_in.bus(load_bus_rows, 1), original_pd, original_qd, shed_p, shed_q);

    if pf_success
        ols_detail.status = "success";
        ols_detail.message = "OLS solved and AC PF converged after applying load shedding.";
    else
        ols_detail.status = "failed";
        ols_detail.message = "OLS OPF succeeded, but AC PF did not converge after applying load shedding.";
    end
else
    ols_detail.status = "failed";
    if strlength(string(ols_detail.message)) == 0
        ols_detail.message = "OLS OPF did not converge.";
    end
end

failure_info = diagnose_ols_failure(mpc_in, [], ols_detail, struct(), cfg);
ols_detail.diagnosis_failure_type = failure_info.failure_type;
ols_detail.diagnosis_likely_cause = failure_info.likely_cause;
end

function [mpc_opf, shed_gen_rows, load_bus_rows] = build_dispatchable_shed_case(mpc_in, cfg, load_rows)
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
num_shed = numel(load_bus_rows);
num_gen0 = size(mpc_in.gen, 1);
num_gen_col = size(mpc_in.gen, 2);
new_gen = zeros(num_shed, num_gen_col);

for k = 1:num_shed
    bus_row = load_bus_rows(k);
    bus_id = mpc_in.bus(bus_row, 1);
    pd = mpc_in.bus(bus_row, 3);
    qd = mpc_in.bus(bus_row, 4);
    new_gen(k, 1) = bus_id;
    new_gen(k, 2) = 0;
    new_gen(k, 3) = 0;
    new_gen(k, 4) = max(abs(qd), 0);
    new_gen(k, 5) = -max(abs(qd), 0);
    new_gen(k, 6) = max(mpc_in.bus(bus_row, 8), 1.0);
    new_gen(k, 7) = mpc_in.baseMVA;
    new_gen(k, 8) = 1;
    new_gen(k, 9) = pd;
    new_gen(k, 10) = 0;
end

mpc_opf.gen = [mpc_opf.gen; new_gen];
shed_gen_rows = (num_gen0 + 1):(num_gen0 + num_shed);

if isfield(mpc_opf, 'gencost') && ~isempty(mpc_opf.gencost)
    cost_col = size(mpc_opf.gencost, 2);
else
    cost_col = 6;
end
gencost = zeros(num_gen0 + num_shed, cost_col);
gencost(:, 1) = 2;
gencost(:, 4) = 2;
if cost_col >= 6
    gencost(1:num_gen0, 5) = get_cfg(cfg, 'paper_ols_generation_cost', 0.0);
    gencost(num_gen0 + 1:end, 5) = get_cfg(cfg, 'paper_ols_shed_cost', 1.0);
end
mpc_opf.gencost = gencost;
end

function tbl = build_bus_shed_table(bus_id, original_pd, original_qd, shed_p, shed_q)
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
detail.mpopt_algorithm = string(get_cfg(cfg, 'paper_ols_opf_alg', 'DEFAULT'));
detail.opf_raw_success = false;
detail.opf_objective = NaN;
detail.opf_message = "";
detail.num_zero_rateA_lines = NaN;
detail.num_binding_generators = NaN;
detail.has_slack_online = false;
detail.diagnosis_failure_type = "unknown";
detail.diagnosis_likely_cause = "";
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
    shed.load_shed_frac = shed.total_load_shed_mw / base_load_mw;
    shed.corrective_load_shed_frac = corrective_load_shed_mw / base_load_mw;
else
    shed.load_shed_frac = 0;
    shed.corrective_load_shed_frac = 0;
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

function value = get_struct_field(s, field_name, default_value)
if isstruct(s) && isfield(s, field_name)
    value = s.(field_name);
else
    value = default_value;
end
end

function message = extract_opf_message(opf_result)
message = "";
if isfield(opf_result, 'raw') && isfield(opf_result.raw, 'output') && ...
        isfield(opf_result.raw.output, 'message')
    message = string(opf_result.raw.output.message);
elseif isfield(opf_result, 'output') && isfield(opf_result.output, 'message')
    message = string(opf_result.output.message);
end
end

function count = count_binding_generators(opf_result)
count = NaN;
if ~isfield(opf_result, 'gen') || isempty(opf_result.gen)
    return;
end
gen = opf_result.gen;
tol = 1e-5;
pg_bind = abs(gen(:, 2) - gen(:, 9)) <= tol | abs(gen(:, 2) - gen(:, 10)) <= tol;
qg_bind = abs(gen(:, 3) - gen(:, 4)) <= tol | abs(gen(:, 3) - gen(:, 5)) <= tol;
count = sum(pg_bind | qg_bind);
end

function tf = has_online_slack(mpc)
slack_buses = mpc.bus(mpc.bus(:, 2) == 3, 1);
if isempty(slack_buses)
    tf = false;
    return;
end
online_gen_buses = mpc.gen(mpc.gen(:, 8) > 0, 1);
tf = any(ismember(slack_buses, online_gen_buses));
end
