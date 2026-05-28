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
must_exist(summary_path); must_exist(delta_path); must_exist(bench_path);
summary = readtable(summary_path);
delta = readtable(delta_path);
bench = readtable(bench_path);

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
if exist(fullfile(project_root, 'results', 'final_summary', 'tables', 'ols_benchmark_smoke_summary.csv'), 'file')
    error('OLS benchmark smoke must not write into final_summary.');
end

log_path = fullfile(log_dir, 'ols_benchmark_smoke_check_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'OLS benchmark smoke check log\n');
fprintf(fid, 'generated_at=%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, 'scenario_count=%d summary_rows=%d delta_rows=%d benchmark_rows=%d\n', ...
    numel(scenarios), height(summary), height(delta), height(bench));
fprintf(fid, 'check_status=passed; note=5-trial smoke only, not final thesis result.\n');
fprintf('OLS benchmark smoke check passed: %s\n', log_path);
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file is missing: %s', path);
end
end
