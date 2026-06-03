function main_build_fig4_2_density_data()
%MAIN_BUILD_FIG4_2_DENSITY_DATA Build KDE/histogram density data for Fig.4-2.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'figures', 'fig4_2_diagnostic_reproduction');
scenario_dirs = [ ...
    struct('id', 'fig4_2_no_renewable', 'label', 'No renewable access'); ...
    struct('id', 'fig4_2_distributed_renewable_3000MW', 'label', 'Distributed renewable 3000 MW') ...
    ];
metrics = ["LLR","LFOR","NVOR"];
value_fields = ["R_LLR_display","R_LFOR_display","R_NVOR_display"];
rows = {};
for s = 1:numel(scenario_dirs)
    sample_path = fullfile(out_root, scenario_dirs(s).id, 'risk_samples_for_density.csv');
    T = readtable(sample_path, 'TextType', 'string', 'Delimiter', ',');
    for m = 1:numel(metrics)
        x = T.(value_fields(m));
        [xv, dv, method, bw, note] = local_density(x);
        for i = 1:numel(xv)
            rows{end+1,1} = table(string(scenario_dirs(s).id), string(scenario_dirs(s).label), metrics(m), ...
                xv(i), dv(i), numel(x), string(method), bw, string(note), ...
                'VariableNames', {'scenario_id','scenario_label','metric_name','x_value','density_value', ...
                'sample_count','kernel_method','bandwidth','note'}); %#ok<AGROW>
        end
    end
end
D = vertcat(rows{:});
writetable(D, fullfile(out_root, 'fig4_2_density_data.csv'));
fprintf('Wrote %s\n', fullfile(out_root, 'fig4_2_density_data.csv'));
end

function [xv, dv, method, bw, note] = local_density(x)
x = x(:);
x = x(~isnan(x) & ~isinf(x));
if isempty(x)
    xv = NaN; dv = NaN; method = "empty"; bw = NaN; note = "no valid samples";
    return;
end
if numel(unique(x)) < 2 || numel(x) < 5
    center = x(1);
    span = max(abs(center) * 0.05, 1e-6);
    xv = [center - span; center; center + span];
    dv = [0; 1 / max(2 * span, eps); 0];
    method = "histogram_degenerate";
    bw = 2 * span;
    note = "Samples too few or all equal; retained zero-risk samples and used degenerate histogram density.";
    return;
end
if exist('ksdensity', 'file') == 2
    [dv, xv, bw] = ksdensity(x, 'NumPoints', 200);
    method = "ksdensity";
    note = "KDE density; full-range samples retained.";
else
    edges = linspace(min(x), max(x), min(40, max(8, ceil(sqrt(numel(x))) + 1)));
    [counts, edges] = histcounts(x, edges, 'Normalization', 'pdf');
    xv = (edges(1:end-1) + edges(2:end)) ./ 2;
    dv = counts;
    bw = mean(diff(edges));
    method = "histogram_pdf";
    note = "ksdensity unavailable; used histogram pdf. Full-range samples retained.";
end
xv = xv(:);
dv = dv(:);
end
