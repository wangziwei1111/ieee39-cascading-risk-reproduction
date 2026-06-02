function main_analyze_wind_speed_baseflow_tail_correlation_after_severity_fix()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula');
source_root=fullfile(root,'results','calibration','wind_speed_component_diagnostic_rerun');
Tail=readtable(fullfile(out_dir,'wind_speed_after_severity_fix_tail_samples.csv'),'TextType','string','Delimiter',',');
Tail=Tail(Tail.tail_flag==1,:);
rows={}; delta_rows={};
for p=unique(Tail.parameter_set_id).'
 for sc=unique(Tail.scenario_id).'
  line_file=fullfile(source_root,p,sc,'tables','line_probability_component_trace.csv');
  if exist(line_file,'file')~=2, continue; end
  L=readtable(line_file,'TextType','string','Delimiter',',');
  tailChains=Tail(Tail.parameter_set_id==p&Tail.scenario_id==sc,:);
  Tline=filter_chain(L,tailChains);
  for b=unique(Tline.candidate_branch).'
    sub=Tline(Tline.candidate_branch==b,:);
    loading=getcol(sub,'line_loading_pu'); pl=getcol(sub,'P_L');
    risk=chain_risk_for_rows(sub,tailChains);
    rows{end+1,1}=table(p,sc,b,mean(getcol(L(L.candidate_branch==b,:),'line_loading_pu'),'omitnan'),mean(loading,'omitnan'),mean(pl,'omitnan'),mean(risk,'omitnan'),corrsafe(loading,pl),corrsafe(loading,risk),classify(corrsafe(loading,risk)), ...
        "Base/stage loading and tail risk correlation from existing line component trace.", ...
        'VariableNames',{'parameter_set_id','scenario_id','candidate_branch','mean_base_or_stage_line_loading','mean_tail_line_loading','tail_probability_mean','tail_risk_mean','correlation_loading_probability','correlation_loading_tail_risk','baseflow_driver_status','note'}); %#ok<AGROW>
  end
 end
end
C=vertcat(rows{:});
writetable(C,fullfile(out_dir,'wind_speed_after_severity_fix_baseflow_tail_correlation.csv'));
branches=unique(C.candidate_branch);
for b=branches.'
    a=C(C.scenario_id=="wind_speed_11_28"&C.candidate_branch==b,:);
    d=C(C.scenario_id=="wind_speed_12_00"&C.candidate_branch==b,:);
    if isempty(a)||isempty(d), continue; end
    line11=mean(a.mean_tail_line_loading,'omitnan'); line12=mean(d.mean_tail_line_loading,'omitnan');
    p11=mean(a.tail_probability_mean,'omitnan'); p12=mean(d.tail_probability_mean,'omitnan');
    r11=mean(a.tail_risk_mean,'omitnan'); r12=mean(d.tail_risk_mean,'omitnan');
    interp="no_baseflow_relation";
    if line12>line11 && r12>r11, interp="higher_wind_output_increases_loading_and_tail_risk";
    elseif line12<line11 && r12>r11, interp="higher_wind_output_reduces_loading_but_tail_still_higher";
    elseif isnan(line11)||isnan(line12), interp="insufficient_data"; end
    delta_rows{end+1,1}=table(b,line11,line12,line12-line11,p11,p12,p12-p11,r11,r12,r12-r11,interp,"Aggregated across parameter sets and metrics.", ...
        'VariableNames',{'candidate_branch','line_loading_11_28','line_loading_12_00','delta_line_loading','P_L_11_28','P_L_12_00','delta_P_L','tail_risk_11_28','tail_risk_12_00','delta_tail_risk','interpretation','note'}); %#ok<AGROW>
end
writetable(vertcat_or_empty(delta_rows),fullfile(out_dir,'wind_speed_after_severity_fix_baseflow_delta_summary.csv'));
end

function T=filter_chain(T,chains)
keep=false(height(T),1);
for i=1:height(chains), keep=keep | (T.initial_branch==chains.initial_branch(i)&T.trial_id==chains.trial_id(i)); end
T=T(keep,:);
end
function v=getcol(T,name)
if isempty(T)||~ismember(name,T.Properties.VariableNames), v=NaN(height(T),1); else, v=T.(name); end
end
function risk=chain_risk_for_rows(L,tail)
risk=NaN(height(L),1);
for i=1:height(L)
 idx=tail.initial_branch==L.initial_branch(i)&tail.trial_id==L.trial_id(i);
 if any(idx), risk(i)=tail.R_CRI_display(find(idx,1)); end
end
end
function c=corrsafe(a,b)
mask=~isnan(a)&~isnan(b);
if sum(mask)<3, c=NaN; else, C=corrcoef(a(mask),b(mask)); c=C(1,2); end
end
function s=classify(c)
if isnan(c), s="insufficient_data"; elseif c>0.3, s="loading_correlated_with_tail_risk"; else, s="weak_or_no_loading_tail_correlation"; end
end
function T=vertcat_or_empty(rows)
if isempty(rows), T=table(); else, T=vertcat(rows{:}); end
end
