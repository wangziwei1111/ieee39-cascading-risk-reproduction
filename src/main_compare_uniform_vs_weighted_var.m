function main_compare_uniform_vs_weighted_var()
%MAIN_COMPARE_UNIFORM_VS_WEIGHTED_VAR 对比uniform与表4-1加权VaR结果。
% 输入：
%   无。读取 markov_var_metrics.csv 和 markov_var_metrics_weighted.csv。
% 输出：
%   results/tables/var_uniform_vs_weighted_comparison.csv
%   results/figures/var_uniform_vs_weighted_cri.png
% 物理含义：
%   uniform VaR 表示每条Monte Carlo事故链等权；weighted VaR 表示按论文表4-1
%   初始线路故障概率给事故链分配权重。该对照用于观察初始故障概率分布对全局
%   风险指标的影响。

project_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(project_root, 'config'));
addpath(genpath(fullfile(project_root, 'src')));

cfg = base_config();
cfg.results_table_dir = fullfile(project_root, cfg.results_table_dir);
cfg.results_figure_dir = fullfile(project_root, cfg.results_figure_dir);

uniform_csv = fullfile(cfg.results_table_dir, 'markov_var_metrics.csv');
weighted_csv = fullfile(cfg.results_table_dir, 'markov_var_metrics_weighted.csv');
if ~exist(uniform_csv, 'file')
    error('找不到uniform VaR结果：%s。请先运行 main_run_markov_risk。', uniform_csv);
end
if ~exist(weighted_csv, 'file')
    error('找不到weighted VaR结果：%s。请先填写论文表4-1并运行 main_run_markov_risk_weighted。', weighted_csv);
end

uniform_table = sortrows(readtable(uniform_csv), 'sigma');
weighted_table = sortrows(readtable(weighted_csv), 'sigma');
if height(uniform_table) ~= height(weighted_table) || any(abs(uniform_table.sigma - weighted_table.sigma) > 1e-12)
    error('uniform与weighted VaR结果的sigma列表不一致。');
end

delta_SLLR = weighted_table.SLLR - uniform_table.SLLR;
delta_SLFOR = weighted_table.SLFOR - uniform_table.SLFOR;
delta_SNVOR = weighted_table.SNVOR - uniform_table.SNVOR;
delta_CRI = weighted_table.CRI - uniform_table.CRI;

comparison_table = table(uniform_table.sigma, ...
    uniform_table.SLLR, weighted_table.SLLR, delta_SLLR, ...
    uniform_table.SLFOR, weighted_table.SLFOR, delta_SLFOR, ...
    uniform_table.SNVOR, weighted_table.SNVOR, delta_SNVOR, ...
    uniform_table.CRI, weighted_table.CRI, delta_CRI, ...
    'VariableNames', {'sigma', ...
    'uniform_SLLR', 'weighted_SLLR', 'delta_SLLR', ...
    'uniform_SLFOR', 'weighted_SLFOR', 'delta_SLFOR', ...
    'uniform_SNVOR', 'weighted_SNVOR', 'delta_SNVOR', ...
    'uniform_CRI', 'weighted_CRI', 'delta_CRI'});

comparison_csv = fullfile(cfg.results_table_dir, 'var_uniform_vs_weighted_comparison.csv');
save_result_table(comparison_table, comparison_csv, true);

if ~exist(cfg.results_figure_dir, 'dir')
    mkdir(cfg.results_figure_dir);
end
fig = figure('Visible', 'off', 'Color', 'w');
plot(comparison_table.sigma, comparison_table.uniform_CRI, '-o', 'LineWidth', 1.8);
hold on;
plot(comparison_table.sigma, comparison_table.weighted_CRI, '-s', 'LineWidth', 1.8);
grid on;
xlabel('置信水平 \sigma');
ylabel('CRI');
title('uniform 与论文表4-1加权 VaR-CRI 对比');
legend({'uniform', 'paper table 4-1 weighted'}, 'Location', 'best');
saveas(fig, fullfile(cfg.results_figure_dir, 'var_uniform_vs_weighted_cri.png'));
close(fig);

fprintf('uniform与weighted VaR对照表已写入：%s\n', comparison_csv);
end
