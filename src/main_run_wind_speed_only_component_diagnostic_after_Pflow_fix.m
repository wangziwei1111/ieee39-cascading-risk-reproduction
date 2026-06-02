function main_run_wind_speed_only_component_diagnostic_after_Pflow_fix()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
audit_path = fullfile(out_dir, 'below_rated_Pflow_variation_audit.csv');
smoke_path = fullfile(out_dir, 'line_probability_formula_fix_smoke.csv');
rerun_root = fullfile(out_dir, 'wind_speed_after_Pflow_fix_diagnostic_rerun');
if exist(rerun_root,'dir')~=7, mkdir(rerun_root); end
issue = false; smoke_ok = false;
if exist(audit_path,'file')==2
    A = readtable(audit_path, 'TextType','string');
    issue = any(logical(A.issue_confirmed));
end
if exist(smoke_path,'file')==2
    S = readtable(smoke_path, 'TextType','string');
    smoke_ok = all(string(S.pass_fail)=="pass");
end
if ~(issue && smoke_ok)
    writelines(["skipped_no_issue_confirmed"; "No Markov rerun executed because below-rated P_flow issue was not confirmed."], ...
        fullfile(rerun_root, 'after_Pflow_fix_rerun_log.txt'));
    return;
end
error('Pflow issue confirmed path is intentionally not auto-run here; inspect before rerun.');
end
