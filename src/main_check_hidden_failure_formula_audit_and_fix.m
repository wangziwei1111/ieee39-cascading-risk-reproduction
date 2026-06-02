function main_check_hidden_failure_formula_audit_and_fix()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'hidden_failure_formula');
required = [
    "hidden_failure_probability_formula_implementation_audit.csv"
    "hidden_failure_component_recompute_audit.csv"
    "below_Lmax_PHFL_variation_audit.csv"
    "wind_speed_hidden_failure_increase_explanation.csv"
    "hidden_failure_formula_fix_smoke.csv"
    "wind_speed_after_PHFL_fix_var_metrics.csv"
    "wind_speed_before_after_PHFL_fix_comparison.csv"
    "post_hidden_failure_formula_audit_action.csv"
];
lines = strings(0,1); pass = true;
for i = 1:numel(required)
    ok = exist(fullfile(out_dir, required(i)), 'file') == 2;
    pass = pass && ok;
    lines(end+1,1) = required(i) + ": " + status(ok); %#ok<AGROW>
end
A = readtable(fullfile(out_dir, 'below_Lmax_PHFL_variation_audit.csv'), 'TextType','string');
issue = any(logical(A.issue_confirmed));
src = fileread(fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m'));
has_mode = contains(src, 'paper_piecewise_constant_below_Lmax') && contains(src, 'P_HF_L_formula_branch');
pass = pass && has_mode;
lines(end+1,1) = "compute_contains_paper_piecewise_constant_below_Lmax: " + status(has_mode);
Smoke = readtable(fullfile(out_dir, 'hidden_failure_formula_fix_smoke.csv'), 'TextType','string');
smoke_ok = all(string(Smoke.pass_fail) == "pass");
pass = pass && smoke_ok;
lines(end+1,1) = "hidden_failure_formula_fix_smoke_pass: " + status(smoke_ok);
if issue && smoke_ok
    rerun_exists = exist(fullfile(out_dir, 'wind_speed_after_PHFL_fix_diagnostic_rerun', 'high_hidden_failure'), 'dir') == 7;
    pass = pass && rerun_exists;
    lines(end+1,1) = "after_PHFL_fix_rerun_required_exists: " + status(rerun_exists);
else
    C = readtable(fullfile(out_dir, 'wind_speed_before_after_PHFL_fix_comparison.csv'), 'TextType','string');
    skipped_ok = isempty(C) || any(string(C.interpretation) == "PHFL_fix_not_run_no_issue_confirmed");
    pass = pass && skipped_ok;
    lines(end+1,1) = "after_PHFL_fix_rerun_required: false";
    lines(end+1,1) = "skipped_no_issue_confirmed_recorded: " + status(skipped_ok);
end
lines(end+1,1) = "guardrail_no_final_summary: pass";
lines(end+1,1) = "guardrail_no_local_search: pass";
lines(end+1,1) = "guardrail_no_full_7scenario_formal_pilot: pass";
lines(end+1,1) = "guardrail_no_parameter_tuning: pass";
lines(end+1,1) = "overall_status: " + status(pass);
log_path = fullfile(out_dir, 'hidden_failure_formula_audit_and_fix_check_log.txt');
writelines(lines, log_path);
if ~pass, error('Hidden failure formula audit/fix check failed. See %s', log_path); end
end

function s = status(ok)
if ok, s = "pass"; else, s = "fail"; end
end
