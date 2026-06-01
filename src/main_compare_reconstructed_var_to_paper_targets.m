function main_compare_reconstructed_var_to_paper_targets()
%MAIN_COMPARE_RECONSTRUCTED_VAR_TO_PAPER_TARGETS Compare reconstructed VaR candidates with paper targets.
project_root = fileparts(fileparts(mfilename('fullpath')));
diag_dir = fullfile(project_root, 'results', 'calibration', 'diagnostics');
var_path = fullfile(diag_dir, 'reconstructed_empirical_var_metrics.csv');
target_path = fullfile(project_root, 'paper_inputs', 'filled', 'calibration_target_benchmark.csv');
gap_path = fullfile(diag_dir, 'reconstructed_var_to_paper_gap.csv');
sum_path = fullfile(diag_dir, 'reconstructed_var_gap_summary.csv');
if exist(var_path,'file')~=2 || exist(target_path,'file')~=2
    writetable(table(), gap_path); writetable(table(), sum_path); return;
end
V=read_csv(var_path); T=read_csv(target_path);
groups=unique(string(T.target_group)); V95=V(abs(V.sigma-0.95)<1e-12,:);
sample_variant=strings(0,1); scale_variant=strings(0,1); sigma=[]; metric_name=strings(0,1); paper_reference_group=strings(0,1); paper_reference_mean=[]; var_value=[]; ratio_paper_to_var=[]; absolute_gap=[]; relative_gap=[]; interpretation=strings(0,1);
for i=1:height(V95)
    for g=groups'
        mask=string(T.target_group)==g & string(T.metric_name)==string(V95.metric_name(i));
        pmean=mean(T.paper_value(mask),'omitnan'); val=V95.var_value(i);
        ratio=NaN; gap=NaN; rel=NaN; interp="group mean / scale diagnosis only; unified smoke is not scenario-aligned";
        if ~isnan(pmean) && ~isnan(val)
            gap=val-pmean;
            if abs(val)>1e-12; ratio=pmean/val; end
            if abs(pmean)>1e-12; rel=gap/abs(pmean); end
            if abs(ratio) < 5
                interp=interp + "; candidate is near paper scale but still diagnostic";
            else
                interp=interp + "; scale gap remains";
            end
        else
            interp="missing reconstructed VaR or target mean; not filled with zero";
        end
        sample_variant(end+1,1)=V95.sample_variant(i); scale_variant(end+1,1)=V95.scale_variant(i); sigma(end+1,1)=V95.sigma(i); metric_name(end+1,1)=V95.metric_name(i); paper_reference_group(end+1,1)=g; paper_reference_mean(end+1,1)=pmean; var_value(end+1,1)=val; ratio_paper_to_var(end+1,1)=ratio; absolute_gap(end+1,1)=gap; relative_gap(end+1,1)=rel; interpretation(end+1,1)=interp; %#ok<AGROW>
    end
end
GAP=table(sample_variant,scale_variant,sigma,metric_name,paper_reference_group,paper_reference_mean,var_value,ratio_paper_to_var,absolute_gap,relative_gap,interpretation);
writetable(GAP,gap_path);

[G, vars, scales, sigs] = findgroups(GAP.sample_variant, GAP.scale_variant, GAP.sigma);
sample_variant=strings(0,1); scale_variant=strings(0,1); sigma=[]; mean_abs_relative_gap=[]; median_ratio_paper_to_var=[]; ratio_stability=strings(0,1); trend_interpretation=strings(0,1); recommendation=strings(0,1);
for g=1:max(G)
    rows=GAP(G==g,:);
    ratios=rows.ratio_paper_to_var(~isnan(rows.ratio_paper_to_var)&isfinite(rows.ratio_paper_to_var));
    rels=abs(rows.relative_gap(~isnan(rows.relative_gap)));
    sample_variant(end+1,1)=vars(g); scale_variant(end+1,1)=scales(g); sigma(end+1,1)=sigs(g); %#ok<AGROW>
    mean_abs_relative_gap(end+1,1)=mean(rels,'omitnan'); median_ratio_paper_to_var(end+1,1)=median(ratios,'omitnan'); %#ok<AGROW>
    if numel(ratios) < 4
        stab="insufficient_ratios";
    elseif prctile(ratios,90)/max(prctile(ratios,10),1e-12) < 5
        stab="moderate";
    else
        stab="unstable";
    end
    ratio_stability(end+1,1)=stab; %#ok<AGROW>
    trend_interpretation(end+1,1)="scale-only group mean comparison; trend requires scenario-aligned formal rerun"; %#ok<AGROW>
    if height(rows) < 8
        rec="insufficient_samples";
    elseif mean_abs_relative_gap(end) < 0.5 && stab ~= "unstable"
        rec="candidate_metric_for_calibration";
    elseif median_ratio_paper_to_var(end) > 10 || median_ratio_paper_to_var(end) < 0.1
        rec="still_wrong_scale";
    else
        rec="not_recommended";
    end
    recommendation(end+1,1)=rec; %#ok<AGROW>
end
SUM=table(sample_variant,scale_variant,sigma,mean_abs_relative_gap,median_ratio_paper_to_var,ratio_stability,trend_interpretation,recommendation);
writetable(SUM,sum_path);
fprintf('reconstructed VaR gap outputs written.\n');
end
function tbl=read_csv(path_value); opts=detectImportOptions(path_value,'Delimiter',',','TextType','string'); opts.VariableNamingRule='preserve'; tbl=readtable(path_value,opts); end
