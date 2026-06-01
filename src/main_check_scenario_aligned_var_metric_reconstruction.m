function main_check_scenario_aligned_var_metric_reconstruction()
project_root=fileparts(fileparts(mfilename('fullpath'))); diag_dir=fullfile(project_root,'results','calibration','diagnostics'); ensure_dir(diag_dir);
log_path=fullfile(diag_dir,'scenario_aligned_var_metric_reconstruction_check_log.txt');
files=["scenario_aligned_chain_var_metrics.csv","scenario_aligned_var_to_paper_gap.csv","scenario_aligned_var_score_summary.csv","paper_table_unit_convention_diagnosis.csv","selected_calibration_metric_source.csv"];
lines="scenario-aligned VaR metric reconstruction check started: "+string(datetime('now')); ok=true;
for f=files
    p=fullfile(diag_dir,f); e=exist(p,'file')==2; ok=ok&&e; lines(end+1)=p+" exists="+string(e); %#ok<AGROW>
end
local_search=fullfile(project_root,'results','calibration','local_search_results.csv'); lines(end+1)="local_search_results_absent="+string(exist(local_search,'file')~=2);
lines(end+1)="final_summary_not_written_by_this_check=true";
sel_path=fullfile(diag_dir,'selected_calibration_metric_source.csv');
if exist(sel_path,'file')==2
    S=read_csv(sel_path);
    if height(S)>0
        lines(end+1)="selected_go_no_go="+string(S.go_no_go(1));
        if string(S.go_no_go(1))=="do_not_calibrate_parameters"
            lines(end+1)="decision=do not continue parameter calibration";
        elseif string(S.go_no_go(1))=="needs_formal_rerun_before_local_search"
            lines(end+1)="decision=next step should be formal scenario-aligned VaR pilot, not local search";
        end
    end
end
if ok; lines(end+1)="check_status=passed"; else; lines(end+1)="check_status=failed"; end
write_lines(log_path,lines); fprintf('%s\n',lines); if ~ok; error('scenario-aligned VaR metric reconstruction check failed'); end
end
function ensure_dir(path_value); if exist(path_value,'dir')~=7; mkdir(path_value); end; end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
function write_lines(path_value,lines); fid=fopen(path_value,'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); for i=1:numel(lines); fprintf(fid,'%s\n',lines(i)); end; end
