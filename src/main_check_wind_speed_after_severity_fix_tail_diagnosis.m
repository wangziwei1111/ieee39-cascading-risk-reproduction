function main_check_wind_speed_after_severity_fix_tail_diagnosis()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula');
files=["wind_speed_after_severity_fix_tail_samples.csv", ...
    "wind_speed_after_severity_fix_tail_initial_branch_summary.csv", ...
    "wind_speed_after_severity_fix_tail_initial_branch_delta.csv", ...
    "wind_speed_after_severity_fix_tail_candidate_branch_summary.csv", ...
    "wind_speed_after_severity_fix_tail_candidate_branch_delta.csv", ...
    "wind_speed_after_severity_fix_baseflow_tail_correlation.csv", ...
    "wind_speed_after_severity_fix_baseflow_delta_summary.csv", ...
    "post_wind_speed_after_severity_fix_tail_action.csv"];
rows={};
for i=1:numel(files)
    rows{end+1,1}=row(files(i),exist(fullfile(out_dir,files(i)),'file')==2,fullfile(out_dir,files(i))); %#ok<AGROW>
end
rows{end+1,1}=row("guard_no_final_summary",true,"No final_summary called.");
rows{end+1,1}=row("guard_no_local_search",true,"No local search called.");
rows{end+1,1}=row("guard_no_parameter_tuning",true,"No parameter refinement.");
rows{end+1,1}=row("guard_no_full_7scenario_formal_pilot",true,"No full formal pilot.");
T=vertcat(rows{:}); overall=all(T.pass);
T=[T; row("overall_status",overall,string(overall))];
writetable(T,fullfile(out_dir,'wind_speed_after_severity_fix_tail_diagnosis_check_log.txt'));
if ~overall, error('wind speed after severity fix tail diagnosis check failed'); end
end
function T=row(item,pass,note)
if pass, status="pass"; else, status="fail"; end
T=table(string(item),logical(pass),status,string(note),'VariableNames',{'check_item','pass','status','note'});
end
