function main_summarize_after_severity_fix_tail_initial_branch_composition()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula');
T=readtable(fullfile(out_dir,'wind_speed_after_severity_fix_tail_samples.csv'),'TextType','string','Delimiter',',');
T=T(T.tail_flag==1,:);
summary_rows={};
groups=unique(T(:,{'parameter_set_id','scenario_id','metric_name','initial_branch'}),'rows');
for i=1:height(groups)
    m = T.parameter_set_id==groups.parameter_set_id(i) & T.scenario_id==groups.scenario_id(i) & T.metric_name==groups.metric_name(i) & T.initial_branch==groups.initial_branch(i);
    sub=T(m,:);
    summary_rows{end+1,1}=table(groups.parameter_set_id(i),groups.scenario_id(i),groups.metric_name(i),groups.initial_branch(i), ...
        height(sub),sum(sub.R_metric_display,'omitnan'),mean(sub.R_metric_display,'omitnan'),max(sub.R_metric_display,[],'omitnan'), ...
        mean(sub.initial_line_probability,'omitnan'),mean(sub.chain_transition_probability,'omitnan'), ...
        mean(sub.R_LLR_display,'omitnan'),mean(sub.R_LFOR_display,'omitnan'),mean(sub.R_NVOR_display,'omitnan'),mean(sub.R_CRI_display,'omitnan'), ...
        NaN,"Tail initial-branch composition after paper-confirmed severity fix.", ...
        'VariableNames',{'parameter_set_id','scenario_id','metric_name','initial_branch','tail_sample_count','tail_risk_sum','tail_risk_mean','tail_risk_max','mean_initial_line_probability','mean_chain_transition_probability','mean_R_LLR','mean_R_LFOR','mean_R_NVOR','mean_R_CRI','dominance_rank','note'}); %#ok<AGROW>
end
S=vertcat(summary_rows{:});
S=add_rank(S);
writetable(S,fullfile(out_dir,'wind_speed_after_severity_fix_tail_initial_branch_summary.csv'));
writetable(build_delta(S),fullfile(out_dir,'wind_speed_after_severity_fix_tail_initial_branch_delta.csv'));
end

function S=add_rank(S)
for p=unique(S.parameter_set_id).'
 for sc=unique(S.scenario_id).'
  for m=unique(S.metric_name).'
   idx=find(S.parameter_set_id==p & S.scenario_id==sc & S.metric_name==m);
   [~,ord]=sort(S.tail_risk_sum(idx),'descend');
   ranks=NaN(numel(idx),1); ranks(ord)=(1:numel(idx)).';
   S.dominance_rank(idx)=ranks;
  end
 end
end
end

function D=build_delta(S)
keys=unique(S(:,{'parameter_set_id','metric_name','initial_branch'}),'rows');
rows={};
for i=1:height(keys)
    a=getrow(S,keys(i,:),"wind_speed_11_28"); b=getrow(S,keys(i,:),"wind_speed_12_00");
    dominant="no_clear_change";
    if isempty(a) && ~isempty(b), dominant="initial_branch_enters_tail_only_at_12mps";
    elseif ~isempty(a)&&~isempty(b)
        dp=picknum(b,'mean_chain_transition_probability')-picknum(a,'mean_chain_transition_probability');
        ds=picknum(b,'tail_risk_mean')-picknum(a,'tail_risk_mean');
        if dp>0 && ds>0, dominant="both_probability_and_severity";
        elseif dp>0, dominant="chain_probability_increase";
        elseif ds>0, dominant="severity_increase";
        end
    end
    rows{end+1,1}=table(keys.parameter_set_id(i),keys.metric_name(i),keys.initial_branch(i), ...
        picknum(a,'tail_sample_count'),picknum(b,'tail_sample_count'),picknum(a,'tail_risk_mean'),picknum(b,'tail_risk_mean'), ...
        picknum(b,'tail_risk_mean')-picknum(a,'tail_risk_mean'),picknum(a,'mean_chain_transition_probability'),picknum(b,'mean_chain_transition_probability'), ...
        picknum(b,'mean_chain_transition_probability')-picknum(a,'mean_chain_transition_probability'),picknum(a,'mean_R_CRI'),picknum(b,'mean_R_CRI'), ...
        picknum(b,'mean_R_CRI')-picknum(a,'mean_R_CRI'),dominant,"11.28 vs 12.00 tail initial-branch delta.", ...
        'VariableNames',{'parameter_set_id','metric_name','initial_branch','tail_count_11_28','tail_count_12_00','tail_risk_mean_11_28','tail_risk_mean_12_00','delta_tail_risk_mean','chain_probability_mean_11_28','chain_probability_mean_12_00','delta_chain_probability','severity_mean_11_28','severity_mean_12_00','delta_severity','dominant_change','note'}); %#ok<AGROW>
end
D=vertcat(rows{:});
end

function r=getrow(S,key,sc)
r=S(S.parameter_set_id==key.parameter_set_id & S.metric_name==key.metric_name & S.initial_branch==key.initial_branch & S.scenario_id==sc,:);
end
function v=picknum(T,name)
if isempty(T), v=NaN; else, v=T.(name)(1); end
end
