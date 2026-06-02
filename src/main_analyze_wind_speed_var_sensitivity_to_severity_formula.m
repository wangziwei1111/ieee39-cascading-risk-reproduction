function main_analyze_wind_speed_var_sensitivity_to_severity_formula()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula'); ensure_dir(out_dir);
src_root=fullfile(root,'results','calibration','wind_speed_component_diagnostic_rerun');
T=readtable(fullfile(out_dir,'severity_metric_recompute_audit.csv'),'TextType','string','Delimiter',',');
psets=unique(T.parameter_set_id); metrics=["LLR","LFOR","NVOR","CRI"]; sigmas=[0.90;0.95;0.98]; rows={};
for p=psets'
 for variant=["recorded_severity","recomputed_severity"]
  for m=metrics
   for sg=1:numel(sigmas)
    v11=var_proxy(root,src_root,T,p,"wind_speed_11_28",m,variant,sigmas(sg));
    v12=var_proxy(root,src_root,T,p,"wind_speed_12_00",m,variant,sigmas(sg));
    dirn=dir_text(v12-v11);
    rows{end+1,1}=table(p,m,sigmas(sg),variant,v11,v12,dirn,"12mps_expected_lower_or_not_higher",dirn=="matches_paper_direction","offline_proxy", ...
     "Uses existing chain transition probability and severity trace; not formal VaR.", ...
     'VariableNames',{'parameter_set_id','metric_name','sigma','variant','wind_speed_11_28_var','wind_speed_12_00_var','direction','paper_expected_direction','direction_match','proxy_status','note'}); %#ok<AGROW>
   end
  end
 end
end
writetable(vertcat(rows{:}),fullfile(out_dir,'wind_speed_var_sensitivity_to_severity_formula.csv'));
end
function v=var_proxy(root,src_root,T,pset,scen,metric,variant,sigma)
S=T(T.parameter_set_id==pset & T.scenario_id==scen,:);
M=readtable(fullfile(src_root,pset,scen,'tables','markov_chain_summary.csv'),'TextType','string','Delimiter',',');
if variant=="recorded_severity", col="recorded_basic_"+metric; else, col="recomputed_"+metric; end
if metric=="CRI" && variant=="recomputed_severity", values=S.recomputed_CRI; else, values=S.(col); end
keys=string(S.initial_branch)+"_"+string(S.trial_id);
[G,k]=findgroups(keys);
sev=splitapply(@max,values,G);
ib=zeros(numel(k),1); tr=zeros(numel(k),1);
for i=1:numel(k), parts=split(k(i),"_"); ib(i)=str2double(parts(1)); tr(i)=str2double(parts(2)); end
P=table(ib,tr,sev,'VariableNames',{'initial_branch','trial_id','severity'});
J=innerjoin(P,M(:,{'initial_branch','trial_id','chain_transition_probability'}),'Keys',{'initial_branch','trial_id'});
risk=J.severity .* J.chain_transition_probability;
v=quantile(risk,sigma);
end
function s=dir_text(delta), if delta<0, s="matches_paper_direction"; elseif delta>0, s="12mps_higher_than_11p28"; else, s="flat"; end, end
function ensure_dir(path), if exist(path,'dir')~=7, mkdir(path); end, end
