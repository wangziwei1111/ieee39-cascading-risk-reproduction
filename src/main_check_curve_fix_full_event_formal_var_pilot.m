function main_check_curve_fix_full_event_formal_var_pilot()
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot_after_curve_fix');
log_path = fullfile(out_root, 'curve_fix_full_event_formal_var_pilot_check_log.txt');
ok = true; messages = strings(0,1);
ready_path = fullfile(project_root, 'results', 'calibration', 'full_event_formal_var_pilot', 'post_wind_curve_fix_readiness.csv');
[ok,messages]=require_file(ok,messages,ready_path);
if exist(ready_path,'file')==2
    R=readtable(ready_path,'TextType','string','Delimiter',',');
    if ~logical(R.ready_for_full_event_formal_pilot_rerun(1)), ok=false; messages(end+1)="curve fix readiness is not 1"; end %#ok<AGROW>
end
parameter_sets=["low_hidden_failure","medium_hidden_failure","high_hidden_failure","benchmark_calibrated_seed"];
scenario_ids=["concentrated_bus34","distributed_30_39","wind_speed_11_28","wind_speed_12_00","penetration_40pct","penetration_60pct","penetration_80pct"];
for p=parameter_sets
    for s=scenario_ids
        d=fullfile(out_root,p,s);
        snap_path=fullfile(d,'scenario_config_snapshot.csv');
        [ok,messages]=require_file(ok,messages,snap_path);
        if exist(snap_path,'file')==2
            S=readtable(snap_path,'TextType','string','Delimiter',',');
            if S.wind_power_curve_profile(1)~="paper_2_12_20", ok=false; messages(end+1)="non-paper curve in "+snap_path; end %#ok<AGROW>
            if S.wind_curve_source_status(1)~="original_paper_formula", ok=false; messages(end+1)="non-paper curve source in "+snap_path; end %#ok<AGROW>
            if s=="wind_speed_11_28" && abs(S.actual_wind_pg_total_mw_in_case(1)-2489.38805581395)>1e-3, ok=false; messages(end+1)="wind_speed_11_28 PG mismatch"; end %#ok<AGROW>
            if s=="wind_speed_12_00" && abs(S.actual_wind_pg_total_mw_in_case(1)-3000)>1e-6, ok=false; messages(end+1)="wind_speed_12_00 PG mismatch"; end %#ok<AGROW>
        end
        summary_path=fullfile(d,'tables','markov_chain_summary.csv');
        [ok,messages]=require_file(ok,messages,summary_path);
        [ok,messages]=require_file(ok,messages,fullfile(d,'tables','stage_transition_probability_details.csv'));
        [ok,messages]=require_file(ok,messages,fullfile(d,'tables','candidate_probability_trace.csv'));
        [ok,messages]=require_file(ok,messages,fullfile(d,'logs','scenario_run_log.txt'));
        if exist(summary_path,'file')==2
            T=readtable(summary_path,'TextType','string','Delimiter',',');
            if any(string(T.stage_probability_mode)~="bernoulli_full_event"), ok=false; messages(end+1)="non-full-event stage mode in "+summary_path; end %#ok<AGROW>
            if any(string(T.chain_probability_status)=="selected_only_approximation"), ok=false; messages(end+1)="selected-only status in "+summary_path; end %#ok<AGROW>
        end
    end
end
for f=["full_event_var_metrics_after_curve_fix.csv","full_event_var_to_paper_gap_after_curve_fix.csv", ...
        "full_event_var_score_summary_after_curve_fix.csv","before_after_curve_fix_comparison.csv","post_curve_fix_formal_pilot_action.csv"]
    [ok,messages]=require_file(ok,messages,fullfile(out_root,f));
end
messages(end+1)="final_summary_not_written_by_this_check=1"; %#ok<AGROW>
if exist(fullfile(out_root,'local_search_results'),'dir')==7 || exist(fullfile(out_root,'local_search_results.csv'),'file')==2
    ok=false; messages(end+1)="local_search_results unexpectedly exists in after-curve-fix root."; %#ok<AGROW>
else
    messages(end+1)="local_search_results not generated."; %#ok<AGROW>
end
fid=fopen(log_path,'w'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'curve_fix_full_event_formal_var_pilot_check\ncheck_status=%s\n',ternary(ok,'pass','fail'));
for i=1:numel(messages), fprintf(fid,'%s\n',messages(i)); end
if ~ok, error('curve-fix full-event formal pilot check failed; see %s',log_path); end
fprintf('curve-fix full-event formal pilot check passed: %s\n',log_path);
end

function [ok,messages]=require_file(ok,messages,path)
if exist(path,'file')~=2, ok=false; messages(end+1)="missing file: "+string(path); else, messages(end+1)="found file: "+string(path); end
end
function v=ternary(c,a,b)
if c, v=a; else, v=b; end
end
