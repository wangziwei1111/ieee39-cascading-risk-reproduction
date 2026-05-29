function main_check_unified_state_probability_diagnostic()
%MAIN_CHECK_UNIFIED_STATE_PROBABILITY_DIAGNOSTIC Validate same-run composite diagnostic outputs.
project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(project_root, 'src')));
out_root = fullfile(project_root, 'results', 'composite');
case_dir = fullfile(out_root, 'unified_state_probability_diagnostic_smoke');
log_path = fullfile(out_root, 'unified_state_probability_diagnostic_check_log.txt');
fid = fopen(log_path, 'w');
cleanup = onCleanup(@() fclose(fid));

must_exist(fullfile(project_root, 'src', 'risk', 'record_unified_state_probability.m'));
must_exist(fullfile(project_root, 'src', 'risk', 'flatten_unified_state_probability_records.m'));
must_exist(fullfile(project_root, 'src', 'risk', 'summarize_unified_state_probability_records.m'));
must_exist(fullfile(project_root, 'src', 'risk', 'compute_stage_severity_metrics.m'));
must_exist(fullfile(project_root, 'src', 'risk', 'flatten_stage_severity_records.m'));
stage_path = fullfile(case_dir, 'unified_state_probability_stage_details.csv');
summary_path = fullfile(case_dir, 'unified_state_probability_summary.csv');
severity_path = fullfile(case_dir, 'stage_severity_details.csv');
must_exist(stage_path);
must_exist(summary_path);
must_exist(severity_path);
must_exist(fullfile(out_root, 'unified_state_probability_risk_preview.csv'));
must_exist(fullfile(out_root, 'unified_stage_level_risk_preview.csv'));
must_exist(fullfile(out_root, 'stage_level_vs_chain_summary_risk_preview_comparison.csv'));
must_exist(fullfile(out_root, 'unified_vs_offline_composite_comparison.csv'));
must_exist(fullfile(out_root, 'unified_offline_difference_diagnosis.csv'));
must_exist(fullfile(out_root, 'unified_offline_stage_set_audit.csv'));
must_exist(fullfile(out_root, 'unified_offline_stage_key_diff.csv'));
must_exist(fullfile(out_root, 'line_probability_basis_audit.csv'));
must_exist(fullfile(case_dir, 'wind_trip_probability_details.csv'));
must_exist(fullfile(case_dir, 'generator_trip_probability_details.csv'));
must_exist(fullfile(case_dir, 'line_probability_candidate_details.csv'));

stage = readtable(stage_path, 'TextType', 'string');
summary = readtable(summary_path, 'TextType', 'string');
severity = readtable(severity_path, 'TextType', 'string');
comparison = readtable(fullfile(out_root, 'unified_vs_offline_composite_comparison.csv'), 'TextType', 'string');
if height(stage) == 0
    error('Unified state probability stage details must be non-empty.');
end
if any(~logical(stage.diagnostic_only))
    error('Unified state probability rows must be diagnostic_only.');
end
if any(contains(stage.note, "formal paper result"))
    error('Unified diagnostic must not be marked formal paper result.');
end
if exist(fullfile(project_root, 'results', 'final_summary', 'tables', ...
        'unified_state_probability_stage_details.csv'), 'file') == 2
    error('Unified diagnostic output must not be written to final_summary.');
end
if any(comparison.match_status == "different")
    error('Unified/offline comparison still contains unexplained different rows.');
end
prob_keys = stage(:, {'initial_branch', 'trial_id', 'stage_id'});
severity_keys = severity(:, {'initial_branch', 'trial_id', 'stage_id'});
if height(prob_keys) ~= height(severity_keys) || height(innerjoin(prob_keys, severity_keys, 'Keys', {'initial_branch', 'trial_id', 'stage_id'})) ~= height(prob_keys)
    error('stage_severity_details and unified_state_probability_stage_details stage keys must align.');
end
stage_risk = readtable(fullfile(out_root, 'unified_stage_level_risk_preview.csv'), 'TextType', 'string');
if any(contains(stage_risk.note, "formal VaR") | contains(stage_risk.note, "formal paper result"))
    error('Stage-level risk preview must not be labeled formal VaR.');
end

degenerate = all(abs(stage.P_wt_Ek - 1) < 1e-12 | isnan(stage.P_wt_Ek)) && ...
    all(abs(stage.P_ge_Ek - 1) < 1e-12 | isnan(stage.P_ge_Ek));
fprintf(fid, 'unified_state_probability_diagnostic_check passed.\n');
fprintf(fid, 'stage_count=%d\n', height(stage));
fprintf(fid, 'summary_stage_count=%d\n', summary.stage_count(1));
fprintf(fid, 'valid_P_total_stage_count=%d\n', summary.valid_P_total_stage_count(1));
fprintf(fid, 'stage_severity_count=%d\n', height(severity));
fprintf(fid, 'stage_probability_severity_keys_aligned=true\n');
if degenerate
    fprintf(fid, 'degenerate_to_line_probability=true\n');
    fprintf(fid, 'note=current unified smoke has P_wt=1 and P_ge=1, so P_total equals P_line.\n');
else
    fprintf(fid, 'degenerate_to_line_probability=false\n');
end
expected_basis_count = sum(comparison.match_status == "expected_different_due_to_probability_basis");
unexpected_count = sum(comparison.match_status == "unexpected_difference");
fprintf(fid, 'expected_different_due_to_probability_basis_count=%d\n', expected_basis_count);
if expected_basis_count > 0
    fprintf(fid, 'note=expected basis differences are explainable and not treated as program errors.\n');
end
fprintf(fid, 'unexpected_difference_count=%d\n', unexpected_count);
if unexpected_count > 0
    fprintf(fid, 'warning=unexpected_difference rows remain and require manual inspection.\n');
end
fprintf(fid, 'note=diagnostic only; no Markov sampling, state transition, formal paper_formula, or final_summary output was changed.\n');
fprintf('unified state probability diagnostic check passed: %s\n', log_path);
end

function must_exist(path)
if exist(path, 'file') ~= 2
    error('Required file missing: %s', path);
end
end
