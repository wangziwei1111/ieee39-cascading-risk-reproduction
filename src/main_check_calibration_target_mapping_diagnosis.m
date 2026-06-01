function main_check_calibration_target_mapping_diagnosis()
project_root=fileparts(fileparts(mfilename('fullpath'))); diag_dir=fullfile(project_root,'results','calibration','diagnostics'); ensure_dir(diag_dir);
log_path=fullfile(diag_dir,'calibration_target_mapping_diagnosis_check_log.txt');
files=["paper_benchmark_calibration_index.csv","calibration_target_mapping_audit.csv","pilot_scenario_mapping_audit.csv","calibration_target_benchmark_candidate_v2.csv","current_vs_candidate_target_trend_comparison.csv"];
lines="calibration target mapping diagnosis check started: "+string(datetime('now')); ok=true;
for f=files
    p=fullfile(diag_dir,f); e=exist(p,'file')==2; ok=ok&&e; lines(end+1)=p+" exists="+string(e); %#ok<AGROW>
end
doc=fullfile(project_root,'docs','calibration_target_mapping_diagnosis.md'); e=exist(doc,'file')==2; ok=ok&&e; lines(end+1)=doc+" exists="+string(e);
lines(end+1)="local_search_results_absent="+string(exist(fullfile(project_root,'results','calibration','local_search_results.csv'),'file')~=2);
lines(end+1)="final_summary_not_written_by_this_check=true";
cand_path=fullfile(diag_dir,'calibration_target_benchmark_candidate_v2.csv');
cur_path=fullfile(project_root,'paper_inputs','filled','calibration_target_benchmark.csv');
if exist(cand_path,'file')==2 && exist(cur_path,'file')==2
    C=read_csv(cur_path); V=read_csv(cand_path); usable=sum(V.recommended_use); lines(end+1)="candidate_v2_usable_target_count="+string(usable); lines(end+1)="current_target_count="+string(height(C));
    if usable < height(C); lines(end+1)="warning=do not calibrate: candidate_v2 has fewer usable targets than current target table"; end
end
pilot_path=fullfile(diag_dir,'pilot_scenario_mapping_audit.csv');
if exist(pilot_path,'file')==2
    P=read_csv(pilot_path); issue=sum(string(P.issue_type)~="needs_config_file_confirmation" & string(P.issue_type)~="none"); lines(end+1)="pilot_scenario_issue_count="+string(issue);
    if issue>0; lines(end+1)="warning=fix pilot scenarios before calibration"; end
end
if ok; lines(end+1)="check_status=passed"; else; lines(end+1)="check_status=failed"; end
write_lines(log_path,lines); fprintf('%s\n',lines); if ~ok; error('calibration target mapping diagnosis check failed'); end
end
function ensure_dir(path_value); if exist(path_value,'dir')~=7; mkdir(path_value); end; end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
function write_lines(path_value,lines); fid=fopen(path_value,'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); for i=1:numel(lines); fprintf(fid,'%s\n',lines(i)); end; end
