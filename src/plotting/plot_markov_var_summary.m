function plot_markov_var_summary(markov_var_table, initial_fault_var_table, cfg)
%PLOT_MARKOV_VAR_SUMMARY 绘制Markov经验VaR风险指标图。
% 输入：
%   markov_var_table - 全局VaR指标表。
%   initial_fault_var_table - 按初始故障分组的VaR指标表。
%   cfg - 全局配置，包含图像输出目录。
% 输出：
%   results/figures/markov_var_metrics.png
%   results/figures/markov_initial_fault_cri_top10.png
% 物理含义：
%   图像用于快速检查风险指标随置信水平变化，以及识别高CRI初始线路。

if ~exist(cfg.results_figure_dir, 'dir')
    mkdir(cfg.results_figure_dir);
end

fig1 = figure('Visible', 'off');
plot(markov_var_table.sigma, markov_var_table.SLLR, '-o', 'LineWidth', 1.5);
hold on;
plot(markov_var_table.sigma, markov_var_table.SLFOR, '-s', 'LineWidth', 1.5);
plot(markov_var_table.sigma, markov_var_table.SNVOR, '-^', 'LineWidth', 1.5);
plot(markov_var_table.sigma, markov_var_table.CRI, '-d', 'LineWidth', 1.5);
grid on;
xlabel('置信水平 \sigma');
ylabel('经验VaR风险值');
title('Markov事故链样本经验VaR风险指标');
legend({'SLLR', 'SLFOR', 'SNVOR', 'CRI'}, 'Location', 'best');
saveas(fig1, fullfile(cfg.results_figure_dir, 'markov_var_metrics.png'));
close(fig1);

top_n = min(10, height(initial_fault_var_table));
top_table = initial_fault_var_table(1:top_n, :);
fig2 = figure('Visible', 'off');
bar(top_table.CRI);
grid on;
xticks(1:top_n);
xticklabels("L" + string(top_table.initial_branch));
xtickangle(45);
xlabel('初始线路编号');
ylabel('CRI');
title('sigma=0.95下CRI排名前10的初始线路');
saveas(fig2, fullfile(cfg.results_figure_dir, 'markov_initial_fault_cri_top10.png'));
close(fig2);
end
