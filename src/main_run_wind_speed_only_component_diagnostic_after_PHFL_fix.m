function main_run_wind_speed_only_component_diagnostic_after_PHFL_fix()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
audit_path = fullfile(out_dir, 'below_Lmax_PHFL_variation_audit.csv');
smoke_path = fullfile(out_dir, 'hidden_failure_formula_fix_smoke.csv');
rerun_root = fullfile(out_dir, 'wind_speed_after_PHFL_fix_diagnostic_rerun');
ensure_dir(rerun_root);
issue = false; smoke_ok = false;
if exist(audit_path, 'file') == 2
    A = readtable(audit_path, 'TextType','string');
    if ismember('issue_confirmed', A.Properties.VariableNames)
        issue = any(logical(A.issue_confirmed));
    end
end
if exist(smoke_path, 'file') == 2
    S = readtable(smoke_path, 'TextType','string');
    smoke_ok = all(string(S.pass_fail) == "pass");
end
if ~(issue && smoke_ok)
    writelines(["skipped_no_issue_confirmed"; ...
        "No Markov rerun executed because below-Lmax P_HF_L issue was not confirmed or formula smoke did not require rerun."], ...
        fullfile(rerun_root, 'after_PHFL_fix_rerun_log.txt'));
    return;
end
error('P_HF_L issue confirmed path requires explicit review before running wind-speed diagnostic rerun.');
end

function ensure_dir(path)
if exist(path,'dir')~=7, mkdir(path); end
end
