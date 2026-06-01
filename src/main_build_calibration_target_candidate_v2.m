function main_build_calibration_target_candidate_v2()
project_root=fileparts(fileparts(mfilename('fullpath'))); diag_dir=fullfile(project_root,'results','calibration','diagnostics');
audit_path=fullfile(diag_dir,'calibration_target_mapping_audit.csv'); target_path=fullfile(project_root,'paper_inputs','filled','calibration_target_benchmark.csv');
out_path=fullfile(diag_dir,'calibration_target_benchmark_candidate_v2.csv');
if exist(audit_path,'file')~=2 || exist(target_path,'file')~=2; writetable(table(),out_path); return; end
A=read_csv(audit_path); T=read_csv(target_path);
target_group=A.target_group; scenario_id=A.scenario_id; metric_name=A.metric_name; paper_value=A.matched_paper_table_value;
confidence_sigma=A.matched_confidence_sigma; paper_table_id=A.matched_paper_table_id; paper_scenario_label=A.matched_scenario_label;
weight=zeros(height(A),1); priority=zeros(height(A),1);
for i=1:height(A)
    idx=find(string(T.target_group)==string(target_group(i)) & string(T.scenario_id)==string(scenario_id(i)) & string(T.metric_name)==string(metric_name(i)),1);
    if ~isempty(idx); weight(i)=T.weight(idx); priority(i)=T.priority(idx); end
end
unit_convention=repmat("paper_table_display_value",height(A),1);
mapping_confidence=strings(height(A),1); source_note=strings(height(A),1); change_from_current_target=strings(height(A),1); recommended_use=false(height(A),1);
for i=1:height(A)
    if string(A.mapping_status(i))=="exact_match"
        mapping_confidence(i)="high"; recommended_use(i)=true; source_note(i)="exact mapping from paper benchmark index";
    else
        mapping_confidence(i)="low"; recommended_use(i)=false; source_note(i)="mapping issue: "+string(A.mapping_status(i));
    end
    if abs(A.value_difference(i))<1e-9
        change_from_current_target(i)="unchanged";
    else
        change_from_current_target(i)="value_changed_from_current_target";
    end
    if isnan(confidence_sigma(i)) || abs(confidence_sigma(i)-0.95)>1e-12
        recommended_use(i)=false; mapping_confidence(i)="sigma_not_0p95";
    end
end
out=table(target_group,scenario_id,metric_name,paper_value,confidence_sigma,paper_table_id,paper_scenario_label,weight,priority,unit_convention,mapping_confidence,source_note,change_from_current_target,recommended_use);
writetable(out,out_path);
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
