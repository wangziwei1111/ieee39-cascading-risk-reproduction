function main_compare_current_vs_candidate_target_trends()
project_root=fileparts(fileparts(mfilename('fullpath'))); diag_dir=fullfile(project_root,'results','calibration','diagnostics');
cur_path=fullfile(project_root,'paper_inputs','filled','calibration_target_benchmark.csv'); cand_path=fullfile(diag_dir,'calibration_target_benchmark_candidate_v2.csv');
out_path=fullfile(diag_dir,'current_vs_candidate_target_trend_comparison.csv');
if exist(cur_path,'file')~=2 || exist(cand_path,'file')~=2; writetable(table(),out_path); return; end
C=read_csv(cur_path); V=read_csv(cand_path);
groups=unique(C.target_group); metrics=unique(C.metric_name);
target_group=strings(0,1); metric_name=strings(0,1); current_direction_summary=strings(0,1); candidate_direction_summary=strings(0,1); direction_changed=[]; current_values=strings(0,1); candidate_values=strings(0,1); note=strings(0,1);
for g=groups'
    for m=metrics'
        c=C(string(C.target_group)==g & string(C.metric_name)==m,:); v=V(string(V.target_group)==g & string(V.metric_name)==m & V.recommended_use,:);
        if isempty(c); continue; end
        cs=direction_summary(c); vs=direction_summary(v);
        target_group(end+1,1)=g; metric_name(end+1,1)=m; current_direction_summary(end+1,1)=cs; candidate_direction_summary(end+1,1)=vs; direction_changed(end+1,1)=~strcmp(cs,vs); current_values(end+1,1)=values_text(c); candidate_values(end+1,1)=values_text(v); note(end+1,1)="candidate_v2 preserves only high-confidence 0.95 mappings"; %#ok<AGROW>
    end
end
out=table(target_group,metric_name,current_direction_summary,candidate_direction_summary,direction_changed,current_values,candidate_values,note);
writetable(out,out_path);
end
function s=direction_summary(T)
if isempty(T); s="no_candidate_values"; return; end
[~,ord]=sort(string(T.scenario_id)); vals=T.paper_value(ord); ids=string(T.scenario_id(ord));
if numel(vals)<2; s="single_value"; return; end
if any(contains(ids,"concentrated")) && any(contains(ids,"distributed"))
    c=vals(contains(ids,"concentrated")); d=vals(contains(ids,"distributed")); s="distributed_minus_concentrated="+string(d(1)-c(1));
elseif any(contains(ids,"wind_speed")) || any(contains(ids,"penetration"))
    s="last_minus_first="+string(vals(end)-vals(1));
else
    s="direction_unknown";
end
end
function txt=values_text(T)
if isempty(T); txt=""; return; end
parts=strings(height(T),1); for i=1:height(T); parts(i)=string(T.scenario_id(i))+":"+string(T.paper_value(i)); end; txt=strjoin(parts,";");
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
