function main_summarize_after_severity_fix_tail_candidate_branch_composition()
root=fileparts(fileparts(mfilename('fullpath')));
out_dir=fullfile(root,'results','calibration','severity_formula');
source_root=fullfile(root,'results','calibration','wind_speed_component_diagnostic_rerun');
Tail=readtable(fullfile(out_dir,'wind_speed_after_severity_fix_tail_samples.csv'),'TextType','string','Delimiter',',');
Tail=Tail(Tail.tail_flag==1,:);
rows={};
for p=unique(Tail.parameter_set_id).'
 for sc=unique(Tail.scenario_id).'
  cand_file=fullfile(source_root,p,sc,'tables','candidate_probability_trace.csv');
  line_file=fullfile(source_root,p,sc,'tables','line_probability_component_trace.csv');
  if exist(cand_file,'file')~=2 || exist(line_file,'file')~=2, continue; end
  C=readtable(cand_file,'TextType','string','Delimiter',',');
  L=readtable(line_file,'TextType','string','Delimiter',',');
  for m=unique(Tail.metric_name).'
    chains=Tail(Tail.parameter_set_id==p & Tail.scenario_id==sc & Tail.metric_name==m,:);
    Csub=filter_chain(C,chains); Lsub=filter_chain(L,chains);
    branches=unique(Csub.candidate_branch);
    for b=branches.'
        c=Csub(Csub.candidate_branch==b,:); l=Lsub(Lsub.candidate_branch==b,:);
        rows{end+1,1}=table(p,sc,m,b,height(chains),height(c),sum(c.selected==1),mean(c.candidate_probability,'omitnan'),pct(c.candidate_probability,95), ...
            mean(getcol(l,'P_L'),'omitnan'),mean(getcol(l,'P1'),'omitnan'),mean(getcol(l,'P2'),'omitnan'),mean(getcol(l,'P3'),'omitnan'), ...
            mean(getcol(l,'P_flow'),'omitnan'),mean(getcol(l,'P_HF_L'),'omitnan'),mean(getcol(l,'line_loading_pu'),'omitnan'),NaN, ...
            "Tail candidate composition from existing candidate and line probability traces.", ...
            'VariableNames',{'parameter_set_id','scenario_id','metric_name','candidate_branch','tail_chain_count','candidate_occurrence_count','selected_count','mean_candidate_probability','p95_candidate_probability','mean_P_L','mean_P1','mean_P2','mean_P3','mean_P_flow','mean_P_HF_L','mean_line_loading_pu','tail_selected_rank','note'}); %#ok<AGROW>
    end
  end
 end
end
S=vertcat(rows{:}); S=rank_selected(S);
writetable(S,fullfile(out_dir,'wind_speed_after_severity_fix_tail_candidate_branch_summary.csv'));
writetable(delta_table(S),fullfile(out_dir,'wind_speed_after_severity_fix_tail_candidate_branch_delta.csv'));
end

function T=filter_chain(T,chains)
keep=false(height(T),1);
for i=1:height(chains)
    keep=keep | (T.initial_branch==chains.initial_branch(i)&T.trial_id==chains.trial_id(i));
end
T=T(keep,:);
end
function v=getcol(T,name)
if isempty(T)||~ismember(name,T.Properties.VariableNames), v=NaN(height(T),1); else, v=T.(name); end
end
function q=pct(x,p)
x=sort(x(~isnan(x))); if isempty(x), q=NaN; else, q=x(max(1,ceil(p/100*numel(x)))); end
end
function S=rank_selected(S)
for p=unique(S.parameter_set_id).', for sc=unique(S.scenario_id).', for m=unique(S.metric_name).'
 idx=find(S.parameter_set_id==p&S.scenario_id==sc&S.metric_name==m); [~,o]=sort(S.selected_count(idx),'descend'); r=NaN(numel(idx),1); r(o)=(1:numel(idx)).'; S.tail_selected_rank(idx)=r;
end, end, end
end
function D=delta_table(S)
keys=unique(S(:,{'parameter_set_id','metric_name','candidate_branch'}),'rows'); rows={};
for i=1:height(keys)
 a=getrow(S,keys(i,:),"wind_speed_11_28"); b=getrow(S,keys(i,:),"wind_speed_12_00");
 driver="no_clear_driver";
 if isempty(a)&&~isempty(b), driver="only_appears_in_12mps_tail";
 elseif ~isempty(a)&&~isempty(b)
  if picknum(b,'selected_count')>picknum(a,'selected_count'), driver="selected_more_often_at_12mps"; end
  if picknum(b,'mean_line_loading_pu')>picknum(a,'mean_line_loading_pu'), driver="line_loading_increase"; end
  if picknum(b,'mean_P2')>picknum(a,'mean_P2'), driver="P2_increase"; end
  if picknum(b,'mean_P1')>picknum(a,'mean_P1'), driver="P1_increase"; end
  if picknum(b,'mean_P_L')>picknum(a,'mean_P_L'), driver="P_L_increase"; end
 end
 rows{end+1,1}=table(keys.parameter_set_id(i),keys.metric_name(i),keys.candidate_branch(i),picknum(a,'candidate_occurrence_count'),picknum(b,'candidate_occurrence_count'),picknum(a,'selected_count'),picknum(b,'selected_count'),picknum(a,'mean_P_L'),picknum(b,'mean_P_L'),picknum(b,'mean_P_L')-picknum(a,'mean_P_L'),picknum(a,'mean_P1'),picknum(b,'mean_P1'),picknum(b,'mean_P1')-picknum(a,'mean_P1'),picknum(a,'mean_P2'),picknum(b,'mean_P2'),picknum(b,'mean_P2')-picknum(a,'mean_P2'),picknum(a,'mean_line_loading_pu'),picknum(b,'mean_line_loading_pu'),picknum(b,'mean_line_loading_pu')-picknum(a,'mean_line_loading_pu'),driver,"11.28 vs 12.00 tail candidate delta.",'VariableNames',{'parameter_set_id','metric_name','candidate_branch','tail_occurrence_count_11_28','tail_occurrence_count_12_00','selected_count_11_28','selected_count_12_00','mean_P_L_11_28','mean_P_L_12_00','delta_P_L','mean_P1_11_28','mean_P1_12_00','delta_P1','mean_P2_11_28','mean_P2_12_00','delta_P2','mean_line_loading_11_28','mean_line_loading_12_00','delta_line_loading','candidate_tail_driver','note'}); %#ok<AGROW>
end
D=vertcat(rows{:});
end
function r=getrow(S,k,sc)
r=S(S.parameter_set_id==k.parameter_set_id&S.metric_name==k.metric_name&S.candidate_branch==k.candidate_branch&S.scenario_id==sc,:);
end
function v=picknum(T,name)
if isempty(T), v=NaN; else, v=T.(name)(1); end
end
