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
must_exist(summary_path); must_exist(delta_path); must_exist(bench_path);
must_exist(failure_diag_path); must_exist(failure_summary_path); must_exist(robust_path);
must_exist(apply_test_path); must_exist(apply_summary_path);
summary = readtable(summary_path);
delta = readtable(delta_path);
bench = readtable(bench_path);
failure_diag = readtable(failure_diag_path);
failure_summary = readtable(failure_summary_path);
robust = readtable(robust_path);
apply_test = readtable(apply_test_path);
apply_summary = readtable(apply_summary_path);

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
load_only = apply_summary(string(apply_summary.apply_solution_mode) == "load_only", :);
with_init = apply_summary(string(apply_summary.apply_solution_mode) == "load_dispatch_and_voltage_init", :);
if ~isempty(load_only) && ~isempty(with_init) && with_init.success_rate(1) > load_only.success_rate(1)
    apply_mode_note = 'load_dispatch_and_voltage_init improves diagnostic PF success rate; consider a separate diagnostic rerun before formal benchmarks.';
else
    apply_mode_note = 'apply_solution_mode did not improve PF success rate in this diagnostic sample; failures may not be state-application issues.';
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
fprintf(fid, 'check_status=passed; note=5-trial smoke only, not final thesis result.\n');
fprintf('OLS benchmark smoke check passed: %s\n', log_path);
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end
