function main_compare_fig4_2_diagnostic_trend_to_paper()
%MAIN_COMPARE_FIG4_2_DIAGNOSTIC_TREND_TO_PAPER Qualitative trend comparison.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'figures', 'fig4_2_diagnostic_reproduction');
S = readtable(fullfile(out_root, 'fig4_2_metric_summary.csv'), 'TextType', 'string', 'Delimiter', ',');
metrics = ["LLR","LFOR","NVOR"];
rows = cell(numel(metrics), 1);
for m = 1:numel(metrics)
    no = S(S.scenario_id == "fig4_2_no_renewable" & S.metric_name == metrics(m), :);
    re = S(S.scenario_id == "fig4_2_distributed_renewable_3000MW" & S.metric_name == metrics(m), :);
    if isempty(no) || isempty(re) || no.sample_count < 10 || re.sample_count < 10
        diagnostic_trend = "unclear";
        trend_status = "insufficient_samples";
        evidence = "missing metric summary rows or too few samples";
    elseif re.p95_value < no.p95_value && re.mean_value < no.mean_value
        diagnostic_trend = "renewable_lower";
        trend_status = "qualitative_only";
        evidence = sprintf('mean %.4g -> %.4g; p95 %.4g -> %.4g', no.mean_value, re.mean_value, no.p95_value, re.p95_value);
    elseif re.p95_value > no.p95_value && re.mean_value > no.mean_value
        diagnostic_trend = "renewable_higher";
        trend_status = "qualitative_only";
        evidence = sprintf('mean %.4g -> %.4g; p95 %.4g -> %.4g', no.mean_value, re.mean_value, no.p95_value, re.p95_value);
    else
        diagnostic_trend = "mixed";
        trend_status = "qualitative_only";
        evidence = sprintf('mean %.4g -> %.4g; p95 %.4g -> %.4g', no.mean_value, re.mean_value, no.p95_value, re.p95_value);
    end
    rows{m} = table(metrics(m), "paper_figure_shape_only", diagnostic_trend, trend_status, string(evidence), ...
        "Paper figure is used qualitatively only; this is not strict original reproduction.", ...
        'VariableNames', {'metric_name','paper_qualitative_trend','diagnostic_trend','trend_match_status','evidence','note'});
end
T = vertcat(rows{:});
writetable(T, fullfile(out_root, 'fig4_2_trend_comparison.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'fig4_2_trend_comparison.csv'));
end
