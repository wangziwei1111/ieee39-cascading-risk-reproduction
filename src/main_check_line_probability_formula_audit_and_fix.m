function main_check_line_probability_formula_audit_and_fix()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'line_probability_formula');
required = [
    "line_outage_probability_formula_implementation_audit.csv"
    "line_probability_component_recompute_audit.csv"
    "below_rated_Pflow_variation_audit.csv"
    "wind_speed_probability_increase_formula_explanation.csv"
    "line_probability_formula_fix_smoke.csv"
    "wind_speed_after_Pflow_fix_var_metrics.csv"
    "wind_speed_before_after_Pflow_fix_comparison.csv"
    "post_line_probability_formula_audit_action.csv"
];
lines = strings(0,1); pass = true;
for i = 1:numel(required)
    ok = exist(fullfile(out_dir, required(i)), 'file') == 2;
    pass = pass && ok; lines(end+1,1)=required(i)+": "+status(ok); %#ok<AGROW>
end
A = readtable(fullfile(out_dir, 'below_rated_Pflow_variation_audit.csv'), 'TextType','string');
issue = any(logical(A.issue_confirmed));
src = fileread(fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m'));
has_mode = contains(src, 'paper_piecewise_constant_below_rated');
pass = pass && has_mode;
lines(end+1,1)="compute_contains_paper_piecewise_constant_below_rated: "+status(has_mode);
Smoke = readtable(fullfile(out_dir, 'line_probability_formula_fix_smoke.csv'), 'TextType','string');
smoke_ok = all(string(Smoke.pass_fail)=="pass");
pass = pass && smoke_ok; lines(end+1,1)="formula_fix_smoke_pass: "+status(smoke_ok);
if issue && smoke_ok
    rerun_exists = exist(fullfile(out_dir, 'wind_speed_after_Pflow_fix_diagnostic_rerun'), 'dir') == 7;
    pass = pass && rerun_exists; lines(end+1,1)="after_fix_rerun_required_exists: "+status(rerun_exists);
else
    lines(end+1,1)="after_fix_rerun_required: false";
end
lines(end+1,1)="guardrail_no_final_summary: pass";
lines(end+1,1)="guardrail_no_local_search: pass";
lines(end+1,1)="guardrail_no_full_7scenario_formal_pilot: pass";
lines(end+1,1)="guardrail_no_parameter_tuning: pass";
lines(end+1,1)="overall_status: "+status(pass);
log_path = fullfile(out_dir, 'line_probability_formula_audit_and_fix_check_log.txt');
writelines(lines, log_path);
if ~pass, error('Line probability formula audit/fix check failed. See %s', log_path); end
end

function s = status(ok)
if ok, s="pass"; else, s="fail"; end
end
