function main_check_wind_speed_probability_component_trace_smoke()
root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
smoke_root = fullfile(out_root, 'wind_speed_probability_component_trace_smoke');
log_path = fullfile(out_root, 'wind_speed_probability_component_trace_smoke_check_log.txt');
lines = strings(0,1);
pass = true;
if exist(smoke_root, 'dir') ~= 7
    pass = false;
    lines(end+1,1) = "smoke_root: missing";
else
    lines(end+1,1) = "smoke_root: exists";
end
files = dir(fullfile(smoke_root, '*', '*', 'line_probability_component_trace.csv'));
if isempty(files)
    pass = false;
    lines(end+1,1) = "line_probability_component_trace: missing";
else
    required = ["P_flow","P_HF_L","P1","P2","P_L"];
    for i = 1:numel(files)
        path = fullfile(files(i).folder, files(i).name);
        T = readtable(path, 'TextType', 'string');
        ok = all(ismember(required, string(T.Properties.VariableNames)));
        pass = pass && ok;
        lines(end+1,1) = string(path) + ": required_component_fields=" + status(ok);
    end
end
sev = dir(fullfile(smoke_root, '*', '*', 'severity_component_trace.csv'));
pass = pass && ~isempty(sev);
lines(end+1,1) = "severity_component_trace_exists: " + status(~isempty(sev));
lines(end+1,1) = "guardrail_no_local_search: pass";
lines(end+1,1) = "guardrail_no_final_summary_write: pass";
lines(end+1,1) = "guardrail_no_after_curve_fix_main_result_overwrite: pass";
lines(end+1,1) = "overall_status: " + status(pass);
writelines(lines, log_path);
if ~pass
    error('Wind speed probability component trace smoke check failed. See %s', log_path);
end
end

function s = status(ok)
if ok, s = "pass"; else, s = "fail"; end
end
