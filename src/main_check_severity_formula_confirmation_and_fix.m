function main_check_severity_formula_confirmation_and_fix()
root = fileparts(fileparts(mfilename('fullpath')));
out_dir = fullfile(root, 'results', 'calibration', 'severity_formula');
checks = {};
files = ["severity_formula_manual_confirmation_record.csv","post_severity_formula_audit_action_v2.csv", ...
    "wind_speed_paper_confirmed_severity_recompute_from_existing_trace.csv", ...
    "wind_speed_after_severity_fix_var_metrics.csv","wind_speed_before_after_severity_fix_comparison.csv", ...
    "wind_speed_after_severity_fix_to_paper_gap.csv","post_severity_formula_fix_action.csv"];
for i=1:numel(files)
    checks{end+1,1}=row(files(i), exist(fullfile(out_dir,files(i)),'file')==2, fullfile(out_dir,files(i))); %#ok<AGROW>
end
checks{end+1,1}=row("calc_basic_risk_metrics_paper_confirmed.m", exist(fullfile(root,'src','risk','calc_basic_risk_metrics_paper_confirmed.m'),'file')==2, "paper-confirmed severity function exists");
cfg_text = string(fileread(fullfile(root,'config','base_config.m')));
checks{end+1,1}=row("cfg.severity_formula_mode", contains(cfg_text,"cfg.severity_formula_mode"), "config contains severity formula mode");
smoke_files = dir(fullfile(out_dir,'severity_vector_trace_smoke','*','severity_vector_trace.csv'));
checks{end+1,1}=row("severity_vector_trace_smoke", ~isempty(smoke_files), "smoke/reconstructed vector traces exist");
after_files = dir(fullfile(out_dir,'wind_speed_after_severity_fix_diagnostic_rerun','*','*','tables','severity_vector_trace.csv'));
checks{end+1,1}=row("wind_speed_after_severity_fix_diagnostic_rerun", ~isempty(after_files), "after-fix severity traces exist");
checks{end+1,1}=row("guard_no_final_summary", true, "No final_summary called by this check");
checks{end+1,1}=row("guard_no_local_search", true, "No local search called");
checks{end+1,1}=row("guard_no_parameter_tuning", true, "No parameter refinement");
checks{end+1,1}=row("guard_no_full_7scenario_formal_pilot", true, "No full 7-scenario formal pilot");
T = vertcat(checks{:});
overall = all(T.pass);
T = [T; row("overall_status", overall, ternary(overall,"pass","fail"))];
writetable(T, fullfile(out_dir,'severity_formula_confirmation_and_fix_check_log.txt'));
if ~overall
    error('severity formula confirmation/fix check failed');
end
end

function T=row(item,pass,note)
T=table(string(item),logical(pass),ternary(pass,"pass","fail"),string(note),'VariableNames',{'check_item','pass','status','note'});
end

function s=ternary(cond,a,b)
if cond, s=string(a); else, s=string(b); end
end
