function main_diagnose_wind_speed_severity_response()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula'); ensure_dir(out_dir);
T=readtable(fullfile(out_dir,'severity_metric_recompute_audit.csv'),'TextType','string','Delimiter',',');
metrics=["LLR","LFOR","NVOR","CRI"]; rows={}; drows={};
for p=unique(T.parameter_set_id)'
 for m=metrics
  col="recorded_basic_"+m; rcol="recomputed_"+m;
  for scen=unique(T.scenario_id)'
   S=T(T.parameter_set_id==p & T.scenario_id==scen,:);
   vals=S.(col); rvals=S.(rcol);
   rows{end+1,1}=table(p,m,scen,height(S),mean(vals,'omitnan'),median(vals,'omitnan'),prctile(vals,95),max(vals,[],'omitnan'),mean(rvals,'omitnan'),prctile(rvals,95), ...
    sum(vals>=prctile(vals,95)),mean(vals(vals>=prctile(vals,95)),'omitnan'),prctile(vals(vals>=prctile(vals,95)),95), ...
    "computed_from_existing_trace","Diagnostic severity response summary.", ...
    'VariableNames',{'parameter_set_id','metric_name','scenario_id','sample_count','mean_recorded_severity','median_recorded_severity','p95_recorded_severity','max_recorded_severity','mean_recomputed_severity','p95_recomputed_severity','tail_sample_count','tail_mean_severity','tail_p95_severity','severity_status','note'}); %#ok<AGROW>
  end
 end
 A=T(T.parameter_set_id==p & T.scenario_id=="wind_speed_11_28",:); B=T(T.parameter_set_id==p & T.scenario_id=="wind_speed_12_00",:);
 keys=intersect(keyset(A),keyset(B));
 for k=1:numel(keys)
  parts=split(keys(k),"_"); ib=str2double(parts(1)); tr=str2double(parts(2)); st=str2double(parts(3));
  a=A(A.initial_branch==ib&A.trial_id==tr&A.stage_id==st,:); b=B(B.initial_branch==ib&B.trial_id==tr&B.stage_id==st,:);
  for m=metrics
   col="recorded_basic_"+m; rcol="recomputed_"+m;
   drows{end+1,1}=table(p,m,ib,tr,a.(col)(1),b.(col)(1),b.(col)(1)-a.(col)(1),a.(rcol)(1),b.(rcol)(1),b.(rcol)(1)-a.(rcol)(1), ...
    b.total_load_shed_frac(1)-a.total_load_shed_frac(1),b.max_line_loading_pu(1)-a.max_line_loading_pu(1),b.max_voltage_deviation_pu(1)-a.max_voltage_deviation_pu(1), ...
    b.overloaded_branch_count(1)-a.overloaded_branch_count(1),b.voltage_violation_bus_count(1)-a.voltage_violation_bus_count(1),driver(m,b.(col)(1)-a.(col)(1),b,a), ...
    "Paired wind-speed severity delta from existing traces.", ...
    'VariableNames',{'parameter_set_id','metric_name','initial_branch','trial_id','recorded_11_28','recorded_12_00','delta_recorded_12_minus_11','recomputed_11_28','recomputed_12_00','delta_recomputed_12_minus_11','delta_load_shed_frac','delta_max_line_loading_pu','delta_max_voltage_deviation_pu','delta_overloaded_branch_count','delta_voltage_violation_bus_count','severity_driver','note'}); %#ok<AGROW>
  end
 end
end
writetable(vertcat(rows{:}),fullfile(out_dir,'wind_speed_severity_response_summary.csv'));
writetable(vertcat(drows{:}),fullfile(out_dir,'wind_speed_severity_response_delta.csv'));
end
function keys=keyset(T), keys=string(T.initial_branch)+"_"+string(T.trial_id)+"_"+string(T.stage_id); end
function s=driver(m,delta,b,a)
if delta<=0, s="no_severity_increase"; elseif m=="LLR"||b.total_load_shed_frac(1)>a.total_load_shed_frac(1), s="load_shed_component"; elseif m=="LFOR"||b.max_line_loading_pu(1)>a.max_line_loading_pu(1), s="line_overload_component"; elseif m=="NVOR"||b.max_voltage_deviation_pu(1)>a.max_voltage_deviation_pu(1), s="voltage_violation_component"; elseif m=="CRI", s="CRI_weighting"; else, s="mixed_severity"; end
end
function ensure_dir(path), if exist(path,'dir')~=7, mkdir(path); end, end
