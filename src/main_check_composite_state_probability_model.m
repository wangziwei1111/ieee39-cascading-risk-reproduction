function main_check_composite_state_probability_model()
%MAIN_CHECK_COMPOSITE_STATE_PROBABILITY_MODEL Validate offline composite probability diagnostics.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

out_dir = fullfile(project_root, 'results', 'composite');
log_path = fullfile(out_dir, 'composite_state_probability_model_check_log.txt');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

must_exist(fullfile(project_root, 'src', 'risk', 'compute_composite_state_probability.m'));
stress_path = fullfile(out_dir, 'composite_probability_stress_test.csv');
diag_path = fullfile(out_dir, 'composite_state_probability_diagnostic.csv');
summary_path = fullfile(out_dir, 'composite_probability_effect_summary.csv');
preview_path = fullfile(out_dir, 'composite_probability_risk_preview.csv');
must_exist(stress_path);
must_exist(diag_path);
must_exist(summary_path);
must_exist(preview_path);

stress = readtable(stress_path, 'TextType', 'string');
if any(stress.test_status ~= "pass")
    error('Composite probability stress test contains failures.');
end
diag = readtable(diag_path, 'TextType', 'string');
summary = readtable(summary_path, 'TextType', 'string');
if height(diag) == 0 || height(summary) == 0
    error('Composite diagnostic outputs must be non-empty.');
end
if exist(fullfile(project_root, 'results', 'final_summary', 'tables', ...
        'composite_state_probability_diagnostic.csv'), 'file') == 2
    error('Composite diagnostic output must not be written to final_summary.');
end

if any(contains(diag.calibration_status, "formal_paper_formula") | contains(diag.composite_status, "formal_paper_formula"))
    error('Composite diagnostic must not be marked as formal paper_formula.');
end
all_degenerate = all(abs(diag.P_wt_Ek - 1) < 1e-12 | isnan(diag.P_wt_Ek)) && ...
    all(abs(diag.P_ge_Ek - 1) < 1e-12 | isnan(diag.P_ge_Ek));

fprintf(fid, 'composite_state_probability_model_check passed.\n');
fprintf(fid, 'stress_test_rows=%d\n', height(stress));
fprintf(fid, 'diagnostic_rows=%d\n', height(diag));
fprintf(fid, 'summary_rows=%d\n', height(summary));
if all_degenerate
    fprintf(fid, 'degenerate_to_line_probability=true\n');
    fprintf(fid, 'note=current smoke has P_wt=1 and P_ge=1, so composite probability equals P_line.\n');
else
    fprintf(fid, 'degenerate_to_line_probability=false\n');
end
fprintf(fid, 'note=offline diagnostic only; no final_summary or formal paper_formula output was replaced.\n');
fprintf('composite state probability model check passed: %s\n', log_path);
end

function must_exist(path)
if exist(path, 'file') ~= 2
    error('Required file missing: %s', path);
end
end
