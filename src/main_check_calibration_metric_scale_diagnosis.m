function main_check_calibration_metric_scale_diagnosis()
%MAIN_CHECK_CALIBRATION_METRIC_SCALE_DIAGNOSIS Validate metric-scale diagnosis artifacts.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end
log_path = fullfile(out_dir, 'calibration_metric_scale_diagnosis_check_log.txt');
fid = fopen(log_path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, 'calibration_metric_scale_diagnosis_check_log\n');
fprintf(fid, 'generated_at=%s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

required = [
    "results/calibration/diagnostics/calibration_metric_source_audit.csv"
    "results/calibration/diagnostics/calibration_metric_scale_summary.csv"
    "results/calibration/diagnostics/calibration_metric_scale_fit.csv"
    "results/calibration/diagnostics/calibration_trend_alignment.csv"
    "results/calibration/diagnostics/calibration_trend_alignment_summary.csv"
    "docs/calibration_metric_scale_diagnosis.md"
    ];
for i = 1:numel(required)
    exists_flag = exist(fullfile(project_root, required(i)), 'file') == 2;
    fprintf(fid, 'required_file=%s exists=%d\n', required(i), exists_flag);
    if ~exists_flag
        error('Missing calibration metric scale diagnosis artifact: %s', required(i));
    end
end

summary = read_csv(fullfile(out_dir, 'calibration_metric_scale_summary.csv'));
diagnoses = unique(summary.diagnosis);
fprintf(fid, 'diagnoses=%s\n', strjoin(diagnoses, ','));
has_definition_mismatch = any(summary.diagnosis == "likely_metric_definition_mismatch") || ...
    any(summary.diagnosis == "likely_wrong_source_file");
if has_definition_mismatch
    fprintf(fid, 'do not proceed to parameter local search: metric source or definition mismatch detected\n');
end

source_audit = read_csv(fullfile(out_dir, 'calibration_metric_source_audit.csv'));
fprintf(fid, 'source_audit_rows=%d\n', height(source_audit));
if any(isnan(source_audit.paper_value))
    error('paper_value missing in metric source audit.');
end

trend_summary = read_csv(fullfile(out_dir, 'calibration_trend_alignment_summary.csv'));
fprintf(fid, 'trend_summary_rows=%d\n', height(trend_summary));

forbidden = [
    "results/final_summary/calibration_metric_scale_diagnosis_check_log.txt"
    "results/final_summary/tables/calibration_metric_source_audit.csv"
    "results/calibration/local_search_results.csv"
    ];
for i = 1:numel(forbidden)
    exists_flag = exist(fullfile(project_root, forbidden(i)), 'file') == 2;
    fprintf(fid, 'forbidden_file=%s exists=%d\n', forbidden(i), exists_flag);
    if exists_flag
        error('Forbidden output exists: %s', forbidden(i));
    end
end

doc_text = string(fileread(fullfile(project_root, 'docs', 'calibration_metric_scale_diagnosis.md')));
if ~contains(doc_text, "do not proceed to parameter local search") && has_definition_mismatch
    error('Diagnosis doc must state do not proceed to parameter local search when mismatch is detected.');
end

fprintf(fid, '\ncheck_status=passed\n');
fprintf('calibration metric scale diagnosis check passed: %s\n', log_path);
end

function tbl = read_csv(path)
opts = detectImportOptions(path, 'Delimiter', ',', 'TextType', 'string');
tbl = readtable(path, opts);
end
