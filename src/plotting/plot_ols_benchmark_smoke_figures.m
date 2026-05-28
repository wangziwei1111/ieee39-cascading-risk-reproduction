function plot_ols_benchmark_smoke_figures(root_dir)
%PLOT_OLS_BENCHMARK_SMOKE_FIGURES Plot OLS benchmark smoke diagnostics.
if nargin < 1 || isempty(root_dir)
    project_root = fileparts(fileparts(mfilename('fullpath')));
    root_dir = fullfile(project_root, 'results', 'loadshedding', 'ols_benchmark_smoke');
end
table_dir = fullfile(root_dir, 'tables');
figure_dir = fullfile(root_dir, 'figures');
if ~exist(figure_dir, 'dir')
    mkdir(figure_dir);
end

summary = readtable(fullfile(table_dir, 'ols_benchmark_smoke_summary.csv'));
bench = readtable(fullfile(table_dir, 'ols_smoke_vs_paper_benchmark.csv'));

plot_cri(summary, fullfile(figure_dir, 'ols_vs_simple_cri_comparison.png'));
plot_trigger_counts(summary, fullfile(figure_dir, 'ols_trigger_counts.png'));
plot_paper_compare(bench, fullfile(figure_dir, 'ols_smoke_vs_paper_cri.png'));
end

function plot_cri(summary, out_path)
scenarios = string(unique(summary.scenario_id, 'stable'));
weighted_simple = zeros(numel(scenarios), 1);
weighted_ols = zeros(numel(scenarios), 1);
paper_simple = zeros(numel(scenarios), 1);
paper_ols = zeros(numel(scenarios), 1);
for i = 1:numel(scenarios)
    s = summary(string(summary.scenario_id) == scenarios(i) & string(summary.mode) == "simple", :);
    o = summary(string(summary.scenario_id) == scenarios(i) & string(summary.mode) == "paper_ols_violation", :);
    weighted_simple(i) = s.weighted_CRI_095(1);
    weighted_ols(i) = o.weighted_CRI_095(1);
    paper_simple(i) = s.paper_CRI_095(1);
    paper_ols(i) = o.paper_CRI_095(1);
end
figure('Visible', 'off', 'Color', 'w');
bar([weighted_simple, weighted_ols, paper_simple, paper_ols]);
set(gca, 'XTickLabel', cellstr(scenarios), 'XTickLabelRotation', 25);
ylabel('CRI');
title('OLS benchmark smoke: simple vs paper\_ols\_violation CRI');
legend({'weighted simple','weighted OLS','paper simple','paper OLS'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_trigger_counts(summary, out_path)
ols = summary(string(summary.mode) == "paper_ols_violation", :);
figure('Visible', 'off', 'Color', 'w');
bar([ols.nonconverged_trigger_count, ols.line_overload_trigger_count, ols.voltage_violation_trigger_count], 'stacked');
set(gca, 'XTickLabel', cellstr(string(ols.scenario_id)), 'XTickLabelRotation', 25);
ylabel('Triggered stage count');
title('OLS trigger count diagnostics');
legend({'nonconverged','line overload','voltage violation'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end

function plot_paper_compare(bench, out_path)
figure('Visible', 'off', 'Color', 'w');
bar([bench.paper_CRI, bench.simple_paper_formula_CRI, bench.paper_ols_violation_paper_formula_CRI]);
set(gca, 'XTickLabel', cellstr(string(bench.reproduction_scenario_id)), 'XTickLabelRotation', 25);
ylabel('CRI raw value');
title('OLS smoke vs paper benchmark CRI (raw comparison; unit alignment pending)');
legend({'paper benchmark','simple paper\_formula','OLS paper\_formula'}, 'Location', 'best');
grid on;
saveas(gcf, out_path);
close(gcf);
end
