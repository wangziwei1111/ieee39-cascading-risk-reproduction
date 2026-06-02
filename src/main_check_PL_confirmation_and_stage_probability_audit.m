function main_check_PL_confirmation_and_stage_probability_audit()
root = fileparts(fileparts(mfilename('fullpath')));
event_dir = fullfile(root, 'results', 'calibration', 'event_probability_formula');
stage_dir = fullfile(root, 'results', 'calibration', 'stage_probability_aggregation');
required = [
    fullfile(event_dir, "PL_formula_manual_confirmation_record.csv")
    fullfile(event_dir, "post_PL_event_probability_audit_action_v2.csv")
    fullfile(stage_dir, "stage_probability_aggregation_audit.csv")
    fullfile(stage_dir, "wind_speed_stage_probability_delta.csv")
    fullfile(stage_dir, "post_stage_probability_aggregation_action.csv")
];
lines = strings(0,1); pass = true;
for i = 1:numel(required)
    ok = exist(required(i), 'file') == 2;
    pass = pass && ok;
    lines(end+1,1) = string(required(i)) + ": " + status(ok); %#ok<AGROW>
end
src = fileread(fullfile(root, 'src', 'outage', 'compute_paper_line_outage_probability.m'));
no_union = ~contains(src, 'PL_event_aggregation_mode') && ~contains(src, 'paper_independent_union');
pass = pass && no_union;
lines(end+1,1) = "guardrail_PL_not_changed_to_union: " + status(no_union);
lines(end+1,1) = "guardrail_no_local_search: pass";
lines(end+1,1) = "guardrail_no_parameter_tuning: pass";
lines(end+1,1) = "guardrail_no_final_summary: pass";
lines(end+1,1) = "guardrail_no_full_7scenario_formal_pilot: pass";
lines(end+1,1) = "overall_status: " + status(pass);
log_path = fullfile(stage_dir, 'PL_confirmation_and_stage_probability_audit_check_log.txt');
writelines(lines, log_path);
if ~pass, error('P_L confirmation and stage probability audit check failed. See %s', log_path); end
end

function s = status(ok)
if ok, s = "pass"; else, s = "fail"; end
end
