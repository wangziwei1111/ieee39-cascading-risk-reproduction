function main_select_next_calibration_metric_source()
project_root=fileparts(fileparts(mfilename('fullpath'))); diag_dir=fullfile(project_root,'results','calibration','diagnostics');
score_path=fullfile(diag_dir,'scenario_aligned_var_score_summary.csv'); out_path=fullfile(diag_dir,'selected_calibration_metric_source.csv');
if exist(score_path,'file')~=2; writetable(empty(),out_path); return; end
S=read_csv(score_path);
priority=["candidate_for_scale_aware_calibration","candidate_but_needs_formal_rerun"];
selected_row=[]; go="do_not_calibrate_parameters"; action="fix metric definition or run formal scenario-aligned VaR pilot before local search"; reason="all sources are wrong_scale/wrong_trend/not_recommended";
for p=priority
    R=S(string(S.recommendation)==p,:);
    if ~isempty(R)
        [~,idx]=min(R.score_rank); selected_row=R(idx,:); reason="best available recommendation is "+p;
        if p=="candidate_for_scale_aware_calibration"; go="proceed_to_scale_aware_calibration_pilot_not_local_search"; action="proceed to scale-aware calibration pilot only after review";
        else; go="needs_formal_rerun_before_local_search"; action="run formal scenario-aligned VaR pilot, not local search"; end
        break;
    end
end
if isempty(selected_row)
    [~,idx]=min(S.score_rank); selected_row=S(idx,:); sel=0;
else
    sel=1;
end
selected=sel; parameter_set_id=selected_row.parameter_set_id; sigma=selected_row.sigma; metric_source=selected_row.metric_source; scale_variant=selected_row.scale_variant; comparison_mode=selected_row.comparison_mode; go_no_go=string(go); required_next_action=string(action); reason=string(reason);
out=table(selected,parameter_set_id,sigma,metric_source,scale_variant,comparison_mode,reason,go_no_go,required_next_action);
writetable(out,out_path);
end
function out=empty(); out=table([],strings(0,1),[],strings(0,1),strings(0,1),strings(0,1),strings(0,1),strings(0,1),strings(0,1),'VariableNames',{'selected','parameter_set_id','sigma','metric_source','scale_variant','comparison_mode','reason','go_no_go','required_next_action'}); end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
