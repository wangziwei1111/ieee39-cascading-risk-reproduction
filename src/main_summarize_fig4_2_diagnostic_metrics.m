function main_summarize_fig4_2_diagnostic_metrics()
%MAIN_SUMMARIZE_FIG4_2_DIAGNOSTIC_METRICS Summarize Fig.4-2 risk samples.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'figures', 'fig4_2_diagnostic_reproduction');
scenario_ids = ["fig4_2_no_renewable", "fig4_2_distributed_renewable_3000MW"];
labels = ["No renewable access", "Distributed renewable 3000 MW"];
metrics = ["LLR","LFOR","NVOR","CRI_reference"];
fields = ["R_LLR_display","R_LFOR_display","R_NVOR_display","R_CRI_display_reference"];
rows = {};
for s = 1:numel(scenario_ids)
    T = readtable(fullfile(out_root, scenario_ids(s), 'risk_samples_for_density.csv'), 'TextType', 'string', 'Delimiter', ',');
    for m = 1:numel(metrics)
        x = T.(fields(m));
        rows{end+1,1} = table(scenario_ids(s), labels(s), metrics(m), numel(x), sum(x ~= 0 & ~isnan(x)), ...
            mean(x == 0, 'omitnan'), mean(x, 'omitnan'), median(x, 'omitnan'), ...
            prctile(x, 90), prctile(x, 95), prctile(x, 98), max(x, [], 'omitnan'), ...
            prctile(x, 95), "Diagnostic display values divided by 1e-4; not formal VaR.", ...
            'VariableNames', {'scenario_id','scenario_label','metric_name','sample_count','nonzero_count', ...
            'zero_fraction','mean_value','median_value','p90_value','p95_value','p98_value','max_value','VaR_0p95','note'}); %#ok<AGROW>
    end
end
S = vertcat(rows{:});
writetable(S, fullfile(out_root, 'fig4_2_metric_summary.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'fig4_2_metric_summary.csv'));
end
