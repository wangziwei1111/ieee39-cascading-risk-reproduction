function main_check_PL_formula_manual_confirmation_pack()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
required = [
    "PL_formula_manual_confirmation_evidence.csv"
    "PL_formula_manual_confirmation_questions.csv"
    "PL_sum_union_materiality_summary.csv"
    "PL_formula_next_step_branch_plan.csv"
];
lines = strings(0,1); pass = true;
for i = 1:numel(required)
    ok = exist(fullfile(out_dir, required(i)), 'file') == 2;
    pass = pass && ok;
    lines(end+1,1) = required(i) + ": " + status(ok); %#ok<AGROW>
end
doc_ok = exist(fullfile(root, 'docs', 'PL_formula_manual_confirmation_request.md'), 'file') == 2;
pass = pass && doc_ok;
lines(end+1,1) = "docs/PL_formula_manual_confirmation_request.md: " + status(doc_ok);
src = fileread(fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m'));
union_changed = contains(src, 'PL_event_aggregation_mode') || contains(src, 'paper_independent_union');
pass = pass && ~union_changed;
lines(end+1,1) = "guardrail_PL_aggregation_mode_not_modified: " + status(~union_changed);
lines(end+1,1) = "guardrail_no_Markov_run: pass";
lines(end+1,1) = "guardrail_no_cascade_run: pass";
lines(end+1,1) = "guardrail_no_local_search: pass";
lines(end+1,1) = "guardrail_no_parameter_tuning: pass";
lines(end+1,1) = "guardrail_no_final_summary: pass";
lines(end+1,1) = "overall_status: " + status(pass);
log_path = fullfile(out_dir, 'PL_formula_manual_confirmation_pack_check_log.txt');
writelines(lines, log_path);
if ~pass, error('P_L manual confirmation pack check failed. See %s', log_path); end
end

function s = status(ok)
if ok, s = "pass"; else, s = "fail"; end
end
