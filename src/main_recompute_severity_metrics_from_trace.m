function main_recompute_severity_metrics_from_trace()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula'); ensure_dir(out_dir);
src_root=fullfile(root,'results','calibration','wind_speed_component_diagnostic_rerun');
psets=["high_hidden_failure","benchmark_calibrated_seed"]; scens=["wind_speed_11_28","wind_speed_12_00"];
rows={};
for p=1:numel(psets)
 for s=1:numel(scens)
  T=readtable(fullfile(src_root,psets(p),scens(s),'tables','severity_component_trace.csv'),'TextType','string','Delimiter',',');
  for i=1:height(T)
   LLR=T.total_load_shed_frac(i);
   LFOR=max(T.max_line_loading_pu(i)-1,0)*max(T.overloaded_branch_count(i),1);
   NVOR=T.max_voltage_deviation_pu(i)*max(T.voltage_violation_bus_count(i),1);
   CRI=0.6*LLR+0.2*LFOR+0.2*NVOR;
   diffs=[T.basic_LLR(i)-LLR,T.basic_LFOR(i)-LFOR,T.basic_NVOR(i)-NVOR,T.basic_CRI(i)-CRI];
   rows{end+1,1}=table(psets(p),scens(s),T.initial_branch(i),T.trial_id(i),T.stage_id(i), ...
    T.basic_LLR(i),LLR,diffs(1),T.basic_LFOR(i),LFOR,diffs(2),T.basic_NVOR(i),NVOR,diffs(3),T.basic_CRI(i),CRI,diffs(4), ...
    T.total_load_shed_frac(i),T.max_line_loading_pu(i),T.max_voltage_deviation_pu(i),T.overloaded_branch_count(i),T.voltage_violation_bus_count(i), ...
    "code_implementation_recompute","normalization_from_trace_fields",issue(diffs), ...
    "Offline recompute of current basic severity formulas; not formal paper confirmation.", ...
    'VariableNames',{'parameter_set_id','scenario_id','initial_branch','trial_id','stage_id','recorded_basic_LLR','recomputed_LLR','diff_LLR','recorded_basic_LFOR','recomputed_LFOR','diff_LFOR','recorded_basic_NVOR','recomputed_NVOR','diff_NVOR','recorded_basic_CRI','recomputed_CRI','diff_CRI','total_load_shed_frac','max_line_loading_pu','max_voltage_deviation_pu','overloaded_branch_count','voltage_violation_bus_count','severity_formula_status','normalization_status','issue_type','note'}); %#ok<AGROW>
  end
 end
end
writetable(vertcat(rows{:}),fullfile(out_dir,'severity_metric_recompute_audit.csv'));
end
function s=issue(d)
if any(isnan(d)), s="missing_required_field"; elseif abs(d(1))>1e-10, s="LLR_mismatch"; elseif abs(d(2))>1e-10, s="LFOR_mismatch"; elseif abs(d(3))>1e-10, s="NVOR_mismatch"; elseif abs(d(4))>1e-10, s="CRI_weight_mismatch"; else, s="no_issue"; end
end
function ensure_dir(path), if exist(path,'dir')~=7, mkdir(path); end, end
