function main_diagnose_paper_table_unit_convention()
project_root=fileparts(fileparts(mfilename('fullpath'))); diag_dir=fullfile(project_root,'results','calibration','diagnostics');
score_path=fullfile(diag_dir,'scenario_aligned_var_score_summary.csv'); out_path=fullfile(diag_dir,'paper_table_unit_convention_diagnosis.csv');
if exist(score_path,'file')~=2; writetable(table(),out_path); return; end
S=read_csv(score_path); modes=unique(string(S.comparison_mode));
comparison_mode=strings(0,1); best_parameter_set_id=strings(0,1); best_sigma=[]; best_metric_source=strings(0,1); best_scale_variant=strings(0,1); median_abs_relative_gap=[]; trend_match_rate=[]; diagnosis=strings(0,1); recommended_use=strings(0,1);
for m=modes'
    R=S(string(S.comparison_mode)==m,:); [~,idx]=min(R.median_abs_relative_gap - R.trend_match_rate);
    row=R(idx,:);
    comparison_mode(end+1,1)=m; best_parameter_set_id(end+1,1)=row.parameter_set_id; best_sigma(end+1,1)=row.sigma; best_metric_source(end+1,1)=row.metric_source; best_scale_variant(end+1,1)=row.scale_variant; median_abs_relative_gap(end+1,1)=row.median_abs_relative_gap; trend_match_rate(end+1,1)=row.trend_match_rate; %#ok<AGROW>
    if row.median_abs_relative_gap < 1 && row.trend_match_rate >= 0.75
        d="paper_values_should_be_used_as_display_units"; use="may be used for next scale-aware diagnostic, not formal result";
    elseif row.median_abs_relative_gap > 5
        d="ambiguous_need_manual_confirmation"; use="do not use as calibration convention yet";
    else
        d="not_enough_evidence"; use="requires formal scenario-aligned VaR pilot";
    end
    if m=="compare_to_paper_actual_1e_minus_4" && row.median_abs_relative_gap < 1
        d="paper_values_should_be_converted_to_actual_risk";
    end
    diagnosis(end+1,1)=d; recommended_use(end+1,1)=use; %#ok<AGROW>
end
out=table(comparison_mode,best_parameter_set_id,best_sigma,best_metric_source,best_scale_variant,median_abs_relative_gap,trend_match_rate,diagnosis,recommended_use);
writetable(out,out_path);
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
