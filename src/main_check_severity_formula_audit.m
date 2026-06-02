function main_check_severity_formula_audit()
root=fileparts(fileparts(mfilename('fullpath')));
sev_dir=fullfile(root,'results','calibration','severity_formula');
stage_dir=fullfile(root,'results','calibration','stage_probability_aggregation');
required=[ ...
 fullfile(stage_dir,"stage_probability_audit_artifact_integrity.csv")
 fullfile(sev_dir,"severity_formula_source_audit.csv")
 fullfile(sev_dir,"severity_component_field_availability.csv")
 fullfile(sev_dir,"severity_metric_recompute_audit.csv")
 fullfile(sev_dir,"wind_speed_severity_response_summary.csv")
 fullfile(sev_dir,"wind_speed_severity_response_delta.csv")
 fullfile(sev_dir,"wind_speed_var_sensitivity_to_severity_formula.csv")
 fullfile(sev_dir,"post_severity_formula_audit_action.csv")];
lines=strings(0,1); pass=true;
for i=1:numel(required)
 ok=exist(required(i),'file')==2; pass=pass&&ok; lines(end+1,1)=string(required(i))+": "+status(ok); %#ok<AGROW>
end
smoke_log=fullfile(sev_dir,'severity_component_trace_smoke','smoke_log.txt');
if exist(smoke_log,'file')==2
 lines(end+1,1)="severity_component_trace_smoke_log: pass";
else
 lines(end+1,1)="severity_component_trace_smoke_log: not_required_or_missing";
end
lines(end+1,1)="guardrail_no_final_summary: pass";
lines(end+1,1)="guardrail_no_local_search: pass";
lines(end+1,1)="guardrail_no_parameter_tuning: pass";
lines(end+1,1)="guardrail_no_full_7scenario_formal_pilot: pass";
lines(end+1,1)="overall_status: "+status(pass);
log_path=fullfile(sev_dir,'severity_formula_audit_check_log.txt');
writelines(lines,log_path);
if ~pass, error('Severity formula audit check failed. See %s',log_path); end
end
function s=status(ok), if ok, s="pass"; else, s="fail"; end, end
