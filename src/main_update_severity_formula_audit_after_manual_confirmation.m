function main_update_severity_formula_audit_after_manual_confirmation()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
ensure_dir(out_dir);
record_file = fullfile(out_dir, 'severity_formula_manual_confirmation_record.csv');
if exist(record_file, 'file') ~= 2
    error('Missing severity_formula_manual_confirmation_record.csv');
end
R = readtable(record_file, 'TextType', 'string', 'Delimiter', ',');
if ~logical(R.confirmed_by_user(1))
    error('Manual confirmation record is not confirmed_by_user.');
end
T = table(true, ...
    "manual_confirmation_completed_current_LFOR_NVOR_mismatch", ...
    "paper_severity_formulas_confirmed_by_user", ...
    "implement_paper_confirmed_severity_formula_mode", ...
    "implement paper LFOR/NVOR exponential severity and run wind-speed-only diagnostic rerun", ...
    "Current code LFOR/NVOR max-count formulas differ from confirmed paper exponential full-line/full-bus sums; fix only severity mode, no tuning.", ...
    'VariableNames', {'selected','dominant_root_cause','formula_status','go_no_go','recommended_next_action','note'});
writetable(T, fullfile(out_dir, 'post_severity_formula_audit_action_v2.csv'));
end

function ensure_dir(p)
if exist(p,'dir')~=7, mkdir(p); end
end
