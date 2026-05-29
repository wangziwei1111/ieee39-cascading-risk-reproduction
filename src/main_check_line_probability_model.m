function main_check_line_probability_model()
%MAIN_CHECK_LINE_PROBABILITY_MODEL Check thesis line probability diagnostic outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
out_root = fullfile(project_root, 'results', 'outage');
smoke_dir = fullfile(out_root, 'line_probability_diagnostic_smoke');
unit_path = fullfile(out_root, 'paper_line_probability_unit_test.csv');
comparison_path = fullfile(smoke_dir, 'candidate_probability_comparison.csv');
summary_path = fullfile(smoke_dir, 'line_probability_summary.csv');
chain_path = fullfile(smoke_dir, 'markov_chain_summary.csv');
log_path = fullfile(out_root, 'line_probability_model_check_log.txt');

must_exist(fullfile(project_root, 'src', 'outage', 'compute_paper_line_outage_probability.m'));
must_exist(fullfile(project_root, 'src', 'outage', 'compute_line_outage_probability_dispatch.m'));
if ~strcmp(string(cfg.line_outage_probability_model), "engineering")
    error('Default cfg.line_outage_probability_model must remain engineering.');
end
must_exist(unit_path);
must_exist(comparison_path);
must_exist(summary_path);
must_exist(chain_path);
must_exist(fullfile(smoke_dir, 'diagnostic_log.txt'));

unit_tbl = readtable(unit_path);
comparison = readtable(comparison_path);
summary = readtable(summary_path);
if isempty(unit_tbl)
    error('paper_line_probability_unit_test.csv is empty.');
end
if any(unit_tbl.p_line < 0 | unit_tbl.p_line > 1, 'all')
    error('Unit-test p_line is outside [0,1].');
end
if any(strcmp(string(unit_tbl.status), "calibrated"))
    error('paper_formula must not be marked calibrated.');
end
if isempty(comparison)
    error('candidate_probability_comparison.csv is empty.');
end
if ~any(contains(string(comparison.paper_formula_status), "missing_parameter"))
    error('paper_formula diagnostic should expose missing-parameter status with current NaN inputs.');
end
if ~any(logical(comparison.paper_formula_used_fallback))
    error('paper_formula diagnostic should mark fallback when paper parameters are missing.');
end
if any(abs(comparison.outage_probability - comparison.engineering_probability) > 1e-12, 'all')
    error('paper_formula_diagnostic must keep main-chain outage_probability equal to engineering_probability.');
end
if summary.paper_formula_fallback_count(1) <= 0
    error('line_probability_summary must count paper_formula fallbacks.');
end

fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'line probability model check passed\n');
fprintf(fid, 'default_model=%s\n', cfg.line_outage_probability_model);
fprintf(fid, 'unit_rows=%d\n', height(unit_tbl));
fprintf(fid, 'diagnostic_candidate_rows=%d\n', height(comparison));
fprintf(fid, 'paper_formula_fallback_count=%d\n', summary.paper_formula_fallback_count(1));
fprintf(fid, 'note=paper_formula remains diagnostic and uncalibrated; Markov main chain uses engineering probability in diagnostic smoke.\n');
fprintf('line probability model check passed: %s\n', log_path);
end

function must_exist(path)
if ~exist(path, 'file')
    error('Required file missing: %s', path);
end
end
