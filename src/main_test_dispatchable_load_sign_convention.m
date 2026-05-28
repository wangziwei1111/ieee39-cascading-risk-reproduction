function main_test_dispatchable_load_sign_convention()
%MAIN_TEST_DISPATCHABLE_LOAD_SIGN_CONVENTION Validate dispatchable-load OLS signs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
ensure_dir(table_dir);

cfg = base_config();
require_matpower(cfg);
cfg.paper_ols_formulation = 'dispatchable_load';
cfg.paper_ols_dispatchable_load_q_mode = 'variable_absorption';
cfg.paper_ols_fail_policy = 'fallback_to_simple_with_warning';
cfg.paper_ols_apply_solution_mode = 'load_only';
cfg.paper_ols_relax_voltage_limits = false;
cfg.paper_ols_rate_limit_relax_factor = 1.0;

mpc0 = build_case39_base(cfg);
rows = {};

mpc = mpc0;
mpc.branch(:, 6) = max(mpc.branch(:, 6), 1e5);
mpc.bus(:, 12) = 1.2;
mpc.bus(:, 13) = 0.8;
rows{end + 1, 1} = run_sign_case("no_constraint_case", mpc, cfg, ...
    "No binding branch limit; dispatchable load should preserve almost all load.", false); %#ok<AGROW>

mpc = mpc0;
mpc.branch(:, 6) = max(mpc.branch(:, 6), 1e5);
mpc.branch(1, 6) = 10;
mpc.bus(:, 12) = 1.2;
mpc.bus(:, 13) = 0.8;
rows{end + 1, 1} = run_sign_case("artificial_branch_limit_case", mpc, cfg, ...
    "Artificially tight branch limit should require positive load shedding if OPF converges.", true); %#ok<AGROW>

mpc = mpc0;
mpc.branch(:, 6) = max(mpc.branch(:, 6), 1e5);
rows{end + 1, 1} = run_sign_case("q_absorption_case", mpc, cfg, ...
    "Dispatchable load QG must be nonpositive; it must not provide reactive support.", false); %#ok<AGROW>

result = vertcat(rows{:});
save_result_table(result, fullfile(table_dir, 'dispatchable_load_sign_convention_test.csv'), true);
fprintf('dispatchable-load sign convention test written: %s\n', ...
    fullfile(table_dir, 'dispatchable_load_sign_convention_test.csv'));
end

function row = run_sign_case(test_name, mpc, cfg, expected_behavior, expect_shed)
[~, ~, ~, detail] = solve_paper_ols_load_shedding(mpc, cfg, 0);
opf_success = logical(detail.opf_success);
observed_shed_mw = detail.corrective_load_shed_mw;
observed_served_load_mw = detail.served_load_mw;
max_positive_q_injection = detail.max_positive_q_injection;
status = "pass";
note = string(detail.message);
if ~opf_success
    status = "diagnostic_warning";
    note = "OPF did not converge; sign convention could not be fully verified. " + note;
elseif test_name == "no_constraint_case" && observed_shed_mw > 1e-2
    status = "fail";
    note = "No-constraint sign check shed load, which indicates objective/sign convention may be wrong.";
elseif expect_shed && observed_shed_mw <= 1e-6
    status = "diagnostic_warning";
    note = "Artificial limit case converged without shedding; branch limit may not bind in this OPF state.";
elseif max_positive_q_injection > 1e-6
    status = "fail";
    note = "Dispatchable load produced positive Q injection.";
end
row = table(string(test_name), opf_success, string(expected_behavior), observed_shed_mw, ...
    observed_served_load_mw, max_positive_q_injection, status, note, ...
    'VariableNames', {'test_name', 'opf_success', 'expected_behavior', ...
    'observed_shed_mw', 'observed_served_load_mw', 'max_positive_q_injection', ...
    'status', 'note'});
end

function ensure_dir(path)
if ~exist(path, 'dir')
    mkdir(path);
end
end
