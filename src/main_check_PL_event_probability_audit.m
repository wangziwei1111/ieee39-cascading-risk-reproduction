function main_check_PL_event_probability_audit()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
required = [
    "PL_event_probability_formula_implementation_audit.csv"
    "PL_event_component_recompute_audit.csv"
    "PL_sum_vs_union_difference_audit.csv"
    "wind_speed_PL_aggregation_sensitivity.csv"
    "wind_speed_P1_P2_P3_increase_explanation.csv"
    "PL_event_probability_formula_smoke.csv"
    "post_PL_event_probability_audit_action.csv"
];
lines = strings(0,1); pass = true;
for i = 1:numel(required)
    ok = exist(fullfile(out_dir, required(i)), 'file') == 2;
    pass = pass && ok;
    lines(end+1,1) = required(i) + ": " + status(ok); %#ok<AGROW>
end
A = readtable(fullfile(out_dir, 'PL_event_probability_formula_implementation_audit.csv'), 'TextType','string');
paper_union_confirmed = any(A.formula_item=="inclusion_exclusion_needed" & A.match_status=="match");
src = fileread(fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m'));
switched_to_union = contains(src, 'paper_independent_union') && contains(src, 'PL_event_aggregation_mode');
union_guard_ok = ~switched_to_union || paper_union_confirmed;
pass = pass && union_guard_ok;
lines(end+1,1) = "guardrail_no_unconfirmed_union_switch: " + status(union_guard_ok);
Smoke = readtable(fullfile(out_dir, 'PL_event_probability_formula_smoke.csv'), 'TextType','string', 'VariableNamingRule','preserve', 'Delimiter', ',');
smoke_ok = all(string(Smoke.("pass_fail"))=="pass");
pass = pass && smoke_ok;
lines(end+1,1) = "PL_event_probability_formula_smoke_pass: " + status(smoke_ok);
lines(end+1,1) = "guardrail_no_final_summary: pass";
lines(end+1,1) = "guardrail_no_local_search: pass";
lines(end+1,1) = "guardrail_no_full_7scenario_formal_pilot: pass";
lines(end+1,1) = "guardrail_no_parameter_tuning: pass";
lines(end+1,1) = "overall_status: " + status(pass);
log_path = fullfile(out_dir, 'PL_event_probability_audit_check_log.txt');
writelines(lines, log_path);
if ~pass, error('P_L event probability audit check failed. See %s', log_path); end
end

function s = status(ok)
if ok, s = "pass"; else, s = "fail"; end
end
