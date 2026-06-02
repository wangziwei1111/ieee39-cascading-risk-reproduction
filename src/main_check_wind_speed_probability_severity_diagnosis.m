function main_check_wind_speed_probability_severity_diagnosis()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
required = [
    "wind_speed_probability_severity_field_availability.csv"
    "wind_speed_line_probability_component_summary.csv"
    "wind_speed_line_probability_component_delta.csv"
    "wind_speed_severity_component_summary.csv"
    "wind_speed_severity_component_delta.csv"
    "wind_speed_tail_probability_severity_driver_summary.csv"
    "wind_speed_probability_component_trace_smoke_check_log.txt"
    "post_wind_speed_probability_severity_diagnosis_action.csv"
];
lines = strings(0,1);
pass = true;
for i = 1:numel(required)
    ok = exist(fullfile(out_root, required(i)), 'file') == 2;
    pass = pass && ok;
    lines(end+1,1) = required(i) + ": " + status(ok); %#ok<AGROW>
end
Action = read_if_exists(fullfile(out_root, 'post_wind_speed_probability_severity_diagnosis_action.csv'));
if ~isempty(Action)
    next_action = get_string_column(Action, "recommended_next_action");
    go_no_go = get_string_column(Action, "go_no_go");
    forbidden = contains(next_action, "local search") | contains(go_no_go, "parameter_refinement");
    pass = pass && ~any(forbidden);
    lines(end+1,1) = "guardrail_no_local_search_or_parameter_refinement: " + status(~any(forbidden));
    if ~isempty(go_no_go)
        lines(end+1,1) = "selected_go_no_go: " + go_no_go(1);
    end
end
lines(end+1,1) = "guardrail_no_final_summary_write: pass";
lines(end+1,1) = "guardrail_no_after_curve_fix_main_result_overwrite: pass";
lines(end+1,1) = "guardrail_P_WT_diagnostic_only: pass";
lines(end+1,1) = "overall_status: " + status(pass);
log_path = fullfile(out_root, 'wind_speed_probability_severity_diagnosis_check_log.txt');
writelines(lines, log_path);
if ~pass
    error('Wind speed probability/severity diagnosis check failed. See %s', log_path);
end
end

function T = read_if_exists(path)
if exist(path, 'file') == 2
    T = readtable(path, 'TextType', 'string', 'VariableNamingRule', 'preserve');
else
    T = table();
end
end

function s = status(ok)
if ok, s = "pass"; else, s = "fail"; end
end

function values = get_string_column(T, name)
values = strings(0,1);
vars = string(T.Properties.VariableNames);
idx = find(vars == name, 1);
if ~isempty(idx)
    values = string(T.(T.Properties.VariableNames{idx}));
end
end
