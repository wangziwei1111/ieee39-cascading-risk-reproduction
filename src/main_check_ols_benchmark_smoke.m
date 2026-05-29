function main_check_ols_benchmark_smoke()
%MAIN_CHECK_OLS_BENCHMARK_SMOKE Check OLS benchmark smoke outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
table_dir = fullfile(root_dir, 'tables');
log_dir = fullfile(root_dir, 'logs');
figure_dir = fullfile(root_dir, 'figures');
if ~exist(log_dir, 'dir')
    mkdir(log_dir);
end

summary_path = fullfile(table_dir, 'ols_benchmark_smoke_summary.csv');
delta_path = fullfile(table_dir, 'ols_vs_simple_delta.csv');
bench_path = fullfile(table_dir, 'ols_smoke_vs_paper_benchmark.csv');
failure_diag_path = fullfile(table_dir, 'ols_failure_diagnosis.csv');
failure_summary_path = fullfile(table_dir, 'ols_failure_summary.csv');
robust_path = fullfile(table_dir, 'ols_solver_robustness_test.csv');
apply_test_path = fullfile(table_dir, 'ols_apply_solution_mode_test.csv');
apply_summary_path = fullfile(table_dir, 'ols_apply_solution_mode_summary.csv');
modeling_path = fullfile(table_dir, 'ols_modeling_consistency_check.csv');
case_index_path = fullfile(table_dir, 'ols_failure_case_index.csv');
case_replay_path = fullfile(table_dir, 'ols_failure_case_replay_check.csv');
alternative_path = fullfile(table_dir, 'ols_alternative_formulation_review.csv');
dc_preview_path = fullfile(table_dir, 'dc_ols_feasibility_preview.csv');
fixed_test_path = fullfile(table_dir, 'ols_fixed_q_shed_test.csv');
fixed_summary_path = fullfile(table_dir, 'ols_fixed_q_shed_summary.csv');
fixed_delta_path = fullfile(table_dir, 'ols_fixed_q_vs_free_q_delta.csv');
dispatch_sign_path = fullfile(table_dir, 'dispatchable_load_sign_convention_test.csv');
dispatch_case_path = fullfile(table_dir, 'ols_dispatchable_load_case_test.csv');
dispatch_case_summary_path = fullfile(table_dir, 'ols_dispatchable_load_case_summary.csv');
formulation_comparison_path = fullfile(table_dir, 'ols_formulation_comparison.csv');
dispatch_failure_diag_path = fullfile(table_dir, 'dispatchable_load_failure_diagnosis.csv');
dispatch_failure_summary_path = fullfile(table_dir, 'dispatchable_load_failure_summary.csv');
dispatch_failure_case_index_path = fullfile(table_dir, 'dispatchable_failure_case_index.csv');
dc_preshed_test_path = fullfile(table_dir, 'dc_preshed_dispatchable_failure_test.csv');
dc_preshed_summary_path = fullfile(table_dir, 'dc_preshed_dispatchable_summary.csv');
must_exist(summary_path); must_exist(delta_path); must_exist(bench_path);
must_exist(failure_diag_path); must_exist(failure_summary_path); must_exist(robust_path);
must_exist(apply_test_path); must_exist(apply_summary_path);
must_exist(modeling_path); must_exist(case_index_path); must_exist(case_replay_path);
must_exist(alternative_path); must_exist(dc_preview_path);
must_exist(fixed_test_path); must_exist(fixed_summary_path); must_exist(fixed_delta_path);
must_exist(dispatch_sign_path); must_exist(dispatch_case_path);
must_exist(dispatch_case_summary_path); must_exist(formulation_comparison_path);
must_exist(dispatch_failure_diag_path); must_exist(dispatch_failure_summary_path);
must_exist(dispatch_failure_case_index_path); must_exist(dc_preshed_test_path);
must_exist(dc_preshed_summary_path);
summary = readtable(summary_path);
delta = readtable(delta_path);
bench = readtable(bench_path);
failure_diag = readtable(failure_diag_path);
failure_summary = readtable(failure_summary_path);
robust = readtable(robust_path);
apply_test = readtable(apply_test_path);
apply_summary = readtable(apply_summary_path);
modeling = readtable(modeling_path, 'Delimiter', ',');
case_index = readtable(case_index_path);
case_replay = readtable(case_replay_path);
alternative = readtable(alternative_path);
dc_preview = readtable(dc_preview_path, 'Delimiter', ',');
fixed_test = readtable(fixed_test_path);
fixed_summary = readtable(fixed_summary_path);
fixed_delta = readtable(fixed_delta_path);
dispatch_sign = readtable(dispatch_sign_path);
dispatch_case = readtable(dispatch_case_path);
dispatch_case_summary = readtable(dispatch_case_summary_path);
formulation_comparison = readtable(formulation_comparison_path);
dispatch_failure_diag = readtable(dispatch_failure_diag_path);
dispatch_failure_summary = readtable(dispatch_failure_summary_path);
dispatch_failure_case_index = readtable(dispatch_failure_case_index_path, ...
    detectImportOptions(dispatch_failure_case_index_path, 'Delimiter', ',', 'VariableNamingRule', 'preserve'));
dc_preshed_test = readtable(dc_preshed_test_path);
dc_preshed_summary = readtable(dc_preshed_summary_path);

scenarios = string(unique(summary.scenario_id, 'stable'));
for i = 1:numel(scenarios)
    rows = summary(string(summary.scenario_id) == scenarios(i), :);
    if ~all(ismember(["simple", "paper_ols_violation"], string(rows.mode)))
        error('Scenario %s is missing simple or paper_ols_violation rows.', scenarios(i));
    end
end

simple = summary(string(summary.mode) == "simple", :);
ols = summary(string(summary.mode) == "paper_ols_violation", :);
if any(string(simple.load_shedding_mode) ~= "simple")
    error('simple mode rows must have load_shedding_mode=simple.');
end
if any(string(ols.load_shedding_mode) ~= "paper_ols")
    error('paper_ols_violation rows must have load_shedding_mode=paper_ols.');
end
if any(string(ols.load_shedding_trigger_mode) ~= "nonconverged_or_violation")
    error('paper_ols_violation rows must use nonconverged_or_violation trigger mode.');
end
if any(summary.markov_trials_per_initial_fault ~= 5)
    error('OLS benchmark smoke must use 5 trials per initial fault.');
end
if any(summary.chain_count ~= 46 * 5)
    error('chain_count must equal 46*5 for every summary row.');
end
if any(summary.fallback_count > 0 & strlength(string(summary.note)) == 0)
    error('Rows with fallback_count > 0 must have a nonempty note.');
end

must_exist(fullfile(figure_dir, 'ols_vs_simple_cri_comparison.png'));
must_exist(fullfile(figure_dir, 'ols_trigger_counts.png'));
must_exist(fullfile(figure_dir, 'ols_smoke_vs_paper_cri.png'));
must_exist(fullfile(figure_dir, 'ols_failure_type_summary.png'));
must_exist(fullfile(figure_dir, 'ols_solver_robustness.png'));
must_exist(fullfile(figure_dir, 'ols_apply_solution_mode_success.png'));
must_exist(fullfile(figure_dir, 'ols_modeling_issue_summary.png'));
must_exist(fullfile(figure_dir, 'dc_ols_feasibility_preview.png'));
must_exist(fullfile(figure_dir, 'ols_fixed_q_success_comparison.png'));
must_exist(fullfile(figure_dir, 'ols_fixed_q_q_mismatch.png'));
must_exist(fullfile(figure_dir, 'ols_fixed_q_cri_delta.png'));
must_exist(fullfile(figure_dir, 'ols_formulation_failure_rate.png'));
must_exist(fullfile(figure_dir, 'ols_formulation_q_behavior.png'));
must_exist(fullfile(figure_dir, 'ols_formulation_cri_comparison.png'));
must_exist(fullfile(figure_dir, 'dc_preshed_dispatchable_success.png'));
must_exist(fullfile(figure_dir, 'ols_two_stage_failure_rate.png'));
must_exist(fullfile(figure_dir, 'ols_two_stage_cri_comparison.png'));
if exist(fullfile(project_root, 'results', 'final_summary', 'tables', 'ols_benchmark_smoke_summary.csv'), 'file')
    error('OLS benchmark smoke must not write into final_summary.');
end

for i = 1:height(failure_summary)
    scenario_id = string(failure_summary.scenario_id(i));
    ols_row = summary(string(summary.scenario_id) == scenario_id & string(summary.mode) == "paper_ols_violation", :);
    if isempty(ols_row)
        error('Failure summary scenario %s is missing from smoke summary.', scenario_id);
    end
    if failure_summary.failed_ols_count(i) ~= ols_row.failed_ols_count(1)
        error('Failure count mismatch for %s.', scenario_id);
    end
end
if max(failure_summary.failure_rate) > 0.1
    high_failure_note = 'Do not proceed to formal OLS benchmark rerun before reducing or explaining OLS failures.';
else
    high_failure_note = 'OLS failure rate is below 0.1 in this smoke diagnosis.';
end
if isempty(robust)
    error('OLS solver robustness test must not be empty.');
end
required_modes = ["load_only", "load_and_dispatch", "load_dispatch_and_voltage_init"];
if ~all(ismember(required_modes, string(apply_summary.apply_solution_mode)))
    error('OLS apply solution mode summary must include all three apply modes.');
end
if exist(fullfile(table_dir, 'ols_benchmark_smoke_summary_with_apply_modes.csv'), 'file')
    error('Apply solution mode diagnostics must not be written into the main benchmark summary.');
end
if height(case_index) < 3
    error('At least 3 exported OLS failure cases are required, or the export script must fail explicitly.');
end
if isempty(case_replay)
    error('Failure case replay check must not be empty.');
end
if isempty(alternative)
    error('Alternative OLS formulation review must not be empty.');
end
if isempty(dc_preview)
    error('DC-OLS feasibility preview must not be empty.');
end
if isempty(fixed_test) || isempty(fixed_summary) || isempty(fixed_delta)
    error('Fixed-Q shed diagnostic tables must not be empty.');
end
if isempty(dispatch_sign) || isempty(dispatch_case) || isempty(dispatch_case_summary) || isempty(formulation_comparison)
    error('Dispatchable-load diagnostic tables must not be empty.');
end
if isempty(dispatch_failure_diag) || isempty(dispatch_failure_summary) || isempty(dispatch_failure_case_index) || ...
        isempty(dc_preshed_test) || isempty(dc_preshed_summary)
    error('Dispatchable-load failure and DC preshed diagnostic tables must not be empty.');
end
if any(string(dispatch_sign.status) == "fail")
    error('Dispatchable-load sign convention has failed rows.');
end
fixed_rows = fixed_test(string(fixed_test.shed_gen_q_mode) == "fixed_zero_q", :);
if isempty(fixed_rows)
    error('Fixed-Q shed test must contain fixed_zero_q rows.');
end
if max(abs(fixed_rows.max_abs_shed_gen_qg), [], 'omitnan') > 1e-5
    error('fixed_zero_q shed generator QG must be approximately zero.');
end
if ~ismember("fixed_zero_q", string(fixed_summary.shed_gen_q_mode))
    error('Fixed-Q shed summary must contain fixed_zero_q.');
end
fixed_dirs = ["distributed_wind_3000mw_base", "distributed_wind_penetration_40pct", "paper_wind_speed_12_00mps"];
for fd = 1:numel(fixed_dirs)
    fixed_dir = fullfile(root_dir, 'fixed_q_shed', char(fixed_dirs(fd)), 'tables');
    must_exist(fullfile(fixed_dir, 'markov_chain_summary.csv'));
    must_exist(fullfile(fixed_dir, 'ols_stage_details.csv'));
    must_exist(fullfile(fixed_dir, 'ols_summary.csv'));
    dispatch_dir = fullfile(root_dir, 'dispatchable_load', char(fixed_dirs(fd)), 'tables');
    must_exist(fullfile(dispatch_dir, 'markov_chain_summary.csv'));
    must_exist(fullfile(dispatch_dir, 'ols_stage_details.csv'));
    must_exist(fullfile(dispatch_dir, 'ols_summary.csv'));
end
dispatch_rows = dispatch_case(string(dispatch_case.formulation) == "dispatchable_load", :);
if isempty(dispatch_rows)
    error('Dispatchable-load case test must contain dispatchable_load rows.');
end
max_positive_dispatch_q = max(dispatch_rows.max_positive_q_injection, [], 'omitnan');
dispatch_form_rows = formulation_comparison(string(formulation_comparison.formulation) == "dispatchable_load", :);
if isempty(dispatch_form_rows)
    error('Formulation comparison must include dispatchable_load rows.');
end
if exist(fullfile(project_root, 'results', 'final_summary', 'tables', 'ols_formulation_comparison.csv'), 'file')
    error('Dispatchable-load diagnostics must not write into final_summary.');
end
if exist(fullfile(project_root, 'results', 'final_summary', 'tables', 'dc_preshed_dispatchable_summary.csv'), 'file')
    error('DC preshed diagnostics must not write into final_summary.');
end
if exist(fullfile(project_root, 'src', 'loadshedding', 'solve_dc_ols_preshed.m'), 'file') ~= 2
    error('solve_dc_ols_preshed.m is missing.');
end
two_stage_rows = formulation_comparison(string(formulation_comparison.formulation) == "dispatchable_load_two_stage_dc_ac", :);
if isempty(two_stage_rows)
    error('Formulation comparison must include dispatchable_load_two_stage_dc_ac.');
end
for fd = 1:numel(fixed_dirs)
    two_stage_dir = fullfile(root_dir, 'two_stage_dc_ac', char(fixed_dirs(fd)), 'tables');
    must_exist(fullfile(two_stage_dir, 'markov_chain_summary.csv'));
    must_exist(fullfile(two_stage_dir, 'ols_stage_details.csv'));
    must_exist(fullfile(two_stage_dir, 'ols_summary.csv'));
end
for ci = 1:height(case_index)
    if ~exist(char(string(case_index.case_dir(ci))), 'dir')
        error('Exported failure case directory is missing: %s', string(case_index.case_dir(ci)));
    end
end
q_rows = modeling(contains(lower(string(modeling.check_name)), "opf shed q") | ...
    contains(lower(string(modeling.check_name)), "applied shed_q"), :);
q_status = string(get_table_column(q_rows, "status"));
if any(q_status == "warning")
    q_note = 'q_mismatch_warning=Detected shed-generator Q / applied shed_Q warning; next step should review reactive shedding formulation.';
else
    q_note = 'q_mismatch_warning=None detected in the representative consistency check.';
end
load_only = apply_summary(string(apply_summary.apply_solution_mode) == "load_only", :);
with_init = apply_summary(string(apply_summary.apply_solution_mode) == "load_dispatch_and_voltage_init", :);
if ~isempty(load_only) && ~isempty(with_init) && with_init.success_rate(1) > load_only.success_rate(1)
    apply_mode_note = 'load_dispatch_and_voltage_init improves diagnostic PF success rate; consider a separate diagnostic rerun before formal benchmarks.';
else
    apply_mode_note = 'apply_solution_mode did not improve PF success rate in this diagnostic sample; failures may not be state-application issues.';
end
free_q_summary = fixed_summary(string(fixed_summary.shed_gen_q_mode) == "free_q", :);
fixed_q_summary = fixed_summary(string(fixed_summary.shed_gen_q_mode) == "fixed_zero_q", :);
fixed_q_note = "fixed_q_note=Unable to compare fixed_zero_q against free_q.";
if ~isempty(free_q_summary) && ~isempty(fixed_q_summary)
    if fixed_q_summary.mean_q_mismatch(1) < free_q_summary.mean_q_mismatch(1)
        fixed_q_note = "fixed_q_note=fixed_zero_q lowered Q mismatch in exported failure case tests.";
    end
    if fixed_q_summary.success_rate(1) <= free_q_summary.success_rate(1)
        fixed_q_note = fixed_q_note + " Success rate did not improve enough for direct formal rerun recommendation.";
    else
        fixed_q_note = fixed_q_note + " Success rate improved; use only for a separate diagnostic rerun before formal benchmarks.";
    end
end
failure_delta_rows = fixed_delta(string(fixed_delta.metric_name) == "failure_rate", :);
if ~isempty(failure_delta_rows) && any(failure_delta_rows.delta_value > 0)
    fixed_q_note = fixed_q_note + " In the 5-trial fixed_q_shed smoke, failure_rate increased for at least one scenario; do not adopt fixed_zero_q as formal default.";
elseif ~isempty(failure_delta_rows) && all(failure_delta_rows.delta_value <= 0)
    fixed_q_note = fixed_q_note + " In the 5-trial fixed_q_shed smoke, failure_rate did not increase; still diagnostic only.";
end

log_path = fullfile(log_dir, 'ols_benchmark_smoke_check_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'OLS benchmark smoke check log\n');
fprintf(fid, 'generated_at=%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, 'scenario_count=%d summary_rows=%d delta_rows=%d benchmark_rows=%d failure_rows=%d robustness_rows=%d apply_mode_rows=%d\n', ...
    numel(scenarios), height(summary), height(delta), height(bench), height(failure_diag), height(robust), height(apply_test));
fprintf(fid, 'failure_recommendation=%s\n', high_failure_note);
fprintf(fid, 'apply_solution_mode_recommendation=%s\n', apply_mode_note);
fprintf(fid, 'exported_failure_case_count=%d replay_rows=%d alternative_rows=%d dc_preview_rows=%d\n', ...
    height(case_index), height(case_replay), height(alternative), height(dc_preview));
fprintf(fid, '%s\n', q_note);
fprintf(fid, '%s\n', fixed_q_note);
if max_positive_dispatch_q > 1e-6
    fprintf(fid, 'dispatchable_load_q_warning=max_positive_q_injection %.12g exceeds 1e-6; inspect reactive sign convention.\n', max_positive_dispatch_q);
else
    fprintf(fid, 'dispatchable_load_q_warning=none; dispatchable-load case tests did not produce positive Q injection above tolerance.\n');
end
if any(dispatch_form_rows.failure_rate > 0.1)
    fprintf(fid, 'dispatchable_load_recommendation=Failure rate remains above 0.1 for at least one scenario; do not proceed to formal benchmark.\n');
else
    fprintf(fid, 'dispatchable_load_recommendation=Failure rate is below 0.1 in this 5-trial diagnostic; still requires separate review before formal benchmark.\n');
end
fprintf(fid, 'dispatchable_failure_rows=%d dispatchable_exported_cases=%d dc_preshed_rows=%d\n', ...
    height(dispatch_failure_diag), height(dispatch_failure_case_index), height(dc_preshed_test));
if any(two_stage_rows.failure_rate > 0.1)
    fprintf(fid, 'two_stage_recommendation=Two-stage failure rate remains above 0.1 for at least one scenario; do not proceed to formal benchmark.\n');
else
    fprintf(fid, 'two_stage_recommendation=Two-stage failure rate is below 0.1; consider a future 20-trial diagnostic rerun, still not final reproduction.\n');
end
fprintf(fid, 'check_status=passed; note=5-trial smoke only, not final thesis result.\n');
fprintf('OLS benchmark smoke check passed: %s\n', log_path);
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end

function col = get_table_column(tbl, name)
vars = string(tbl.Properties.VariableNames);
idx = find(vars == name, 1);
if isempty(idx)
    idx = find(vars == name + "_", 1);
end
if isempty(idx)
    error('Missing expected table column: %s', name);
end
col = tbl.(vars(idx));
end
