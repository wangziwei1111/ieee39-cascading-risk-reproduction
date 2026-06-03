function main_plot_fig4_2_diagnostic_reproduction()
%MAIN_PLOT_FIG4_2_DIAGNOSTIC_REPRODUCTION Plot six-panel Fig.4-2 diagnostic.
project_root = fileparts(fileparts(mfilename('fullpath')));
out_root = fullfile(project_root, 'results', 'figures', 'fig4_2_diagnostic_reproduction');
D = readtable(fullfile(out_root, 'fig4_2_density_data.csv'), 'TextType', 'string', 'Delimiter', ',');
scenario_ids = ["fig4_2_no_renewable", "fig4_2_distributed_renewable_3000MW"];
scenario_titles = ["无新能源接入", "节点30-39分散式接入3000MW新能源"];
metrics = ["LLR", "LFOR", "NVOR"];
metric_titles = ["LLR概率密度", "LFOR概率密度", "NVOR概率密度"];

fig = figure('Color', 'w', 'Position', [100, 100, 1400, 760]);
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
for r = 1:2
    for c = 1:3
        nexttile;
        mask = D.scenario_id == scenario_ids(r) & D.metric_name == metrics(c);
        plot(D.x_value(mask), D.density_value(mask), 'LineWidth', 1.8, 'Color', [0.1 0.32 0.62]);
        grid on;
        xlabel('风险指标值');
        ylabel('概率密度');
        title(sprintf('(%c) %s - %s', char('a' + (r-1)*3 + c - 1), scenario_titles(r), metric_titles(c)), 'Interpreter', 'none');
        set(gca, 'Box', 'on', 'FontSize', 10);
    end
end
sgtitle('图4-2诊断复现：新能源接入前后连锁故障风险指标概率密度分布', 'FontWeight', 'bold');
png_path = fullfile(out_root, 'fig4_2_diagnostic_reproduction.png');
fig_path = fullfile(out_root, 'fig4_2_diagnostic_reproduction.fig');
svg_path = fullfile(out_root, 'fig4_2_diagnostic_reproduction.svg');
exportgraphics(fig, png_path, 'Resolution', 200);
savefig(fig, fig_path);
try
    exportgraphics(fig, svg_path);
catch ME
    writelines("SVG export failed: " + string(ME.message), fullfile(out_root, 'fig4_2_plot_svg_export_log.txt'));
end
close(fig);
fprintf('Wrote %s\n', png_path);
end
