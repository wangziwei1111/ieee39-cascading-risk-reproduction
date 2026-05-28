function main_test_dc_ols_feasibility_preview()
%MAIN_TEST_DC_OLS_FEASIBILITY_PREVIEW Run diagnostic DC-OLS LP on exported failures.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
index_path = fullfile(table_dir, 'ols_failure_case_index.csv');
must_exist(index_path);
index = readtable(index_path);

rows = {};
if exist('linprog', 'file') ~= 2
    for i = 1:height(index)
        rows{end + 1, 1} = table(string(index.case_export_id(i)), false, NaN, NaN, ...
            string(index.failure_type(i)), "linprog unavailable; DC-OLS preview not run.", ...
            'VariableNames', {'case_export_id', 'dc_lp_success', ...
            'dc_objective_load_shed_mw', 'max_dc_line_loading_after', ...
            'ac_ols_failure_type', 'interpretation'}); %#ok<AGROW>
    end
else
    for i = 1:height(index)
        before = load(fullfile(string(index.case_dir(i)), 'mpc_before_ols.mat'), 'mpc_before');
        [success, objective, max_loading, note] = solve_dc_preview(before.mpc_before);
        rows{end + 1, 1} = table(string(index.case_export_id(i)), success, objective, ...
            max_loading, string(index.failure_type(i)), string(note), ...
            'VariableNames', {'case_export_id', 'dc_lp_success', ...
            'dc_objective_load_shed_mw', 'max_dc_line_loading_after', ...
            'ac_ols_failure_type', 'interpretation'}); %#ok<AGROW>
    end
end

if isempty(rows)
    preview = table(strings(0, 1), false(0, 1), zeros(0, 1), zeros(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'case_export_id', 'dc_lp_success', ...
        'dc_objective_load_shed_mw', 'max_dc_line_loading_after', ...
        'ac_ols_failure_type', 'interpretation'});
else
    preview = vertcat(rows{:});
end
writetable(preview, fullfile(table_dir, 'dc_ols_feasibility_preview.csv'));
plot_ols_benchmark_smoke_figures(root_dir);
fprintf('DC-OLS feasibility preview written: %s\n', fullfile(table_dir, 'dc_ols_feasibility_preview.csv'));
end

function [success, objective, max_loading, note] = solve_dc_preview(mpc)
success = false;
objective = NaN;
max_loading = NaN;
note = "not_run";
bus_ids = mpc.bus(:, 1);
nb = numel(bus_ids);
online_gen = find(mpc.gen(:, 8) > 0);
ng = numel(online_gen);
load_rows = find(mpc.bus(:, 3) > 1e-9);
nl = numel(load_rows);
if ng == 0
    note = "No online generator; DC-OLS infeasible by construction.";
    return;
end

branch_on = find(mpc.branch(:, 11) > 0 & abs(mpc.branch(:, 4)) > 1e-9);
B = zeros(nb, nb);
flow_rows = [];
for k = 1:numel(branch_on)
    br = branch_on(k);
    f = find(bus_ids == mpc.branch(br, 1), 1);
    t = find(bus_ids == mpc.branch(br, 2), 1);
    if isempty(f) || isempty(t), continue; end
    b = 1 / mpc.branch(br, 4);
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
f = zeros(nvar, 1);
f(shed_idx) = 1;

Aeq = zeros(nb, nvar);
beq = mpc.bus(:, 3);
Aeq(:, theta_idx) = -mpc.baseMVA * B;
for g = 1:ng
    bus_pos = find(bus_ids == mpc.gen(online_gen(g), 1), 1);
    Aeq(bus_pos, pg_idx(g)) = 1;
end
for l = 1:nl
    Aeq(load_rows(l), shed_idx(l)) = 1;
end

A = [];
b = [];
for k = 1:numel(flow_rows)
    br = flow_rows(k);
    fbus = find(bus_ids == mpc.branch(br, 1), 1);
    tbus = find(bus_ids == mpc.branch(br, 2), 1);
    rate = mpc.branch(br, 6);
    if rate <= 0
        rate = 1e4;
    end
    coeff = zeros(1, nvar);
    coeff(fbus) = mpc.baseMVA / mpc.branch(br, 4);
    coeff(tbus) = -mpc.baseMVA / mpc.branch(br, 4);
    A = [A; coeff; -coeff]; %#ok<AGROW>
    b = [b; rate; rate]; %#ok<AGROW>
end

lb = -pi * ones(nvar, 1);
ub = pi * ones(nvar, 1);
slack = find(mpc.bus(:, 2) == 3, 1);
if isempty(slack), slack = 1; end
lb(slack) = 0; ub(slack) = 0;
for g = 1:ng
    lb(pg_idx(g)) = mpc.gen(online_gen(g), 10);
    ub(pg_idx(g)) = mpc.gen(online_gen(g), 9);
end
for l = 1:nl
    lb(shed_idx(l)) = 0;
    ub(shed_idx(l)) = mpc.bus(load_rows(l), 3);
end

try
    opts = optimoptions('linprog', 'Display', 'none');
    [x, objective, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, opts);
    success = exitflag > 0;
    if success
        max_loading = compute_dc_max_loading(mpc, x(theta_idx), flow_rows);
        note = "DC-OLS LP found a linear feasible shed pattern; diagnostic only.";
    else
        note = "DC-OLS LP did not find a feasible solution.";
    end
catch ME
    success = false;
    note = "DC-OLS LP failed: " + string(ME.message);
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

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end
